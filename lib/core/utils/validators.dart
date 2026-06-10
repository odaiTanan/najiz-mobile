import 'package:get/get.dart';

class Validators {
  static String? requiredField(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'validation.required'.tr;
    }
    return null;
  }

  static String? emailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.phoneOrEmailRequired'.tr;
    }
    return null;
  }

  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.enterName'.tr;
    }
    if (value.trim().length < 2) {
      return 'validation.nameTooShort'.tr;
    }
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.enterEmail'.tr;
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) {
      return 'validation.emailInvalid'.tr;
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.enterPhone'.tr;
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'validation.phoneDigitsOnly'.tr;
    }
    if (!trimmed.startsWith('09')) {
      return 'validation.phoneStart09'.tr;
    }
    if (trimmed.length != 10) {
      return 'validation.phone10Digits'.tr;
    }
    return null;
  }

  static String? syrianMobileLocal(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.enterMobile'.tr;
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'validation.mobileDigitsOnly'.tr;
    }
    if (!trimmed.startsWith('9')) {
      return 'validation.mobileStart9'.tr;
    }
    if (trimmed.length != 9) {
      return 'validation.mobile9Digits'.tr;
    }
    return null;
  }

  static String? otpCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'validation.otpRequired'.tr;
    }
    final trimmed = value.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      return 'validation.otp6Digits'.tr;
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'validation.enterPassword'.tr;
    }
    if (value.length < 6) {
      return 'validation.password6Min'.tr;
    }
    return null;
  }

  static String? password8(String? value) {
    if (value == null || value.isEmpty) {
      return 'validation.enterPassword'.tr;
    }
    if (value.length < 8) {
      return 'validation.password8Min'.tr;
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'validation.passwordNeedsLower'.tr;
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'validation.passwordNeedsUpper'.tr;
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'validation.passwordNeedsDigit'.tr;
    }
    return null;
  }
}
