import 'package:najiz_go_express/core/constants/app_error_messages.dart';

/// Converts raw API / system text into safe, short Arabic for end users.
class ErrorSanitizer {
  ErrorSanitizer._();

  static final RegExp _arabic =
      RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');

  static bool _looksTechnical(String s) {
    final t = s.trim();
    if (t.isEmpty) return true;
    final lower = t.toLowerCase();
    return lower.contains('exception') ||
        lower.contains('stacktrace') ||
        lower.contains('stack trace') ||
        lower.contains('sqlstate') ||
        lower.contains('sql:') ||
        lower.contains('fatal error') ||
        lower.contains('undefined') ||
        lower.contains('null pointer') ||
        lower.contains('socketexception') ||
        lower.contains('timeouterror') ||
        lower.contains('clientexception') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('errno') ||
        lower.contains('trace #') ||
        RegExp(r'#0\s').hasMatch(t) ||
        t.length > 220;
  }

  static String _byStatus(int? code) {
    if (code == null) return AppErrorMessages.serverUnavailable;
    if (code == 401) return AppErrorMessages.unauthenticated;
    if (code == 403) return AppErrorMessages.forbidden;
    if (code == 404) return AppErrorMessages.notFound;
    if (code == 408 || code == 504) return AppErrorMessages.requestTimeout;
    if (code == 409) return AppErrorMessages.conflict;
    if (code == 422) return AppErrorMessages.badRequest;
    if (code == 429) return AppErrorMessages.tooManyRequests;
    if (code >= 500) return AppErrorMessages.serverUnavailable;
    if (code >= 400) return AppErrorMessages.badRequest;
    return AppErrorMessages.unexpected;
  }

  static String? _mapKnownBackendCode(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[.\s]+$'), '')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    switch (normalized) {
      case 'unauthenticated':
        return AppErrorMessages.unauthenticated;
      case 'unauthorized':
        return AppErrorMessages.unauthorized;
      case 'forbidden':
      case 'access_denied':
        return AppErrorMessages.forbidden;
      case 'not_found':
      case 'notfound':
        return AppErrorMessages.notFound;
      case 'too_many_requests':
      case 'throttle':
      case 'throttled':
        return AppErrorMessages.tooManyRequests;
      case 'server_error':
      case 'internal_server_error':
        return AppErrorMessages.serverUnavailable;
      case 'conflict':
        return AppErrorMessages.conflict;
    }

    if (normalized.contains('unauthenticated')) {
      return AppErrorMessages.unauthenticated;
    }
    if (normalized.contains('unauthorized')) {
      return AppErrorMessages.unauthorized;
    }
    if (normalized.contains('too_many_requests') ||
        normalized.contains('too many requests')) {
      return AppErrorMessages.tooManyRequests;
    }
    if (_looksLikeAccountRestriction(normalized)) {
      return AppErrorMessages.accountRestricted;
    }
    return null;
  }

  static bool _looksLikeAccountRestriction(String normalized) {
    final hasAccountSignal = normalized.contains('account') ||
        normalized.contains('user') ||
        normalized.contains('حساب');
    final hasRestrictionSignal = normalized.contains('restrict') ||
        normalized.contains('suspend') ||
        normalized.contains('banned') ||
        normalized.contains('blocked') ||
        normalized.contains('disabled') ||
        normalized.contains('deactivat') ||
        normalized.contains('محظور') ||
        normalized.contains('موقوف') ||
        normalized.contains('معلق');
    return hasAccountSignal && hasRestrictionSignal;
  }

  /// True when the backend response means the auth session must be cleared.
  static bool isSessionInvalidating({
    String? rawMessage,
    int? statusCode,
  }) {
    if (statusCode == 401) return true;
    final message = (rawMessage ?? '').trim();
    if (message.isEmpty) return false;
    final normalized =
        message.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
    if (normalized.contains('unauthenticated')) return true;
    if (_looksLikeAccountRestriction(normalized)) return true;
    return false;
  }

  /// Message from JSON body + HTTP status → user-safe Arabic.
  static String serverToUser(String? raw, int? statusCode) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return _byStatus(statusCode);

    final known = _mapKnownBackendCode(t);
    if (known != null) return known;

    if (_looksTechnical(t) && !_arabic.hasMatch(t)) {
      return _byStatus(statusCode);
    }
    if (_looksTechnical(t)) return _byStatus(statusCode);

    // Plain English technical tokens must never reach UI.
    if (!_arabic.hasMatch(t) && RegExp(r'^[a-zA-Z0-9_.\-\s]+$').hasMatch(t)) {
      final tokenMapped = _mapKnownBackendCode(t);
      if (tokenMapped != null) return tokenMapped;
      if (statusCode != null) return _byStatus(statusCode);
      return AppErrorMessages.unexpected;
    }

    return t;
  }

  /// Any thrown value → short Arabic (for catch-all UI).
  static String anyToUser(Object error) {
    if (error is FormatException || error is TypeError) {
      return AppErrorMessages.unexpected;
    }
    final s = error.toString();
    final known = _mapKnownBackendCode(s);
    if (known != null) return known;
    if (_looksTechnical(s)) return AppErrorMessages.unexpected;
    return AppErrorMessages.unexpected;
  }
}
