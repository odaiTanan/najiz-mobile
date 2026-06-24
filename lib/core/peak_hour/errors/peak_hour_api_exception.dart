import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class PeakHourApiException extends FeatureApiException {
  const PeakHourApiException(super.message, {super.statusCode});

  factory PeakHourApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return PeakHourApiException(error.message, statusCode: error.statusCode);
  }

  factory PeakHourApiException.fromHome(HomeApiException error) {
    return PeakHourApiException(error.message, statusCode: error.statusCode);
  }
}
