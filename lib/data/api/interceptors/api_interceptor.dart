import 'package:http/http.dart' as http;

/// Mutable context passed through the interceptor chain before each request.
class ApiRequestContext {
  ApiRequestContext({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

abstract class ApiInterceptor {
  void onRequest(ApiRequestContext context) {}

  void onResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {}

  void onError({
    required String method,
    required Uri uri,
    required Object error,
  }) {}
}
