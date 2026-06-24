import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class TaxiApiException extends FeatureApiException {
  const TaxiApiException(super.message, {super.statusCode});

  factory TaxiApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return TaxiApiException(error.message, statusCode: error.statusCode);
  }

  factory TaxiApiException.fromHome(HomeApiException error) {
    return TaxiApiException(error.message, statusCode: error.statusCode);
  }
}
