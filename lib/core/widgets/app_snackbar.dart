import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

/// تنسيق موحّد لـ Get.snackbar: خلفية بيضاء صلبة (بدون شفافية/blur الافتراضي لـ GetX).
class AppSnackbar {
  AppSnackbar._();

  static void show(
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
    if (!_canPresent()) return;

    final config = _SnackbarConfig(
      title: title,
      message: message,
      snackPosition: snackPosition ?? SnackPosition.TOP,
      duration: duration ?? const Duration(seconds: 3),
      colorText: colorText ?? AppColors.textPrimary,
      backgroundColor: backgroundColor ?? Colors.white,
      icon: icon,
      isDismissible: isDismissible ?? true,
      shouldIconPulse: shouldIconPulse ?? false,
      borderRadius: borderRadius ?? 14,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    SchedulerBinding.instance.addPostFrameCallback((_) {
      _present(config);
    });
  }

  static bool _canPresent() {
    final ctx = Get.context;
    return ctx != null && ctx.mounted;
  }

  static void _present(_SnackbarConfig config) {
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) return;

    try {
      Get.snackbar(
        config.title,
        config.message,
        snackPosition: config.snackPosition,
        duration: config.duration,
        colorText: config.colorText,
        backgroundColor: config.backgroundColor,
        barBlur: 0,
        icon: config.icon,
        isDismissible: config.isDismissible,
        shouldIconPulse: config.shouldIconPulse,
        borderRadius: config.borderRadius,
        margin: config.margin,
        padding: config.padding,
        boxShadows: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );
    } catch (_) {
      // Ignore overlay races during route transitions.
    }
  }
}

class _SnackbarConfig {
  const _SnackbarConfig({
    required this.title,
    required this.message,
    required this.snackPosition,
    required this.duration,
    required this.colorText,
    required this.backgroundColor,
    required this.icon,
    required this.isDismissible,
    required this.shouldIconPulse,
    required this.borderRadius,
    required this.margin,
    required this.padding,
  });

  final String title;
  final String message;
  final SnackPosition snackPosition;
  final Duration duration;
  final Color colorText;
  final Color backgroundColor;
  final Widget? icon;
  final bool isDismissible;
  final bool shouldIconPulse;
  final double borderRadius;
  final EdgeInsets margin;
  final EdgeInsets padding;
}
