import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/services/auth_dependencies.dart';
import 'package:najiz_go_express/features/auth/services/auth_request_runner.dart';
import 'package:najiz_go_express/features/auth/views/otp_verification_screen.dart';

class ForgotPasswordController extends GetxController {
  ForgotPasswordController({AuthRepository? authRepository})
      : _authRepository = resolveAuthRepository(authRepository);

  final AuthRepository _authRepository;

  final formKey = GlobalKey<FormState>();
  final phoneController = TextEditingController();

  final isLoading = false.obs;
  final errorMessage = RxnString();

  Future<void> sendCode() async {
    errorMessage.value = null;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    isLoading.value = true;
    try {
      await runAuthRequest(
        isLoading: isLoading,
        attempt: _sendCodeAttempt,
        mapError: (raw) => raw,
        setError: (message) => errorMessage.value = message,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _sendCodeAttempt() async {
    final result = await _authRepository.forgotPassword(
      phone: phoneController.text.trim(),
    );

    Get.to(
      () => OtpVerificationScreen(
        purpose: OtpPurpose.forgotPassword,
        phone: result.phone ?? phoneController.text.trim(),
      ),
    );
  }

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}
