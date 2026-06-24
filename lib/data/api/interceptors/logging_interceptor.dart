import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/data/api/interceptors/api_interceptor.dart';

/// Debug-only request/response logging (mirrors legacy repository logs).
class LoggingInterceptor extends ApiInterceptor {
  LoggingInterceptor({this.maxBodyChars = 420, this.tag = 'API'});

  final int maxBodyChars;
  final String tag;

  @override
  void onRequest(ApiRequestContext context) {
    if (!kDebugMode) return;
    print('[$tag][REQ] ${context.method} ${context.uri}');
    if (context.body != null) {
      print('[$tag][REQ][BODY] ${_shorten(context.body!)}');
    }
  }

  @override
  void onResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    if (!kDebugMode) return;
    print('[$tag][RES] $method $uri -> ${response.statusCode}');
    print(
      '[$tag][RES][BODY] ${_shorten(response.body)} '
      '(len=${response.body.length})',
    );
  }

  @override
  void onError({
    required String method,
    required Uri uri,
    required Object error,
  }) {
    if (!kDebugMode) return;
    print('[$tag][ERR] $method $uri -> $error');
  }

  String _shorten(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxBodyChars) return compact;
    return '${compact.substring(0, maxBodyChars)}...';
  }
}

/// Auth-specific log tag for backward-compatible debug output.
class AuthLoggingInterceptor extends LoggingInterceptor {
  AuthLoggingInterceptor() : super(tag: 'AUTH');
}
