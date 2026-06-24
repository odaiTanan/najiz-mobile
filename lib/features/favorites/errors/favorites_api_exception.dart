import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class FavoritesApiException extends FeatureApiException {
  const FavoritesApiException(super.message, {super.statusCode});

  factory FavoritesApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return FavoritesApiException(error.message, statusCode: error.statusCode);
  }

  factory FavoritesApiException.fromHome(HomeApiException error) {
    return FavoritesApiException(error.message, statusCode: error.statusCode);
  }
}
