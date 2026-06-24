import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';
import 'package:najiz_go_express/core/network/connectivity_guard.dart';
import 'package:najiz_go_express/data/api/api_get_cache.dart';
import 'package:najiz_go_express/data/api/api_response.dart';
import 'package:najiz_go_express/data/api/interceptors/api_interceptor.dart';
import 'package:najiz_go_express/data/api/interceptors/auth_interceptor.dart';
import 'package:najiz_go_express/data/api/interceptors/logging_interceptor.dart';

export 'package:najiz_go_express/data/api/api_response.dart';
export 'package:najiz_go_express/data/api/endpoints.dart';
export 'package:najiz_go_express/data/api/interceptors/api_interceptor.dart';
export 'package:najiz_go_express/data/api/interceptors/auth_interceptor.dart';
export 'package:najiz_go_express/data/api/interceptors/logging_interceptor.dart';

/// Central HTTP client for all REST API calls.
class ApiClient {
  ApiClient({
    http.Client? client,
    String baseUrl = ApiConfig.baseUrl,
    Duration? readTimeout,
    Duration? writeTimeout,
    List<ApiInterceptor>? interceptors,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl,
        _readTimeout = readTimeout ?? ApiConfig.readTimeout,
        _writeTimeout = writeTimeout ?? ApiConfig.writeTimeout,
        _interceptors = interceptors ??
            [
              LoggingInterceptor(),
            ];

  final http.Client _client;
  final String _baseUrl;
  final Duration _readTimeout;
  final Duration _writeTimeout;
  final List<ApiInterceptor> _interceptors;
  final ApiGetCache _getCache = ApiGetCache();

  String get baseUrl => _baseUrl;

  /// Default client with standard logging (used by home/support repositories).
  factory ApiClient.standard({http.Client? client, String? baseUrl}) {
    return ApiClient(
      client: client,
      baseUrl: baseUrl ?? ApiConfig.baseUrl,
      interceptors: [LoggingInterceptor()],
    );
  }

  /// Client for auth endpoints (AUTH log tag).
  factory ApiClient.auth({http.Client? client, String? baseUrl}) {
    return ApiClient(
      client: client,
      baseUrl: baseUrl ?? ApiConfig.baseUrl,
      interceptors: [AuthLoggingInterceptor()],
    );
  }

  Uri buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$_baseUrl$normalized');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }

  /// Low-level request with retry support. Returns raw [http.Response].
  Future<http.Response> request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    String? token,
    Map<String, String>? extraHeaders,
    int retries = 0,
    Duration retryDelay = const Duration(milliseconds: 800),
    bool requireConnectivity = true,
  }) async {
    final isGet = method.toUpperCase() == 'GET';
    if (requireConnectivity) {
      await ConnectivityGuard.requireOnline(optimistic: isGet);
    }

    final uri = buildUri(path, queryParameters: queryParameters);
    final headers = <String, String>{
      ...?extraHeaders,
    };

    final authInterceptor = AuthInterceptor(token: token);
    authInterceptor.onRequest(
      ApiRequestContext(
        method: method,
        uri: uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );

    final encodedBody = body != null ? jsonEncode(body) : null;
    final context = ApiRequestContext(
      method: method,
      uri: uri,
      headers: headers,
      body: encodedBody,
    );
    for (final interceptor in _interceptors) {
      interceptor.onRequest(context);
    }

    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final response = await _send(
          method: method,
          uri: uri,
          headers: headers,
          body: encodedBody,
        );
        for (final interceptor in _interceptors) {
          interceptor.onResponse(
            method: method,
            uri: uri,
            response: response,
          );
        }
        ConnectivityGuard.markRequestSucceeded();
        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        ConnectivityGuard.markRequestFailed();
        _notifyError(method, uri, e);
      } on SocketException catch (e) {
        lastError = e;
        ConnectivityGuard.markRequestFailed();
        _notifyError(method, uri, e);
      } on http.ClientException catch (e) {
        lastError = e;
        ConnectivityGuard.markRequestFailed();
        _notifyError(method, uri, e);
      }

      if (attempt < retries) {
        await Future.delayed(retryDelay);
      }
    }

    throw _mapNetworkError(lastError);
  }

  /// GET with success-envelope validation (legacy HomeRepository._get).
  Future<Map<String, dynamic>> getEnvelope({
    required String path,
    String? token,
    Map<String, String>? queryParameters,
    int retries = 0,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(
      method: 'GET',
      path: path,
      token: token,
      queryParameters: queryParameters,
    );
    final response = await _getCache.run(
      key: cacheKey,
      forceRefresh: forceRefresh,
      ttl: _cacheTtlForPath(path),
      fetch: () => request(
        method: 'GET',
        path: path,
        token: token,
        queryParameters: queryParameters,
        retries: retries,
      ),
    );
    final data = ApiResponse.safeDecodeMap(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        ApiResponse.isSuccess(data)) {
      return data;
    }
    throw HomeApiException.fromServer(
      ApiResponse.extractMessage(data),
      response.statusCode,
    );
  }

  /// GET that only checks HTTP status (legacy SupportRepository._get).
  Future<dynamic> getRaw({
    required String path,
    required String token,
    Map<String, String>? queryParameters,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _getCacheKey(
      method: 'GET',
      path: path,
      token: token,
      queryParameters: queryParameters,
    );
    final response = await _getCache.run(
      key: cacheKey,
      forceRefresh: forceRefresh,
      ttl: _cacheTtlForPath(path),
      fetch: () => request(
        method: 'GET',
        path: path,
        token: token,
        queryParameters: queryParameters,
      ),
    );
    final data = ApiResponse.safeDecodeAny(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw HomeApiException.fromServer(
      ApiResponse.extractMessage(ApiResponse.asMap(data)),
      response.statusCode,
    );
  }

  /// POST with success-envelope validation (status/success field).
  Future<Map<String, dynamic>> postEnvelope({
    required String path,
    required Map<String, dynamic> body,
    String? token,
    int retries = 0,
  }) async {
    final response = await request(
      method: 'POST',
      path: path,
      body: body,
      token: token,
      retries: retries,
    );
    final data = ApiResponse.safeDecodeMap(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        ApiResponse.isSuccess(data)) {
      return data;
    }
    throw HomeApiException.fromServer(
      ApiResponse.extractMessage(data),
      response.statusCode,
    );
  }

  /// POST that validates HTTP status only (support chat send/read).
  Future<Map<String, dynamic>> postRaw({
    required String path,
    required Map<String, dynamic> body,
    required String token,
  }) async {
    final response = await request(
      method: 'POST',
      path: path,
      body: body,
      token: token,
    );
    final data = ApiResponse.safeDecodeMap(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    throw HomeApiException.fromServer(
      ApiResponse.extractMessage(data),
      response.statusCode,
    );
  }

  /// DELETE with success-envelope validation.
  Future<void> deleteEnvelope({
    required String path,
    required String token,
  }) async {
    final response = await request(
      method: 'DELETE',
      path: path,
      token: token,
    );
    final data = ApiResponse.safeDecodeMap(response.body);
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        ApiResponse.isSuccess(data)) {
      return;
    }
    throw HomeApiException.fromServer(
      ApiResponse.extractMessage(data),
      response.statusCode,
    );
  }

  /// POST with retry, returns raw response (legacy AuthRepository).
  Future<http.Response> postWithRetry({
    required String path,
    required Map<String, dynamic> body,
    String? token,
    int retries = 1,
  }) {
    return request(
      method: 'POST',
      path: path,
      body: body,
      token: token,
      retries: retries,
    );
  }

  /// GET with auth, no envelope check (legacy AuthRepository._getWithAuth).
  Future<http.Response> getWithAuth({
    required String path,
    required String token,
    Map<String, String>? queryParameters,
  }) {
    return request(
      method: 'GET',
      path: path,
      token: token,
      queryParameters: queryParameters,
    );
  }

  /// POST with auth, no envelope check (legacy AuthRepository._postWithAuth).
  Future<http.Response> postWithAuth({
    required String path,
    required String token,
    required Map<String, dynamic> body,
  }) {
    return request(
      method: 'POST',
      path: path,
      body: body,
      token: token,
    );
  }

  /// Wraps POST in try/catch with HomeApiException network mapping.
  Future<Map<String, dynamic>> postEnvelopeSafe({
    required String path,
    required Map<String, dynamic> body,
    String? token,
  }) async {
    try {
      return await postEnvelope(path: path, body: body, token: token);
    } on HomeApiException {
      rethrow;
    } on TimeoutException {
      throw HomeApiException(AppErrorMessages.requestTimeout);
    } on SocketException {
      throw HomeApiException(AppErrorMessages.noInternet);
    } on http.ClientException {
      throw HomeApiException(AppErrorMessages.connectionFailed);
    } catch (_) {
      throw HomeApiException(AppErrorMessages.unexpected);
    }
  }

  void _notifyError(String method, Uri uri, Object error) {
    for (final interceptor in _interceptors) {
      interceptor.onError(method: method, uri: uri, error: error);
    }
  }

  Future<http.Response> _send({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) {
    final timeout = _timeoutForMethod(method);
    switch (method.toUpperCase()) {
      case 'GET':
        return _client.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        return _client
            .post(uri, headers: headers, body: body)
            .timeout(timeout);
      case 'DELETE':
        return _client.delete(uri, headers: headers).timeout(timeout);
      case 'PUT':
        return _client
            .put(uri, headers: headers, body: body)
            .timeout(timeout);
      case 'PATCH':
        return _client
            .patch(uri, headers: headers, body: body)
            .timeout(timeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  Duration _timeoutForMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return _readTimeout;
      default:
        return _writeTimeout;
    }
  }

  Never _mapNetworkError(Object? lastError) {
    if (lastError is TimeoutException) {
      throw HomeApiException(AppErrorMessages.requestTimeout);
    }
    if (lastError is SocketException) {
      throw HomeApiException(AppErrorMessages.noInternet);
    }
    if (lastError is http.ClientException) {
      throw HomeApiException(AppErrorMessages.connectionFailed);
    }
    throw HomeApiException(AppErrorMessages.unexpected);
  }

  String _getCacheKey({
    required String method,
    required String path,
    String? token,
    Map<String, String>? queryParameters,
  }) {
    final query = (queryParameters ?? const <String, String>{})
        .entries
        .map((entry) => '${entry.key}=${entry.value}')
        .toList()
      ..sort();
    final tokenKey = token == null || token.isEmpty ? 'guest' : 'auth';
    return '$method|$path|$tokenKey|${query.join('&')}';
  }

  Duration _cacheTtlForPath(String path) {
    if (path.contains('/offers')) return const Duration(minutes: 3);
    if (path.contains('/our-services')) return const Duration(hours: 6);
    if (path.contains('/vendors')) return const Duration(minutes: 8);
    if (path.contains('/peak-hour-status')) return const Duration(minutes: 5);
    if (path.contains('/favorites')) return const Duration(minutes: 2);
    if (path.contains('/auth/me') || path.contains('/user/me')) {
      return const Duration(minutes: 10);
    }
    if (path.contains('/addresses/')) return const Duration(minutes: 3);
    if (path.contains('/coupons')) return const Duration(minutes: 2);
    return Duration.zero;
  }

  void invalidateGetCache({String? pathPrefix}) {
    if (pathPrefix == null || pathPrefix.isEmpty) {
      _getCache.clear();
      return;
    }
    _getCache.invalidatePrefix('GET|$pathPrefix');
  }
}
