import 'dart:convert';

import 'package:pusher_client/pusher_client.dart';

class ChatWebSocketService {
  ChatWebSocketService({required this.token});

  final String token;
  static const String _wsHost = 'mobile.najizgo.com';
  static const int _wsPort = 443;
  static const bool _wsUseTls = true;

  PusherClient? _pusher;
  Channel? _chatChannel;
  bool _isConnected = false;

  Future<void> connectIfNeeded() async {
    if (_isConnected) return;
    final options = PusherOptions(
      host: _wsHost,
      wsPort: _wsPort,
      wssPort: _wsPort,
      encrypted: _wsUseTls,
      auth: PusherAuth(
        'https://mobile.najizgo.com/api/broadcasting/auth',
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
    await _pusher!.connect();
    _isConnected = true;
  }

  Future<void> subscribeToConversation({
    required int conversationId,
    required void Function(Map<String, dynamic> messagePayload) onMessage,
    void Function(Map<String, dynamic> readPayload)? onMessageRead,
  }) async {
    await connectIfNeeded();
    if (_chatChannel != null) {
      await _pusher?.unsubscribe(_chatChannel!.name);
      _chatChannel = null;
    }
    final channelName = 'private-chat.$conversationId';
    _chatChannel = _pusher!.subscribe(channelName);
    await _chatChannel!.bind('message.sent', (event) {
      _handleMessage(event?.data, onMessage);
    });
    await _chatChannel!.bind('.message.sent', (event) {
      _handleMessage(event?.data, onMessage);
    });
    await _chatChannel!.bind('message.read', (event) {
      _handleReadReceipt(event?.data, onMessageRead);
    });
    await _chatChannel!.bind('.message.read', (event) {
      _handleReadReceipt(event?.data, onMessageRead);
    });
  }

  void _handleMessage(
    dynamic raw,
    void Function(Map<String, dynamic> messagePayload) onMessage,
  ) {
    final decoded = _decodeJsonMap(raw);
    if (decoded.isEmpty) return;
    final nested = _decodeJsonMap(decoded['message']);
    final payload = nested.isNotEmpty ? nested : decoded;
    if (payload.containsKey('message')) onMessage(payload);
  }

  Future<void> disconnect() async {
    if (_chatChannel != null) {
      await _pusher?.unsubscribe(_chatChannel!.name);
      _chatChannel = null;
    }
    if (_isConnected) {
      await _pusher?.disconnect();
      _isConnected = false;
    }
  }

  void _handleReadReceipt(
    dynamic raw,
    void Function(Map<String, dynamic> readPayload)? onMessageRead,
  ) {
    if (onMessageRead == null) return;
    final decoded = _decodeJsonMap(raw);
    if (decoded.isEmpty) return;
    final nested = _decodeJsonMap(decoded['message']);
    final payload = nested.isNotEmpty ? nested : decoded;
    if (payload.containsKey('message_id')) onMessageRead(payload);
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
