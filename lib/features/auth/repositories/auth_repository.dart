import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/error_sanitizer.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/auth/errors/auth_api_exception.dart';
import 'package:najiz_go_express/features/auth/models/auth_result.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<void> deleteAccount({
    required String token,
    required String password,
  }) async {
    http.Response res;
    try {
      res = await _api.postWithAuth(
        path: Endpoints.authDeleteAccount,
        token: token,
        body: {'password': password},
      );
    } on HomeApiException catch (e) {
      throw AuthApiException(e.message, statusCode: e.statusCode);
    } on TimeoutException {
      throw AuthApiException(AppErrorMessages.requestTimeout);
    } on SocketException {
      throw AuthApiException(AppErrorMessages.connectionFailed);
    } on http.ClientException {
      throw AuthApiException(AppErrorMessages.connectionFailed);
    }

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final res = await _postJsonWithRetry(
      path: Endpoints.authLogin,
      body: {
        'phone': phone,
        'password': password,
      },
    );

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

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
    final res = await _postJsonWithRetry(
      path: Endpoints.authRegister,
      body: {
        'name': name,
        'phone': phone,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (referralCode != null && referralCode.trim().isNotEmpty)
          'referral_code': referralCode.trim(),
        'password': password,
        'password_confirmation': password,
      },
    );

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

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
    final res = await _postJsonWithRetry(
      path: Endpoints.authResendOtp,
      body: {'phone': phone},
    );

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

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
    final res = await _postJsonWithRetry(
      path: Endpoints.authVerifyOtp,
      body: {'phone': phone, 'code': code},
    );

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

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
    final res = await _postJsonWithRetry(
      path: Endpoints.authResetPassword,
      body: {
        'phone': phone,
        'reset_token': resetToken,
        'password': password,
        'password_confirmation': password,
      },
    );

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return AuthResult(message: message);
    }

    throw AuthApiException(
      ErrorSanitizer.serverToUser(message, res.statusCode),
      statusCode: res.statusCode,
    );
  }

  Future<AuthResult> forgotPassword({required String phone}) async {
    final res = await _postJsonWithRetry(
      path: Endpoints.authForgotPassword,
      body: {'phone': phone},
    );

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

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
    final res = await _postJsonWithRetry(
      path: Endpoints.authVerifyPasswordReset,
      body: {
        'phone': phone,
        'token': otpToken,
      },
    );

    final data = ApiResponse.safeDecodeMap(res.body);
    final message = ApiResponse.extractMessage(data, includeValidationErrors: true);

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
    const endpoints = <String>[
      '/auth/me',
      '/user/profile',
      '/user/me',
    ];
    for (final endpoint in endpoints) {
      try {
        final res = await _api.getWithAuth(path: endpoint, token: token);
        final data = ApiResponse.safeDecodeMap(res.body);
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final inner = (data['data'] is Map)
              ? Map<String, dynamic>.from(data['data'] as Map)
              : data;
          if (inner['user'] is Map) {
            return Map<String, dynamic>.from(inner['user'] as Map);
          }
          if (inner.isNotEmpty) return inner;
        }
      } catch (_) {}
    }
    return null;
  }

  Future<http.Response> _postJsonWithRetry({
    required String path,
    required Map<String, dynamic> body,
    int retries = 1,
  }) async {
    try {
      return await _api.postWithRetry(path: path, body: body, retries: retries);
    } on HomeApiException catch (e) {
      throw AuthApiException(e.message);
    }
  }
}
