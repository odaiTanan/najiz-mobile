import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';
import 'package:najiz_go_express/core/services/no_internet_gate_controller.dart';
import 'package:najiz_go_express/core/utils/error_mappers.dart';

bool _isConnectivityMessage(String message) {
  if (ErrorMappers.isNoInternetErrorMessage(message)) return true;
  return message == AppErrorMessages.noInternet ||
      message == AppErrorMessages.connectionFailed ||
      message == AppErrorMessages.requestTimeout;
}

extension HomeApiExceptionConnectivity on HomeApiException {
  bool get isConnectivityIssue => _isConnectivityMessage(message);
}

extension FeatureApiExceptionConnectivity on FeatureApiException {
  bool get isConnectivityIssue => _isConnectivityMessage(message);
}

/// يعرض [NoInternetGateController] عند فشل طلب يبدو بسبب الشبكة.
void showNoInternetGateIfNeeded(
  HomeApiException e, {
  required Future<void> Function() retry,
}) {
  if (!e.isConnectivityIssue) return;
  if (!Get.isRegistered<NoInternetGateController>()) return;
  Get.find<NoInternetGateController>().open(retry);
}

void showNoInternetGateIfNeededFeature(
  FeatureApiException e, {
  required Future<void> Function() retry,
}) {
  if (!e.isConnectivityIssue) return;
  if (!Get.isRegistered<NoInternetGateController>()) return;
  Get.find<NoInternetGateController>().open(retry);
}
