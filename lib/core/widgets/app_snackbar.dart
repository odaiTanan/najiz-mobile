import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

/// تنسيق موحّد لـ Get.snackbar: خلفية بيضاء صلبة (بدون شفافية/blur الافتراضي لـ GetX).
class AppSnackbar {
  AppSnackbar._();

  static SnackbarController show(
    String title,
    String message, {
    SnackPosition? snackPosition,
    Duration? duration,
    Color? colorText,
    Color? backgroundColor,
    Widget? icon,
    bool? isDismissible,
    bool? shouldIconPulse,
    double? borderRadius,
    EdgeInsets? margin,
    EdgeInsets? padding,
  }) {
    return Get.snackbar(
      title,
      message,
      snackPosition: snackPosition ?? SnackPosition.TOP,
      duration: duration ?? const Duration(seconds: 3),
      colorText: colorText ?? AppColors.textPrimary,
      backgroundColor: backgroundColor ?? Colors.white,
      barBlur: 0,
      icon: icon,
      isDismissible: isDismissible ?? true,
      shouldIconPulse: shouldIconPulse ?? false,
      borderRadius: borderRadius ?? 14,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadows: const [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
}
