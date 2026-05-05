import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/core/utils/validators.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';
import 'package:najiz_go_express/core/widgets/no_internet_screen.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/views/otp_verification_screen.dart';

class SignupController extends GetxController {
  SignupController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  final formKey = GlobalKey<FormState>();
  static const String fixedCountryCode = '+963';

  final nameController = TextEditingController();
  final emailController = TextEditingController();
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
      passwordLiveMessage.value = 'كلمة المرور قوية';
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
      errorMessage.value = 'كلمتا المرور غير متطابقتين';
      return;
    }

    isLoading.value = true;
    try {
      await _performSignUpAttempt();
    } on AuthApiException catch (e) {
      if (ErrorMappers.isNoInternetErrorMessage(e.message)) {
        isLoading.value = false;
        await Get.dialog(
          NoInternetScreen(
            onRetry: _performSignUpAttempt,
            onError: (err) {
              if (err is AuthApiException) {
                final raw = err.message;
                if (!ErrorMappers.isNoInternetErrorMessage(raw)) {
                  final mapped = ErrorMappers.mapSignupErrorMessage(raw);
                  errorMessage.value = mapped;
                  AppSnackbar.show('خطأ', mapped);
                  Get.back();
                }
              }
            },
          ),
          barrierDismissible: false,
        );
        return;
      }

      final mapped = ErrorMappers.mapSignupErrorMessage(e.message);
      errorMessage.value = mapped;
      AppSnackbar.show('خطأ', mapped);
    } on TimeoutException catch (_) {
      isLoading.value = false;
      await Get.dialog(
        NoInternetScreen(
          onRetry: _performSignUpAttempt,
          onError: (err) {
            if (err is AuthApiException) {
              final raw = err.message;
              if (!ErrorMappers.isNoInternetErrorMessage(raw)) {
                final mapped = ErrorMappers.mapSignupErrorMessage(raw);
                errorMessage.value = mapped;
                AppSnackbar.show('خطأ', mapped);
                Get.back();
              }
            }
          },
        ),
        barrierDismissible: false,
      );
      return;
    } on SocketException catch (_) {
      isLoading.value = false;
      await Get.dialog(
        NoInternetScreen(
          onRetry: _performSignUpAttempt,
          onError: (err) {
            if (err is AuthApiException) {
              final raw = err.message;
              if (!ErrorMappers.isNoInternetErrorMessage(raw)) {
                final mapped = ErrorMappers.mapSignupErrorMessage(raw);
                errorMessage.value = mapped;
                AppSnackbar.show('خطأ', mapped);
                Get.back();
              }
            }
          },
        ),
        barrierDismissible: false,
      );
      return;
    } catch (_) {
      errorMessage.value = 'خطأ في الشبكة';
      AppSnackbar.show('خطأ', 'خطأ في الشبكة');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _performSignUpAttempt() async {
    final result = await _authRepository.register(
      name: nameController.text.trim(),
      phone: fullPhoneNumber,
      email: emailController.text.trim(),
      password: passwordController.text,
      referralCode: referralCodeController.text.trim(),
    );

    await SessionService.saveUserIdentity(
      name: nameController.text.trim(),
      phone: fullPhoneNumber,
      email: emailController.text.trim(),
      referralCode: referralCodeController.text.trim(),
    );

    // Backend always sends OTP after registration.
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
    emailController.dispose();
    countryCodeController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    referralCodeController.dispose();
    super.onClose();
  }
}

