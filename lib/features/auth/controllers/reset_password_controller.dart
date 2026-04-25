import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';

class ResetPasswordController extends GetxController {
  ResetPasswordController({
    required this.phone,
    required this.code,
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;

  final String phone;
  final String code;

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
      errorMessage.value = 'كلمتا المرور غير متطابقتين';
      return;
    }

    isLoading.value = true;
    try {
      final result = await _authRepository.resetPassword(
        phone: phone,
        code: code,
        password: passwordController.text,
      );

      Get.snackbar('تم بنجاح', result.message);
      Get.offAll(() => const HomeScreen());
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
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}

