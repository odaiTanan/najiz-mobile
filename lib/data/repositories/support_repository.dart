import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/constants/api_config.dart';
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
    final map = _extractDataMap(data);
    final id = _asInt(map['id']) ?? _asInt(data['id']);
    if (id == null) throw HomeApiException('تعذر تحميل بيانات المستخدم');
    return id;
  }

  Future<SupportConversation> getUserConversation({required String token}) async {
    final data = await _get(endpoint: '/chat/support-conversation', token: token);
    final map = _extractDataMap(data);
    final id = _asInt(map['id']) ?? _asInt(data['id']);
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
    final uri = Uri.parse('$_baseUrl/chat/messages/$conversationId');
    final payload = {'message': message};
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
    final data = _safeJsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final map = _extractDataMap(data, fallback: data);
      return _toMessage(map);
    }
    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> _get({
    required String endpoint,
    required String token,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
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
    final data = _safeJsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Map<String, dynamic> _extractDataMap(
    Map<String, dynamic> data, {
    Map<String, dynamic>? fallback,
  }) {
    final inner = data['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) {
      return inner.map((k, v) => MapEntry(k.toString(), v));
    }
    return fallback ?? <String, dynamic>{};
  }

  List<Map<String, dynamic>> _extractDataList(Map<String, dynamic> data) {
    final inner = data['data'] ?? data;
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
  );
}

Map<String, dynamic> _safeJsonDecode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String _extractMessage(Map<String, dynamic> data) {
  final message = data['message'] ?? data['error'];
  if (message != null) return message.toString();
  return 'فشل الطلب';
}
