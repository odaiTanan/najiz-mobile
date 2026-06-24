import 'package:najiz_go_express/data/api/interceptors/api_interceptor.dart';

/// Ensures JSON headers and optional Bearer token on every request.
class AuthInterceptor extends ApiInterceptor {
  AuthInterceptor({this.token});

  final String? token;

  @override
  void onRequest(ApiRequestContext context) {
    context.headers.putIfAbsent('Content-Type', () => 'application/json');
    context.headers.putIfAbsent('Accept', () => 'application/json');

    final resolved = token?.trim();
    if (resolved != null && resolved.isNotEmpty) {
      context.headers['Authorization'] = 'Bearer $resolved';
    }
  }
}
