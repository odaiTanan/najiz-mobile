import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';
import 'package:najiz_go_express/features/auth/views/reset_password_screen.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';

class OtpVerificationController extends GetxController {
  OtpVerificationController({
    required this.purpose,
    required this.phone,
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? AuthRepository();

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

  Future<void> _syncIdentityFromBackend({
    required String authToken,
    required String fallbackPhone,
  }) async {
    try {
      final user = await _authRepository.getCurrentUser(token: authToken);
      final name = (user?['name'] ?? user?['full_name'] ?? '')
          .toString()
          .trim();
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

  @override
  void onInit() {
    super.onInit();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    // Allow resend after ~1 minute.
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
      AppSnackbar.show('رمز التحقق', result.message);
      _startCountdown();
    } on AuthApiException catch (e) {
      errorMessage.value = e.message;
      AppSnackbar.show('خطأ', e.message);
    } catch (_) {
      errorMessage.value = 'خطأ في الشبكة';
      AppSnackbar.show('خطأ', 'خطأ في الشبكة');
    }
  }

  Future<void> submit() async {
    errorMessage.value = null;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    final code = codeController.text.trim();
    isLoading.value = true;
    try {
      if (purpose == OtpPurpose.forgotPassword) {
        final result = await _authRepository.verifyPasswordReset(
          phone: phone,
          otpToken: code,
        );
        final resetToken = result.resetToken;
        if (resetToken == null || resetToken.trim().isEmpty) {
          throw AuthApiException('تعذر استلام رمز إعادة التعيين من الخادم');
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
        code: code,
      );

      if (result.token != null && result.token!.trim().isNotEmpty) {
        await _syncIdentityFromBackend(
          authToken: result.token!,
          fallbackPhone: phone,
        );
        await Get.find<AuthStateManager>().markAuthenticated(result.token!);
      }
      Get.offAll(() => HomeScreen(token: result.token));
    } on AuthApiException catch (e) {
      final mapped = ErrorMappers.mapOtpErrorMessage(e.message);
      errorMessage.value = mapped;
      AppSnackbar.show('خطأ', mapped);
    } catch (_) {
      errorMessage.value = 'خطأ في الشبكة';
      AppSnackbar.show('خطأ', 'خطأ في الشبكة');
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

