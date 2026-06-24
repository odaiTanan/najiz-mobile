import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';
import 'package:najiz_go_express/features/auth/errors/auth_api_exception.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/services/auth_dependencies.dart';
import 'package:najiz_go_express/features/auth/services/auth_identity_sync.dart';
import 'package:najiz_go_express/features/auth/views/reset_password_screen.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';

class OtpVerificationController extends GetxController {
  OtpVerificationController({
    required this.purpose,
    required this.phone,
    AuthRepository? authRepository,
  }) : _authRepository = resolveAuthRepository(authRepository);

  final OtpPurpose purpose;
  final String phone;
  final AuthRepository _authRepository;

  final formKey = GlobalKey<FormState>();
  final codeController = TextEditingController();

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final remainingSeconds = 119.obs;
  Timer? _countdownTimer;
  String? _lastAutoSubmittedCode;

  @override
  void onInit() {
    super.onInit();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    remainingSeconds.value = 60;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds.value <= 0) {
        timer.cancel();
        return;
      }
      remainingSeconds.value--;
    });
  }

  Future<void> resendCode() async {
    if (remainingSeconds.value > 0) return;
    try {
      final result = purpose == OtpPurpose.forgotPassword
          ? await _authRepository.forgotPassword(phone: phone)
          : await _authRepository.resendOtp(phone: phone);
      AppSnackbar.show('auth.otpTitle'.tr, result.message);
      _startCountdown();
    } on AuthApiException catch (e) {
      errorMessage.value = e.message;
      AppSnackbar.show('errors.generic'.tr, e.message);
    } catch (_) {
      errorMessage.value = 'auth.networkError'.tr;
      AppSnackbar.show('errors.generic'.tr, 'errors.networkError'.tr);
    }
  }

  Future<void> submit() async {
    errorMessage.value = null;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    isLoading.value = true;
    try {
      if (purpose == OtpPurpose.forgotPassword) {
        final result = await _authRepository.verifyPasswordReset(
          phone: phone,
          otpToken: codeController.text.trim(),
        );
        final resetToken = result.resetToken;
        if (resetToken == null || resetToken.trim().isEmpty) {
          throw AuthApiException('auth.resetTokenError'.tr);
        }
        Get.to(
          () => ResetPasswordScreen(
            phone: phone,
            resetToken: resetToken,
          ),
        );
        return;
      }

      final result = await _authRepository.verifyOtp(
        phone: phone,
        code: codeController.text.trim(),
      );

      if (result.token != null && result.token!.trim().isNotEmpty) {
        await completeAuthenticatedSession(
          repository: _authRepository,
          token: result.token!,
          fallbackPhone: phone,
        );
      }
      AppRoutes.openHome(token: result.token);
    } on AuthApiException catch (e) {
      final mapped = ErrorMappers.mapOtpErrorMessage(e.message);
      errorMessage.value = mapped;
      AppSnackbar.show('errors.generic'.tr, mapped);
    } catch (_) {
      errorMessage.value = 'auth.networkError'.tr;
      AppSnackbar.show('errors.generic'.tr, 'errors.networkError'.tr);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> onCodeChanged(String value) async {
    final code = value.trim();
    errorMessage.value = null;

    if (code.length != 6 || isLoading.value) return;
    if (_lastAutoSubmittedCode == code) return;

    _lastAutoSubmittedCode = code;
    await submit();

    if (errorMessage.value != null) {
      _lastAutoSubmittedCode = null;
    }
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    codeController.dispose();
    super.onClose();
  }
}
