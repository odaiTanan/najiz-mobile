import 'package:najiz_go_express/core/errors/error_sanitizer.dart';

class HomeApiException implements Exception {
  final String message;
  final int? statusCode;

  HomeApiException(this.message, {this.statusCode});

  factory HomeApiException.fromServer(String? raw, int? statusCode) {
    return HomeApiException(
      ErrorSanitizer.serverToUser(raw, statusCode),
      statusCode: statusCode,
    );
  }

  @override
  String toString() => 'HomeApiException($statusCode): $message';
}
