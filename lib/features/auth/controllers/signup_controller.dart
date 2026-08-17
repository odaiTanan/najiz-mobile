import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/core/utils/validators.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/services/auth_dependencies.dart';
import 'package:najiz_go_express/features/auth/services/auth_request_runner.dart';
import 'package:najiz_go_express/features/auth/views/otp_verification_screen.dart';

class SignupController extends GetxController {
  SignupController({AuthRepository? authRepository})
      : _authRepository = resolveAuthRepository(authRepository);

  final AuthRepository _authRepository;

  final formKey = GlobalKey<FormState>();
  static const String fixedCountryCode = '+963';

  final nameController = TextEditingController();
  final countryCodeController = TextEditingController(text: fixedCountryCode);
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final referralCodeController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordHidden = true.obs;
  final isConfirmPasswordHidden = true.obs;
  final isPasswordStrong = false.obs;
  final passwordLiveMessage = RxnString();

  final errorMessage = RxnString();

  String get fullPhoneNumber =>
      '$fixedCountryCode${phoneController.text.trim()}';

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordHidden.value = !isConfirmPasswordHidden.value;
  }

  void onPasswordChanged(String value) {
    if (value.isEmpty) {
      isPasswordStrong.value = false;
      passwordLiveMessage.value = null;
      return;
    }

    final validationError = Validators.password8(value);
    if (validationError == null) {
      isPasswordStrong.value = true;
      passwordLiveMessage.value = 'auth.passwordStrong'.tr;
      return;
    }

    isPasswordStrong.value = false;
    passwordLiveMessage.value = validationError;
  }

  Future<void> signUp() async {
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
        attempt: _performSignUpAttempt,
        mapError: ErrorMappers.mapSignupErrorMessage,
        setError: (message) => errorMessage.value = message,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _performSignUpAttempt() async {
    final result = await _authRepository.register(
      name: nameController.text.trim(),
      phone: fullPhoneNumber,
      password: passwordController.text,
      referralCode: referralCodeController.text.trim(),
    );

    await SessionService.saveUserIdentity(
      name: nameController.text.trim(),
      phone: fullPhoneNumber,
      referralCode: referralCodeController.text.trim(),
    );

    Get.to(
      () => OtpVerificationScreen(
        purpose: OtpPurpose.signup,
        phone: result.phone ?? fullPhoneNumber,
      ),
    );
  }

  @override
  void onClose() {
    nameController.dispose();
    countryCodeController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    referralCodeController.dispose();
    super.onClose();
  }
}
