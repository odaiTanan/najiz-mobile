import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/network/connectivity_guard.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/support/models/support_chat_models.dart';

class SupportRepository {
  final http.Client _client;
  final String _baseUrl;

  SupportRepository({http.Client? client, String baseUrl = ApiConfig.baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  Future<int> getCurrentUserId({required String token}) async {
    final data = await _get(endpoint: '/profile', token: token);
    final root = _asMap(data);
    final map = _extractDataMap(data);
    final id = _asInt(map['id']) ?? _asInt(root['id']);
    if (id == null) throw HomeApiException('تعذر تحميل بيانات المستخدم');
    return id;
  }

  Future<SupportConversation> getUserConversation({required String token}) async {
    final data = await _get(endpoint: '/chat/support-conversation', token: token);
    final root = _asMap(data);
    final map = _extractDataMap(data);
    final id = _asInt(map['id']) ?? _asInt(root['id']);
    if (id == null) throw HomeApiException('تعذر تحميل المحادثة');
    return SupportConversation(
      id: id,
      name: (map['name'] ?? 'الدعم الفني').toString(),
      avatar: map['avatar']?.toString(),
    );
  }

  Future<List<SupportChatMessage>> getMessages({
    required String token,
    required int conversationId,
  }) async {
    final data = await _get(
      endpoint: '/chat/messages/$conversationId',
      token: token,
    );
    final list = _extractDataList(data);
    return list.map(_toMessage).toList(growable: false);
  }

  Future<SupportChatMessage> sendMessage({
    required String token,
    required int conversationId,
    required String message,
  }) async {
    await ConnectivityGuard.requireOnline();
    final uri = Uri.parse('$_baseUrl/chat/messages/$conversationId');
    final payload = {'message': message};
    try {
      final res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.timeout);
      final data = _safeJsonDecodeAny(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = _extractDataMap(data, fallback: _asMap(data));
        return _toMessage(map);
      }
      throw HomeApiException.fromServer(
        _extractMessage(_asMap(data)),
        res.statusCode,
      );
    } on TimeoutException {
      throw HomeApiException(AppErrorMessages.requestTimeout);
    } on SocketException {
      throw HomeApiException(AppErrorMessages.noInternet);
    } on http.ClientException {
      throw HomeApiException(AppErrorMessages.connectionFailed);
    }
  }

  Future<void> markMessagesAsRead({
    required String token,
    required int conversationId,
    required List<int> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    await ConnectivityGuard.requireOnline();
    final uri = Uri.parse('$_baseUrl/chat/messages/$conversationId/read');
    final payload = {'message_ids': messageIds};
    try {
      final res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return;
      final data = _safeJsonDecodeAny(res.body);
      throw HomeApiException.fromServer(
        _extractMessage(_asMap(data)),
        res.statusCode,
      );
    } on TimeoutException {
      throw HomeApiException(AppErrorMessages.requestTimeout);
    } on SocketException {
      throw HomeApiException(AppErrorMessages.noInternet);
    } on http.ClientException {
      throw HomeApiException(AppErrorMessages.connectionFailed);
    }
  }

  Future<dynamic> _get({
    required String endpoint,
    required String token,
  }) async {
    await ConnectivityGuard.requireOnline();
    final uri = Uri.parse('$_baseUrl$endpoint');
    try {
      final res = await _client
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(ApiConfig.timeout);
      final data = _safeJsonDecodeAny(res.body);
      if (res.statusCode >= 200 && res.statusCode < 300) return data;
      throw HomeApiException.fromServer(
        _extractMessage(_asMap(data)),
        res.statusCode,
      );
    } on TimeoutException {
      throw HomeApiException(AppErrorMessages.requestTimeout);
    } on SocketException {
      throw HomeApiException(AppErrorMessages.noInternet);
    } on http.ClientException {
      throw HomeApiException(AppErrorMessages.connectionFailed);
    }
  }

  Map<String, dynamic> _extractDataMap(
    dynamic data, {
    Map<String, dynamic>? fallback,
  }) {
    final root = _asMap(data);
    final inner = root['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) {
      return inner.map((k, v) => MapEntry(k.toString(), v));
    }
    if (root.isNotEmpty) return root;
    return fallback ?? <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractDataList(dynamic data) {
    final root = _asMap(data);
    final inner = root.isNotEmpty ? (root['data'] ?? data) : data;
    if (inner is List) {
      return inner
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }
}

SupportChatMessage _toMessage(Map<String, dynamic> map) {
  final sender = map['sender'];
  String? senderName;
  if (sender is Map) {
    senderName = sender['name']?.toString();
  }
  return SupportChatMessage(
    id: _asInt(map['id']) ?? DateTime.now().millisecondsSinceEpoch,
    conversationId: _asInt(map['conversation_id']) ?? 0,
    senderId: _asInt(map['sender_id']) ?? 0,
    message: (map['message'] ?? '').toString(),
    createdAt: (map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
    senderName: senderName,
    isReadByMe: _asBool(map['is_read_by_me']),
    readCount: _asInt(map['read_count']) ?? 0,
  );
}

dynamic _safeJsonDecodeAny(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return <String, dynamic>{};
  }
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) {
    return data.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  final normalized = value?.toString().toLowerCase();
  return normalized == '1' || normalized == 'true';
}

String _extractMessage(Map<String, dynamic> data) {
  final message = data['message'] ?? data['error'];
  if (message != null) return message.toString();
  return 'فشل الطلب';
}
