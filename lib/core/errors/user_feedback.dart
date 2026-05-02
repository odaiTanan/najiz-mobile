import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/error_sanitizer.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';

/// Central snackbars for errors — never shows raw stack traces or HTTP dumps.
class UserFeedback {
  UserFeedback._();

  static const String _defaultTitle = 'تنبيه';

  static String _messageFor(Object error) {
    if (error is String) return error;
    if (error is HomeApiException) return error.message;
    if (error is AuthApiException) {
      return ErrorSanitizer.serverToUser(error.message, error.statusCode);
    }
    return ErrorSanitizer.anyToUser(error);
  }

  static void showError(
    Object error, {
    String title = _defaultTitle,
  }) {
    final msg = _messageFor(error);
    if (kDebugMode) {
      debugPrint('[UserFeedback] $title: $msg (${error.runtimeType})');
    }
    if (Get.isSnackbarOpen == true) {
      Get.closeAllSnackbars();
    }
    if (Get.key.currentContext != null || Get.overlayContext != null) {
      Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
    }
  }

  static void showGenericError() {
    showError(AppErrorMessages.unexpected);
  }
}
