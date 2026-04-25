import 'package:flutter/material.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
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

  @override
  void onInit() {
    super.onInit();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    remainingSeconds.value = 119;
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
      final result = await _authRepository.resendOtp(phone: phone);
      Get.snackbar('رمز التحقق', result.message);
      _startCountdown();
    } on AuthApiException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar('خطأ', e.message);
    } catch (_) {
      errorMessage.value = 'خطأ في الشبكة';
      Get.snackbar('خطأ', 'خطأ في الشبكة');
    }
  }

  Future<void> submit() async {
    errorMessage.value = null;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    final code = codeController.text.trim();
    isLoading.value = true;
    try {
      final result = await _authRepository.verifyOtp(
        phone: phone,
        code: code,
      );

      if (purpose == OtpPurpose.forgotPassword) {
        Get.to(
          () => ResetPasswordScreen(
            phone: phone,
            code: code,
          ),
        );
        return;
      }

      if (result.token != null && result.token!.trim().isNotEmpty) {
        await SessionService.saveUserIdentity(phone: phone);
        await Get.find<AuthStateManager>().markAuthenticated(result.token!);
      }
      Get.offAll(() => HomeScreen(token: result.token));
    } on AuthApiException catch (e) {
      errorMessage.value = e.message;
      Get.snackbar('خطأ', e.message);
    } catch (_) {
      errorMessage.value = 'خطأ في الشبكة';
      Get.snackbar('خطأ', 'خطأ في الشبكة');
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

