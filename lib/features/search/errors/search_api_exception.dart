import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class SearchApiException extends FeatureApiException {
  const SearchApiException(super.message, {super.statusCode});

  factory SearchApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return SearchApiException(error.message, statusCode: error.statusCode);
  }

  factory SearchApiException.fromHome(HomeApiException error) {
    return SearchApiException(error.message, statusCode: error.statusCode);
  }
}
