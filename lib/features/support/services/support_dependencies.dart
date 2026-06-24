import 'package:get/get.dart';
import 'package:najiz_go_express/features/support/repositories/support_repository.dart';
import 'package:najiz_go_express/features/support/services/support_chat_presence_service.dart';

void registerSupportDependencies() {
  if (!Get.isRegistered<SupportRepository>()) {
    Get.put(SupportRepository(), permanent: true);
  }
  if (!Get.isRegistered<SupportChatPresenceService>()) {
    Get.put(SupportChatPresenceService(), permanent: true);
  }
}

SupportRepository resolveSupportRepository([SupportRepository? override]) {
  return override ?? Get.find<SupportRepository>();
}

SupportChatPresenceService resolveSupportChatPresenceService([
  SupportChatPresenceService? override,
]) {
  if (override != null) return override;
  if (!Get.isRegistered<SupportChatPresenceService>()) {
    registerSupportDependencies();
  }
  return Get.find<SupportChatPresenceService>();
}
