import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/error_sanitizer.dart';

class AuthResult {
  final String message;
  final String? token;
  final String? resetToken;
  final bool needsVerification;
  final String? phone;

  const AuthResult({
    required this.message,
    this.token,
    this.resetToken,
    this.needsVerification = false,
    this.phone,
  });
}

Map<String, dynamic> _safeJsonDecode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

String _extractMessage(Map<String, dynamic> data) {
  final message = data['message'] ?? data['error'];
  if (message != null) return message.toString();

  // Laravel validation errors often return: { message: "...", errors: { field: [..] } }
  final errors = data['errors'];
  if (errors is Map) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value != null) return value.toString();
    }
  }

  return 'فشل الطلب';
}

class AuthRepository {
  final http.Client _client;
  final String _baseUrl;

  AuthRepository({
    http.Client? client,
    String baseUrl = ApiConfig.baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl;

  void _logAuthError(Uri uri, Object error) {
    if (!kDebugMode) return;
    print('[AUTH][ERR] POST $uri -> $error');
  }

  Future<http.Response> _postJsonWithRetry({
    required Uri uri,
    required Map<String, dynamic> body,
    int retries = 1,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        return await _client
            .post(
              uri,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(body),
            )
            .timeout(ApiConfig.timeout);
      } on TimeoutException catch (e) {
        // Keep detailed reason in debug logs to diagnose device-specific issues.
        _logAuthError(uri, e);
        lastError = e;
      } on SocketException catch (e) {
        _logAuthError(uri, e);
        lastError = e;
      } on http.ClientException catch (e) {
        _logAuthError(uri, e);
        lastError = e;
      }

      if (attempt < retries) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    if (lastError is TimeoutException) {
      throw AuthApiException(AppErrorMessages.requestTimeout);
    }
    if (lastError is SocketException || lastError is http.ClientException) {
      throw AuthApiException(AppErrorMessages.connectionFailed);
    }
    throw AuthApiException(AppErrorMessages.unexpected);
  }

  Future<http.Response> _getWithAuth({
    required Uri uri,
    required String token,
  }) async {
    return _client
        .get(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(ApiConfig.timeout);
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/login');

    final res = await _postJsonWithRetry(
      uri: uri,
      body: {
        'phone': phone,
        'password': password,
      },
    );

    final data = _safeJsonDecode(res.body);
    final message = _extractMessage(data);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final token = data['token']?.toString();
      return AuthResult(message: message, token: token);
    }

    if (res.statusCode == 403 &&
        (data['needs_verification'] == true ||
            data['requires_verification'] == true)) {
      return AuthResult(
        message: message,
        needsVerification: true,
        phone: data['phone']?.toString(),
      );
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> register({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? referralCode,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/register');

    final res = await _postJsonWithRetry(
      uri: uri,
      body: {
        'name': name,
        'phone': phone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referral_code': referralCode.trim(),
        'password': password,
        // Laravel "confirmed" expects password_confirmation
        'password_confirmation': password,
      },
    );

    final data = _safeJsonDecode(res.body);
    final message = _extractMessage(data);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthResult(
        message: message,
        needsVerification: true,
        phone: data['phone']?.toString() ?? phone,
      );
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> resendOtp({required String phone}) async {
    final uri = Uri.parse('$_baseUrl/auth/resend-otp');

    final res = await _postJsonWithRetry(
      uri: uri,
      body: {'phone': phone},
    );

    final data = _safeJsonDecode(res.body);
    final message = _extractMessage(data);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthResult(
        message: message,
        needsVerification: true,
        phone: phone,
      );
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> verifyOtp({
    required String phone,
    required String code,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/verify-otp');

    final res = await _postJsonWithRetry(
      uri: uri,
      body: {'phone': phone, 'code': code},
    );

    final data = _safeJsonDecode(res.body);
    final message = _extractMessage(data);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthResult(message: message, token: data['token']?.toString());
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> resetPassword({
    required String phone,
    required String resetToken,
    required String password,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/reset-password');

    final res = await _postJsonWithRetry(
      uri: uri,
      body: {
        'phone': phone,
        'reset_token': resetToken,
        'password': password,
        // Laravel "confirmed" expects password_confirmation
        'password_confirmation': password,
      },
    );

    final data = _safeJsonDecode(res.body);
    final message = _extractMessage(data);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthResult(message: message);
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> forgotPassword({required String phone}) async {
    final uri = Uri.parse('$_baseUrl/auth/forgot-password');

    final res = await _postJsonWithRetry(
      uri: uri,
      body: {'phone': phone},
    );

    final data = _safeJsonDecode(res.body);
    final message = _extractMessage(data);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthResult(message: message, phone: phone);
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> verifyPasswordReset({
    required String phone,
    required String otpToken,
  }) async {
    final uri = Uri.parse('$_baseUrl/auth/verify-password-reset');

    final res = await _postJsonWithRetry(
      uri: uri,
      body: {
        'phone': phone,
        'token': otpToken,
      },
    );

    final data = _safeJsonDecode(res.body);
    final message = _extractMessage(data);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthResult(
        message: message,
        phone: data['phone']?.toString() ?? phone,
        resetToken: data['reset_token']?.toString(),
      );
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>?> getCurrentUser({
    required String token,
  }) async {
    final candidates = <String>[
      '/auth/me',
      '/user/profile',
      '/profile',
      '/user/me',
    ];
    for (final endpoint in candidates) {
      try {
        final uri = Uri.parse('$_baseUrl$endpoint');
        final res = await _getWithAuth(uri: uri, token: token);
        final data = _safeJsonDecode(res.body);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (data['data'] is Map<String, dynamic>) {
            return Map<String, dynamic>.from(data['data'] as Map<String, dynamic>);
          }
          if (data['user'] is Map<String, dynamic>) {
            return Map<String, dynamic>.from(data['user'] as Map<String, dynamic>);
          }
          if (data.isNotEmpty) return data;
        }
      } catch (_) {}
    }
    return null;
  }
}

class AuthApiException implements Exception {
  final String message;
  final int? statusCode;

  AuthApiException(this.message, {this.statusCode});

  @override
  String toString() => 'AuthApiException($statusCode): $message';
}

