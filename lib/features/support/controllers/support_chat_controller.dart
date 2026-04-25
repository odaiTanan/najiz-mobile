import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/chat_websocket_service.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/data/repositories/support_repository.dart';
import 'package:najiz_go_express/features/support/models/support_chat_models.dart';

class SupportChatController extends GetxController {
  SupportChatController({required this.token, SupportRepository? repository})
    : _repository = repository ?? SupportRepository();

  final String token;
  final SupportRepository _repository;

  final isLoading = true.obs;
  final isSending = false.obs;
  final errorMessage = RxnString();
  final messages = <SupportChatMessage>[].obs;
  final currentUserId = RxnInt();
  final conversation = Rxn<SupportConversation>();

  ChatWebSocketService? _chatWs;

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final results = await Future.wait([
        _repository.getCurrentUserId(token: token),
        _repository.getUserConversation(token: token),
      ]);
      currentUserId.value = results[0] as int;
      conversation.value = results[1] as SupportConversation;
      await _loadMessages();
      await _connectRealtime();
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'تعذر تحميل محادثة الدعم الفني';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadMessages() async {
    final conv = conversation.value;
    if (conv == null) return;
    final loaded = await _repository.getMessages(
      token: token,
      conversationId: conv.id,
    );
    messages.assignAll(loaded);
  }

  Future<void> _connectRealtime() async {
    final conv = conversation.value;
    if (conv == null) return;
    _chatWs = ChatWebSocketService(token: token);
    await _chatWs!.subscribeToConversation(
      conversationId: conv.id,
      onMessage: (payload) {
        final incoming = _toMessage(payload);
        if (messages.any((m) => m.id == incoming.id)) return;
        messages.add(incoming);
      },
    );
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isSending.value) return;
    final conv = conversation.value;
    if (conv == null) return;

    isSending.value = true;
    try {
      final sent = await _repository.sendMessage(
        token: token,
        conversationId: conv.id,
        message: trimmed,
      );
      if (!messages.any((m) => m.id == sent.id)) {
        messages.add(sent);
      }
    } on HomeApiException catch (e) {
      throw e.message;
    } catch (_) {
      throw 'تعذر إرسال الرسالة';
    } finally {
      isSending.value = false;
    }
  }

  @override
  void onClose() {
    _chatWs?.disconnect();
    super.onClose();
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

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
