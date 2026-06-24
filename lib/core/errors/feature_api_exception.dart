import 'package:najiz_go_express/core/errors/error_sanitizer.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

/// Base API exception for feature-level error handling.
class FeatureApiException implements Exception {
  final String message;
  final int? statusCode;

  const FeatureApiException(this.message, {this.statusCode});

  factory FeatureApiException.fromServer(String? raw, int? statusCode) {
    return FeatureApiException(
      ErrorSanitizer.serverToUser(raw, statusCode),
      statusCode: statusCode,
    );
  }

  factory FeatureApiException.fromHome(HomeApiException error) {
    return FeatureApiException(error.message, statusCode: error.statusCode);
  }

  @override
  String toString() => 'FeatureApiException($statusCode): $message';
}
