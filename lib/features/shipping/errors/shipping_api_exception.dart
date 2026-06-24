import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class ShippingApiException extends FeatureApiException {
  const ShippingApiException(super.message, {super.statusCode});

  factory ShippingApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return ShippingApiException(error.message, statusCode: error.statusCode);
  }

  factory ShippingApiException.fromHome(HomeApiException error) {
    return ShippingApiException(error.message, statusCode: error.statusCode);
  }
}
