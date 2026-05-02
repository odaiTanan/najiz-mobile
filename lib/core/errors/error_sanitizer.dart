import 'package:najiz_go_express/core/constants/app_error_messages.dart';

/// Converts raw API / system text into safe, short Arabic for end users.
class ErrorSanitizer {
  ErrorSanitizer._();

  static final RegExp _arabic = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');

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
    if (code == 401) return AppErrorMessages.unauthorized;
    if (code == 403) return AppErrorMessages.forbidden;
    if (code == 404) return AppErrorMessages.notFound;
    if (code == 408 || code == 504) return AppErrorMessages.requestTimeout;
    if (code == 422) return AppErrorMessages.badRequest;
    if (code >= 500) return AppErrorMessages.serverUnavailable;
    if (code >= 400) return AppErrorMessages.badRequest;
    return AppErrorMessages.unexpected;
  }

  /// Message from JSON body + HTTP status → user-safe Arabic.
  static String serverToUser(String? raw, int? statusCode) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return _byStatus(statusCode);
    if (_looksTechnical(t) && !_arabic.hasMatch(t)) {
      return _byStatus(statusCode);
    }
    if (_looksTechnical(t)) return _byStatus(statusCode);
    return t;
  }

  /// Any thrown value → short Arabic (for catch-all UI). Avoid app-specific types here.
  static String anyToUser(Object error) {
    if (error is FormatException || error is TypeError) {
      return AppErrorMessages.unexpected;
    }
    final s = error.toString();
    if (_looksTechnical(s)) return AppErrorMessages.unexpected;
    return AppErrorMessages.unexpected;
  }
}
