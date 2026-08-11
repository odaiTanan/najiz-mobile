import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:pusher_client/pusher_client.dart';
import 'package:http/http.dart' as http;

class OrderWebSocketService {
  OrderWebSocketService({required this.token});

  final String token;
  static const String _wsHost = 'mobile.najizgo.com';
  static const int _wsPort = 443;
  static const bool _wsUseTls = true;
  static const int _kMaxWsLogChars = 360;
  PusherClient? _pusher;
  Channel? _orderChannel;
  bool _isConnected = false;

  void _log(String message) {
    if (!kDebugMode) return;
    print(message);
  }

  String _shorten(dynamic value) {
    final text = value?.toString() ?? '';
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= _kMaxWsLogChars) return compact;
    return '${compact.substring(0, _kMaxWsLogChars)}...';
  }

  Future<void> connectIfNeeded() async {
    if (_isConnected) return;
    final authEndpoint = _resolveBroadcastAuthEndpoint();
    _log(
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
      enableLogging: kDebugMode,
      autoConnect: false,
    );
    _pusher!.onConnectionStateChange((state) {
      if (state == null) return;
      _log('[WS][STATE] ${state.previousState} -> ${state.currentState}');
    });
    _pusher!.onConnectionError((error) {
      _log(
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
    _log('[WS][SUBSCRIBE] $channelName');
    await _debugAuthProbe(channelName);
    _orderChannel = _pusher!.subscribe(channelName);
    await _orderChannel!.bind('order.status.updated', (event) {
      _handleOrderEvent(event?.data, onOrderUpdated, false);
    });
    await _orderChannel!.bind('.order.status.updated', (event) {
      _handleOrderEvent(event?.data, onOrderUpdated, false);
    });
    await _orderChannel!.bind('driver.location.updated', (event) {
      _handleOrderEvent(event?.data, onOrderUpdated, true);
    });
    await _orderChannel!.bind('.driver.location.updated', (event) {
      _handleOrderEvent(event?.data, onOrderUpdated, true);
    });
  }

  void _handleOrderEvent(
    dynamic rawData,
    void Function(Map<String, dynamic> orderPayload) onOrderUpdated,
    bool allowLocationOnly,
  ) {
    _log('[WS][EVENT][RAW] ${_shorten(rawData)}');
    if (rawData == null) return;
    final decoded = _decodeJsonMap(rawData);
    if (decoded.isEmpty) return;
    final orderData = _extractOrderPayload(decoded);
    final hasStatus = orderData.containsKey('status') ||
        orderData.containsKey('order_status');
    final hasDispatch = orderData.containsKey('dispatch_status') ||
        orderData.containsKey('driver_status');
    final hasLatLng = orderData.containsKey('lat') && orderData.containsKey('lng');
    if (!hasStatus && !hasDispatch && !(allowLocationOnly && hasLatLng)) return;
    onOrderUpdated(orderData);
    _log(
      '[WS][EVENT][PARSED] status=${orderData['status']} dispatch=${orderData['dispatch_status']}',
    );
  }

  Future<void> disconnect() async {
    if (_orderChannel != null) {
      _log('[WS][UNSUBSCRIBE] ${_orderChannel!.name}');
      await _pusher?.unsubscribe(_orderChannel!.name);
      _orderChannel = null;
    }
    if (_isConnected) {
      _log('[WS][DISCONNECT]');
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
        _log('[WS][AUTH][SKIP] socket_id is null/empty');
        return;
      }
      final endpoint = _resolveBroadcastAuthEndpoint();
      final body = {'socket_id': socketId, 'channel_name': channelName};
      _log('[WS][AUTH][REQ] POST $endpoint');
      _log('[WS][AUTH][REQ][BODY] ${_shorten(body)}');
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
      _log('[WS][AUTH][RES] ${response.statusCode}');
      _log('[WS][AUTH][RES][BODY] ${_shorten(response.body)} (len=${response.body.length})');
    } catch (e) {
      _log('[WS][AUTH][ERROR] $e');
    }
  }

  String _resolveWsHost() {
    return _wsHost;
  }

  bool _resolveWsUseTls() {
    return _wsUseTls;
  }
}

Map<String, dynamic> _extractOrderPayload(Map<String, dynamic> decoded) {
  final nestedOrder = _decodeJsonMap(decoded['order']);
  if (_looksLikeOrderPayload(nestedOrder)) return nestedOrder;

  final nestedData = _decodeJsonMap(decoded['data']);
  if (_looksLikeOrderPayload(nestedData)) return nestedData;

  return decoded;
}

bool _looksLikeOrderPayload(Map<String, dynamic> map) {
  if (map.isEmpty) return false;
  return map.containsKey('status') ||
      map.containsKey('dispatch_status') ||
      map.containsKey('order_status') ||
      map.containsKey('driver_status') ||
      (map.containsKey('id') &&
          (map.containsKey('lat') || map.containsKey('lng')));
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
