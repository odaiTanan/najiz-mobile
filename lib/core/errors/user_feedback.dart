import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/error_sanitizer.dart';
import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';
import 'package:najiz_go_express/features/auth/errors/auth_api_exception.dart';

/// Central snackbars for errors — never shows raw stack traces or HTTP dumps.
class UserFeedback {
  UserFeedback._();

  static String _messageFor(Object error) {
    if (error is String) return error;
    if (error is FeatureApiException) return error.message;
    if (error is HomeApiException) return error.message;
    if (error is AuthApiException) {
      return ErrorSanitizer.serverToUser(error.message, error.statusCode);
    }
    return ErrorSanitizer.anyToUser(error);
  }

  static void showError(
    Object error, {
    String? title,
  }) {
    final resolvedTitle = title ?? 'errors.title'.tr;
    final msg = _messageFor(error);
    if (kDebugMode) {
      debugPrint('[UserFeedback] $resolvedTitle: $msg (${error.runtimeType})');
    }
    if (Get.isSnackbarOpen == true) {
      Get.closeAllSnackbars();
    }
    if (Get.key.currentContext != null || Get.overlayContext != null) {
      AppSnackbar.show(resolvedTitle, msg, snackPosition: SnackPosition.BOTTOM);
    }
  }

  static void showGenericError() {
    showError(AppErrorMessages.unexpected);
  }
}
