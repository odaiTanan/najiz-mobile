import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class HomeFeatureApiException extends FeatureApiException {
  const HomeFeatureApiException(super.message, {super.statusCode});

  factory HomeFeatureApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return HomeFeatureApiException(error.message, statusCode: error.statusCode);
  }

  factory HomeFeatureApiException.fromHome(HomeApiException error) {
    return HomeFeatureApiException(error.message, statusCode: error.statusCode);
  }
}
