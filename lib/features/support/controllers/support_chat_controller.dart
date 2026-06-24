import 'package:get/get.dart';
import 'package:najiz_go_express/features/support/models/support_chat_models.dart';
import 'package:najiz_go_express/features/support/services/support_chat_presence_service.dart';
import 'package:najiz_go_express/features/support/services/support_dependencies.dart';

class SupportChatController extends GetxController {
  SupportChatController({required this.token})
      : _presence = resolveSupportChatPresenceService();

  final String token;
  final SupportChatPresenceService _presence;

  RxBool get isLoading => _presence.isLoading;
  RxBool get isSending => _presence.isSending;
  RxnString get errorMessage => _presence.errorMessage;
  RxList<SupportChatMessage> get messages => _presence.messages;
  RxnInt get currentUserId => _presence.currentUserId;
  Rxn<SupportConversation> get conversation => _presence.conversation;
  RxString get supportAgentName => _presence.supportAgentName;

  @override
  void onInit() {
    super.onInit();
    _presence.setChatScreenOpen(true);
    loadInitialData();
  }

  @override
  void onClose() {
    _presence.setChatScreenOpen(false);
    super.onClose();
  }

  Future<void> loadInitialData() {
    return _presence.ensureLoaded(token, force: true);
  }

  Future<void> fetchMessages() {
    return _presence.fetchMessages();
  }

  Future<void> sendMessage(String text) {
    return _presence.sendMessage(text);
  }
}
