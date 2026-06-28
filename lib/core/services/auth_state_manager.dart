import 'package:get/get.dart';
import 'package:najiz_go_express/core/navigation/tab_session_cleanup.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';

enum AuthStatus { guest, authenticated }

typedef PendingIntentAction = Future<void> Function(String token);

class AuthStateManager extends GetxService {
  final status = AuthStatus.guest.obs;
  final token = RxnString();

  PendingIntentAction? _pendingIntent;

  bool get isAuthenticated =>
      status.value == AuthStatus.authenticated &&
      token.value != null &&
      token.value!.trim().isNotEmpty;

  bool get isGuest => !isAuthenticated;

  Future<void> initialize({String? initialToken}) async {
    final resolved = initialToken ?? await SessionService.getToken();
    if (resolved != null && resolved.trim().isNotEmpty) {
      token.value = resolved;
      status.value = AuthStatus.authenticated;
      return;
    }
    token.value = null;
    status.value = AuthStatus.guest;
  }

  Future<void> markAuthenticated(String newToken) async {
    final previousToken = token.value?.trim();
    final normalized = newToken.trim();
    final sessionChanged = previousToken == null ||
        previousToken.isEmpty ||
        previousToken != normalized;
    if (sessionChanged) {
      TabSessionCleanup.resetAfterAuthChange();
    }
    await SessionService.saveToken(normalized);
    token.value = normalized;
    status.value = AuthStatus.authenticated;
    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().subscribeDevice(normalized);
    }
    await consumePendingIntentIfAny();
  }

  Future<void> markGuest() async {
    final previousToken = token.value;
    if (previousToken != null &&
        previousToken.trim().isNotEmpty &&
        Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().unsubscribeDevice(
        previousToken,
      );
    }
    if (Get.isRegistered<PushNotificationService>()) {
      await Get.find<PushNotificationService>().clearLocalHistory();
    }
    TabSessionCleanup.resetAfterAuthChange();
    await SessionService.clearSession();
    token.value = null;
    status.value = AuthStatus.guest;
  }

  void setPendingIntent(PendingIntentAction action) {
    _pendingIntent = action;
  }

  Future<void> consumePendingIntentIfAny() async {
    final intent = _pendingIntent;
    final authToken = token.value;
    _pendingIntent = null;
    if (intent == null || authToken == null || authToken.trim().isEmpty) return;
    await intent(authToken);
  }
}
