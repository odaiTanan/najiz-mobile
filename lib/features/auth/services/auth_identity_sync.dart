import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';

Future<void> syncUserIdentityFromBackend({
  required AuthRepository repository,
  required String authToken,
  required String fallbackPhone,
}) async {
  try {
    final user = await repository.getCurrentUser(token: authToken);
    final name = (user?['name'] ?? user?['full_name'] ?? '').toString().trim();
    final phone = (user?['phone'] ?? fallbackPhone).toString().trim();
    final email = (user?['email'] ?? '').toString().trim();
    await SessionService.saveUserIdentity(
      name: name.isEmpty ? null : name,
      phone: phone.isEmpty ? fallbackPhone : phone,
      email: email.isEmpty ? null : email,
    );
  } catch (_) {
    await SessionService.saveUserIdentity(phone: fallbackPhone);
  }
}

Future<void> completeAuthenticatedSession({
  required AuthRepository repository,
  required String token,
  required String fallbackPhone,
}) async {
  await syncUserIdentityFromBackend(
    repository: repository,
    authToken: token,
    fallbackPhone: fallbackPhone,
  );
  await Get.find<AuthStateManager>().markAuthenticated(token);
}
