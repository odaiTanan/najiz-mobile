import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/core/widgets/no_internet_screen.dart';
import 'package:najiz_go_express/features/auth/errors/auth_api_exception.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';

typedef AuthErrorMapper = String Function(String raw);

Future<void> runAuthRequest({
  required RxBool isLoading,
  required Future<void> Function() attempt,
  required AuthErrorMapper mapError,
  required void Function(String message) setError,
  void Function(Object error)? onUnexpectedError,
}) async {
  try {
    await attempt();
  } on AuthApiException catch (e) {
    if (ErrorMappers.isNoInternetErrorMessage(e.message)) {
      isLoading.value = false;
      await _showOfflineRetry(
        attempt: attempt,
        mapError: mapError,
        setError: setError,
      );
      return;
    }

    final mapped = mapError(e.message);
    setError(mapped);
    AppSnackbar.show('errors.generic'.tr, mapped);
  } on TimeoutException catch (e) {
    onUnexpectedError?.call(e);
    isLoading.value = false;
    await _showOfflineRetry(
      attempt: attempt,
      mapError: mapError,
      setError: setError,
    );
  } on SocketException catch (e) {
    onUnexpectedError?.call(e);
    isLoading.value = false;
    await _showOfflineRetry(
      attempt: attempt,
      mapError: mapError,
      setError: setError,
    );
  } catch (e) {
    onUnexpectedError?.call(e);
    setError('auth.networkError'.tr);
    AppSnackbar.show('errors.generic'.tr, 'errors.networkError'.tr);
  }
}

Future<void> _showOfflineRetry({
  required Future<void> Function() attempt,
  required AuthErrorMapper mapError,
  required void Function(String message) setError,
}) {
  return Get.dialog<void>(
    NoInternetScreen(
      onRetry: attempt,
      onError: (err) {
        if (err is AuthApiException) {
          final raw = err.message;
          if (!ErrorMappers.isNoInternetErrorMessage(raw)) {
            final mapped = mapError(raw);
            setError(mapped);
            AppSnackbar.show('errors.generic'.tr, mapped);
            Get.back();
          }
        }
      },
    ),
    barrierDismissible: false,
  );
}

void logAuthDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
