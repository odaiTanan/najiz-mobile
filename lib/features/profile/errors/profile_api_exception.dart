import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

class ProfileApiException extends FeatureApiException {
  const ProfileApiException(super.message, {super.statusCode});

  factory ProfileApiException.fromServer(String? raw, int? statusCode) {
    final error = FeatureApiException.fromServer(raw, statusCode);
    return ProfileApiException(error.message, statusCode: error.statusCode);
  }

  factory ProfileApiException.fromHome(HomeApiException error) {
    return ProfileApiException(error.message, statusCode: error.statusCode);
  }
}
