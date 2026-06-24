import 'package:najiz_go_express/core/errors/feature_api_exception.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

typedef ApiExceptionMapper = FeatureApiException Function(HomeApiException error);

Future<T> runWithMappedApiErrors<T>(
  Future<T> Function() action,
  ApiExceptionMapper map,
) async {
  try {
    return await action();
  } on HomeApiException catch (error) {
    throw map(error);
  }
}
