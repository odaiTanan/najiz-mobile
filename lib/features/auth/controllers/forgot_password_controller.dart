import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/views/otp_verification_screen.dart';

class ForgotPasswordController extends GetxController {
  ForgotPasswordController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

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
      final result =
          await _authRepository.forgotPassword(phone: phoneController.text.trim());

      Get.to(
        () => OtpVerificationScreen(
          purpose: OtpPurpose.forgotPassword,
          phone: result.phone ?? phoneController.text.trim(),
        ),
      );
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

  @override
  void onClose() {
    phoneController.dispose();
    super.onClose();
  }
}

