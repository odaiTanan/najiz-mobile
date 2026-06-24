import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class OrdersApiException extends FeatureApiException {
  const OrdersApiException(super.message, {super.statusCode});

  factory OrdersApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return OrdersApiException(error.message, statusCode: error.statusCode);
  }

  factory OrdersApiException.fromHome(HomeApiException error) {
    return OrdersApiException(error.message, statusCode: error.statusCode);
  }
}
