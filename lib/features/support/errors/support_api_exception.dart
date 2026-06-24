import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class SupportApiException extends FeatureApiException {
  const SupportApiException(super.message, {super.statusCode});

  factory SupportApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return SupportApiException(error.message, statusCode: error.statusCode);
  }

  factory SupportApiException.fromHome(HomeApiException error) {
    return SupportApiException(error.message, statusCode: error.statusCode);
  }
}
