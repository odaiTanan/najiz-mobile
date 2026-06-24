import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/support/errors/support_api_exception.dart';
import 'package:najiz_go_express/features/support/models/cms_page_model.dart';
import 'package:najiz_go_express/features/support/models/faq_item_model.dart';
import 'package:najiz_go_express/features/support/models/support_chat_models.dart';

class SupportRepository {
  SupportRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, SupportApiException.fromHome);
  }

  Future<int> getCurrentUserId({required String token}) {
    return _run(() async {
      final data = await _api.getRaw(path: Endpoints.profile, token: token);
      final root = ApiResponse.asMap(data);
      final map = ApiResponse.extractDataMap(data);
      final id = ApiResponse.asInt(map['id']) ?? ApiResponse.asInt(root['id']);
      if (id == null) {
        throw SupportApiException('تعذر تحميل بيانات المستخدم');
      }
      return id;
    });
  }

  Future<SupportConversation> getUserConversation({required String token}) {
    return _run(() async {
      final data = await _api.getRaw(
        path: Endpoints.chatSupportConversation,
        token: token,
      );
      final root = ApiResponse.asMap(data);
      final map = ApiResponse.extractDataMap(data);
      final id = ApiResponse.asInt(map['id']) ?? ApiResponse.asInt(root['id']);
      if (id == null) {
        throw SupportApiException('تعذر تحميل المحادثة');
      }
      return SupportConversation(
        id: id,
        name: (map['name'] ?? 'الدعم الفني').toString(),
        avatar: map['avatar']?.toString(),
      );
    });
  }

  Future<List<SupportChatMessage>> getMessages({
    required String token,
    required int conversationId,
  }) {
    return _run(() async {
      final data = await _api.getRaw(
        path: Endpoints.chatMessages(conversationId),
        token: token,
      );
      final list = ApiResponse.extractDataList(data);
      return list.map(_toMessage).toList(growable: false);
    });
  }

  Future<SupportChatMessage> sendMessage({
    required String token,
    required int conversationId,
    required String message,
  }) {
    return _run(() async {
      final data = await _api.postRaw(
        path: Endpoints.chatMessages(conversationId),
        token: token,
        body: {'message': message},
      );
      final map = ApiResponse.extractDataMap(
        data,
        fallback: ApiResponse.asMap(data),
      );
      return _toMessage(map);
    });
  }

  Future<void> markMessagesAsRead({
    required String token,
    required int conversationId,
    required List<int> messageIds,
  }) {
    if (messageIds.isEmpty) return Future.value();
    return _run(
      () => _api.postRaw(
        path: Endpoints.chatMessagesRead(conversationId),
        token: token,
        body: {'message_ids': messageIds},
      ),
    );
  }

  /// GET /pages/{slug} — dynamic CMS pages (about-us, privacy-policy, …).
  Future<CmsPage> getCmsPage({String? token, required String slug}) {
    return _run(() async {
      final normalized = slug.trim().replaceAll(RegExp(r'^/+|/+$'), '');
      if (normalized.isEmpty) {
        throw SupportApiException('مسار الصفحة غير صالح');
      }
      final data = await _api.getEnvelope(
        path: Endpoints.cmsPage(normalized),
        token: token,
      );
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return CmsPage.fromJson(inner);
      }
      if (inner is Map) {
        return CmsPage.fromJson(
          inner.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      throw SupportApiException('استجابة غير متوقعة من الخادم');
    });
  }

  /// GET /pages/faq — frequently asked questions.
  Future<List<FaqItem>> getFaqList({String? token}) {
    return _run(() async {
      final data = await _api.getEnvelope(path: Endpoints.faq, token: token);
      final raw = data['data'];
      if (raw is! List) return const [];
      final list = raw
          .whereType<Map>()
          .map(
            (e) => FaqItem.fromJson(e.map((k, v) => MapEntry(k.toString(), v))),
          )
          .toList();
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return list;
    });
  }
}

SupportChatMessage _toMessage(Map<String, dynamic> map) {
  final sender = map['sender'];
  String? senderName;
  if (sender is Map) {
    senderName = sender['name']?.toString();
  }
  return SupportChatMessage(
    id: ApiResponse.asInt(map['id']) ?? DateTime.now().millisecondsSinceEpoch,
    conversationId: ApiResponse.asInt(map['conversation_id']) ?? 0,
    senderId: ApiResponse.asInt(map['sender_id']) ?? 0,
    message: (map['message'] ?? '').toString(),
    createdAt:
        (map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
    senderName: senderName,
    isReadByMe: ApiResponse.asBool(map['is_read_by_me']),
    readCount: ApiResponse.asInt(map['read_count']) ?? 0,
  );
}
