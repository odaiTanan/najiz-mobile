import 'dart:convert';

import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:pusher_client/pusher_client.dart';
import 'package:http/http.dart' as http;

class OrderWebSocketService {
  OrderWebSocketService({required this.token});

  final String token;
  static const String _wsHost = 'mobile.najizgo.com';
  static const int _wsPort = 443;
  static const bool _wsUseTls = true;
  PusherClient? _pusher;
  Channel? _orderChannel;
  bool _isConnected = false;

  Future<void> connectIfNeeded() async {
    if (_isConnected) return;
    final authEndpoint = _resolveBroadcastAuthEndpoint();
    print(
      '[WS][INIT] host=${_resolveWsHost()} tls=${_resolveWsUseTls()} auth=$authEndpoint',
    );

    final options = PusherOptions(
      host: _resolveWsHost(),
      wsPort: _wsPort,
      wssPort: _wsPort,
      encrypted: _resolveWsUseTls(),
      auth: PusherAuth(
        authEndpoint,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
      ),
    );
    _pusher = PusherClient(
      'np5pmfyxuslyl7romizd',
      options,
      enableLogging: true,
      autoConnect: false,
    );
    _pusher!.onConnectionStateChange((state) {
      if (state == null) return;
      print('[WS][STATE] ${state.previousState} -> ${state.currentState}');
    });
    _pusher!.onConnectionError((error) {
      print(
        '[WS][ERROR] message=${error?.message} code=${error?.code} exception=${error?.exception}',
      );
    });
    await _pusher!.connect();
    _isConnected = true;
  }

  Future<void> subscribeToOrder({
    required int orderId,
    required void Function(Map<String, dynamic> orderPayload) onOrderUpdated,
  }) async {
    await connectIfNeeded();

    if (_orderChannel != null) {
      await _pusher?.unsubscribe(_orderChannel!.name);
      _orderChannel = null;
    }

    final channelName = 'private-order.$orderId';
    print('[WS][SUBSCRIBE] $channelName');
    await _debugAuthProbe(channelName);
    _orderChannel = _pusher!.subscribe(channelName);
    await _orderChannel!.bind('order.status.updated', (event) {
      _handleOrderEvent(event?.data, onOrderUpdated);
    });
    await _orderChannel!.bind('.order.status.updated', (event) {
      _handleOrderEvent(event?.data, onOrderUpdated);
    });
  }

  void _handleOrderEvent(
    dynamic rawData,
    void Function(Map<String, dynamic> orderPayload) onOrderUpdated,
  ) {
    print('[WS][EVENT][RAW] $rawData');
    if (rawData == null) return;
    final decoded = _decodeJsonMap(rawData);
    if (decoded.isEmpty) return;
    final nestedOrder = _decodeJsonMap(decoded['order']);
    final orderData = nestedOrder.isNotEmpty ? nestedOrder : decoded;
    final hasStatus = orderData.containsKey('status');
    final hasDispatch = orderData.containsKey('dispatch_status');
    if (!hasStatus && !hasDispatch) return;
    onOrderUpdated(orderData);
    print(
      '[WS][EVENT][PARSED] status=${orderData['status']} dispatch=${orderData['dispatch_status']}',
    );
  }

  Future<void> disconnect() async {
    if (_orderChannel != null) {
      print('[WS][UNSUBSCRIBE] ${_orderChannel!.name}');
      await _pusher?.unsubscribe(_orderChannel!.name);
      _orderChannel = null;
    }
    if (_isConnected) {
      print('[WS][DISCONNECT]');
      await _pusher?.disconnect();
      _isConnected = false;
    }
  }

  String _resolveBroadcastAuthEndpoint() {
    return 'https://mobile.najizgo.com/api/broadcasting/auth';
  }

  Future<void> _debugAuthProbe(String channelName) async {
    try {
      final socketId = _pusher?.getSocketId();
      if (socketId == null || socketId.trim().isEmpty) {
        print('[WS][AUTH][SKIP] socket_id is null/empty');
        return;
      }
      final endpoint = _resolveBroadcastAuthEndpoint();
      final body = {'socket_id': socketId, 'channel_name': channelName};
      print('[WS][AUTH][REQ] POST $endpoint');
      print('[WS][AUTH][REQ][BODY] $body');
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: body,
          )
          .timeout(ApiConfig.timeout);
      print('[WS][AUTH][RES] ${response.statusCode}');
      print('[WS][AUTH][RES][BODY] ${response.body}');
    } catch (e) {
      print('[WS][AUTH][ERROR] $e');
    }
  }

  String _resolveWsHost() {
    return _wsHost;
  }

  bool _resolveWsUseTls() {
    return _wsUseTls;
  }
}

Map<String, dynamic> _decodeJsonMap(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  return <String, dynamic>{};
}
