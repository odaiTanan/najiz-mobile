import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/services/auth_dependencies.dart';
import 'package:najiz_go_express/features/auth/services/auth_identity_sync.dart';
import 'package:najiz_go_express/features/auth/services/auth_request_runner.dart';
import 'package:najiz_go_express/features/auth/views/otp_verification_screen.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';

class LoginController extends GetxController {
  LoginController({AuthRepository? authRepository})
      : _authRepository = resolveAuthRepository(authRepository);

  final AuthRepository _authRepository;

  final formKey = GlobalKey<FormState>();

  final phoneOrEmailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordHidden = true.obs;

  final errorMessage = RxnString();

  String? token;

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> login() async {
    errorMessage.value = null;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    isLoading.value = true;
    try {
      await runAuthRequest(
        isLoading: isLoading,
        attempt: _performLoginAttempt,
        mapError: ErrorMappers.mapLoginErrorMessage,
        setError: (message) => errorMessage.value = message,
        onUnexpectedError: (e) => logAuthDebug('Login unexpected error: $e'),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _performLoginAttempt() async {
    final result = await _authRepository.login(
      phone: phoneOrEmailController.text.trim(),
      password: passwordController.text,
    );

    if (result.needsVerification) {
      errorMessage.value = result.message;
      AppSnackbar.show('auth.otpTitle'.tr, result.message);
      Get.to(
        () => OtpVerificationScreen(
          purpose: OtpPurpose.login,
          phone: result.phone ?? phoneOrEmailController.text.trim(),
        ),
      );
      return;
    }

    token = result.token;
    final fallbackPhone = phoneOrEmailController.text.trim();
    if (token != null && token!.isNotEmpty) {
      await completeAuthenticatedSession(
        repository: _authRepository,
        token: token!,
        fallbackPhone: fallbackPhone,
      );
    } else {
      await SessionService.saveUserIdentity(phone: fallbackPhone);
    }
    AppSnackbar.show('errors.success'.tr, result.message);
    AppRoutes.openHome(token: token);
  }

  @override
  void onClose() {
    phoneOrEmailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
