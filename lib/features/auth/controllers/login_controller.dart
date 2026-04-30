import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';
import 'package:najiz_go_express/core/widgets/no_internet_screen.dart';
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

  void togglePasswordVisibility() {
    isPasswordHidden.value = !isPasswordHidden.value;
  }

  Future<void> login() async {
    errorMessage.value = null;
    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    isLoading.value = true;
    try {
      await _performLoginAttempt();
    } on AuthApiException catch (e) {
      if (ErrorMappers.isNoInternetErrorMessage(e.message)) {
        // Stop button loading and show full-screen offline retry.
        isLoading.value = false;
        await Get.dialog(
          NoInternetScreen(
            onRetry: _performLoginAttempt,
            onError: (err) {
              if (err is AuthApiException) {
                final raw = err.message;
                if (!ErrorMappers.isNoInternetErrorMessage(raw)) {
                  final mapped = ErrorMappers.mapLoginErrorMessage(raw);
                  errorMessage.value = mapped;
                  Get.snackbar('خطأ', mapped);
                  Get.back();
                }
              }
            },
          ),
          barrierDismissible: false,
        );
        return;
      }

      final mapped = ErrorMappers.mapLoginErrorMessage(e.message);
      errorMessage.value = mapped;
      debugPrint(
        'Login API error: status=${e.statusCode}, message=${e.message}',
      );
      Get.snackbar('خطأ', mapped);
    } on TimeoutException catch (e) {
      debugPrint('Login timeout: $e');
      isLoading.value = false;
      await Get.dialog(
        NoInternetScreen(
          onRetry: _performLoginAttempt,
          onError: (err) {
            if (err is AuthApiException) {
              final raw = err.message;
              if (!ErrorMappers.isNoInternetErrorMessage(raw)) {
                final mapped = ErrorMappers.mapLoginErrorMessage(raw);
                errorMessage.value = mapped;
                Get.snackbar('خطأ', mapped);
                Get.back();
              }
            }
          },
        ),
        barrierDismissible: false,
      );
      return;
    } on SocketException catch (e) {
      debugPrint('Login socket error: $e');
      isLoading.value = false;
      await Get.dialog(
        NoInternetScreen(
          onRetry: _performLoginAttempt,
          onError: (err) {
            if (err is AuthApiException) {
              final raw = err.message;
              if (!ErrorMappers.isNoInternetErrorMessage(raw)) {
                final mapped = ErrorMappers.mapLoginErrorMessage(raw);
                errorMessage.value = mapped;
                Get.snackbar('خطأ', mapped);
                Get.back();
              }
            }
          },
        ),
        barrierDismissible: false,
      );
      return;
    } catch (e) {
      errorMessage.value = 'خطأ في الشبكة';
      debugPrint('Login unexpected error: $e');
      Get.snackbar('خطأ', 'خطأ في الشبكة');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _performLoginAttempt() async {
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
    final fallbackPhone = phoneOrEmailController.text.trim();
    if (token != null && token!.isNotEmpty) {
      await _syncIdentityFromBackend(
        authToken: token!,
        fallbackPhone: fallbackPhone,
      );
      await Get.find<AuthStateManager>().markAuthenticated(token!);
    } else {
      await SessionService.saveUserIdentity(phone: fallbackPhone);
    }
    Get.snackbar('تم بنجاح', result.message);
    Get.offAll(() => HomeScreen(token: token));
  }

  @override
  void onClose() {
    phoneOrEmailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}

