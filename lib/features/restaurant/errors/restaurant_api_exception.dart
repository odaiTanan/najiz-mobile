import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class RestaurantApiException extends FeatureApiException {
  const RestaurantApiException(super.message, {super.statusCode});

  factory RestaurantApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return RestaurantApiException(error.message, statusCode: error.statusCode);
  }

  factory RestaurantApiException.fromHome(HomeApiException error) {
    return RestaurantApiException(error.message, statusCode: error.statusCode);
  }
}
