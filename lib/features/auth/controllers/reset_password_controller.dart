import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/services/auth_dependencies.dart';
import 'package:najiz_go_express/features/auth/services/auth_request_runner.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';

class ResetPasswordController extends GetxController {
  ResetPasswordController({
    required this.phone,
    required this.resetToken,
    AuthRepository? authRepository,
  }) : _authRepository = resolveAuthRepository(authRepository);

  final AuthRepository _authRepository;

  final String phone;
  final String resetToken;

  final formKey = GlobalKey<FormState>();

  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordHidden = true.obs;
  final errorMessage = RxnString();

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> resetPassword() async {
    errorMessage.value = null;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    if (passwordController.text != confirmPasswordController.text) {
      errorMessage.value = 'auth.passwordsMismatch'.tr;
      return;
    }

    isLoading.value = true;
    try {
      await runAuthRequest(
        isLoading: isLoading,
        attempt: _resetPasswordAttempt,
        mapError: (raw) => raw,
        setError: (message) => errorMessage.value = message,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _resetPasswordAttempt() async {
    final result = await _authRepository.resetPassword(
      phone: phone,
      resetToken: resetToken,
      password: passwordController.text,
    );

    AppSnackbar.show('errors.success'.tr, result.message);
    AppRoutes.openHome();
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
