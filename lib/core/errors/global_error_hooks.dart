import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';

/// Installs Flutter-wide handlers so users never see the default red error screen.
void installGlobalErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kDebugMode) {
      debugPrint('[FlutterError] ${details.exceptionAsString()}');
      if (details.stack != null) {
        debugPrint('${details.stack}');
      }
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      debugPrint('[PlatformDispatcher] $error\n$stack');
    }
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      debugPrint('[ErrorWidget] ${details.exceptionAsString()}');
    }
    return Material(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            AppErrorMessages.displayError,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Color(0xFF1A2B48),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  };
}
