import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/views/otp_verification_screen.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';

class LoginController extends GetxController {
  LoginController({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

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
      final result = await _authRepository.login(
        phone: phoneOrEmailController.text.trim(),
        password: passwordController.text,
      );

      if (result.needsVerification) {
        errorMessage.value = result.message;
        Get.snackbar('رمز التحقق', result.message);
        Get.to(
          () => OtpVerificationScreen(
            purpose: OtpPurpose.login,
            phone: result.phone ?? phoneOrEmailController.text.trim(),
          ),
        );
        return;
      }

      token = result.token;
      await SessionService.saveUserIdentity(
        phone: phoneOrEmailController.text.trim(),
      );
      if (token != null && token!.isNotEmpty) {
        await Get.find<AuthStateManager>().markAuthenticated(token!);
      }
      Get.snackbar('تم بنجاح', result.message);
      Get.offAll(() => HomeScreen(token: token));
    } on AuthApiException catch (e) {
      errorMessage.value = e.message;
      debugPrint('Login API error: status=${e.statusCode}, message=${e.message}');
      Get.snackbar('خطأ', e.message);
    } on TimeoutException catch (e) {
      errorMessage.value = 'انتهت مهلة الخادم. يرجى المحاولة مرة أخرى.';
      debugPrint('Login timeout: $e');
      Get.snackbar(
        'خطأ',
        'انتهت مهلة الخادم. يرجى التحقق من الاتصال ومحاولة مرة أخرى.',
      );
    } on SocketException catch (e) {
      errorMessage.value = 'لا يوجد اتصال بالإنترنت';
      debugPrint('Login socket error: $e');
      Get.snackbar('خطأ', 'لا يوجد اتصال بالإنترنت');
    } catch (e) {
      errorMessage.value = 'خطأ في الشبكة';
      debugPrint('Login unexpected error: $e');
      Get.snackbar('خطأ', 'خطأ في الشبكة');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    phoneOrEmailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

