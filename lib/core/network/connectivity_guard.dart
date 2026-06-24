import 'dart:async';

import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/errors/home_api_exception.dart';

/// Lightweight connectivity gate.
///
/// GET requests use optimistic mode (no pre-flight ping) after the first
/// successful API call in the session. Failed socket/timeouts flip to
/// pessimistic mode until connectivity is confirmed again.
class ConnectivityGuard {
  ConnectivityGuard._();

  static final InternetConnectionChecker _checker =
      InternetConnectionChecker.createInstance(
    checkTimeout: const Duration(seconds: 2),
    checkInterval: const Duration(seconds: 2),
  );

  static const Duration _probeCacheTtl = Duration(seconds: 30);

  static bool _optimisticOnline = true;
  static DateTime? _lastCheckedAt;
  static bool? _lastProbeResult;
  static Future<bool>? _probeInFlight;

  static Future<bool> get hasConnection async {
    final inFlight = _probeInFlight;
    if (inFlight != null) return inFlight;

    final now = DateTime.now();
    final checkedAt = _lastCheckedAt;
    final cached = _lastProbeResult;
    if (checkedAt != null &&
        cached != null &&
        now.difference(checkedAt) < _probeCacheTtl) {
      return cached;
    }

    final future = _checker.hasConnection.timeout(
      const Duration(seconds: 3),
      onTimeout: () => _optimisticOnline,
    ).then((result) {
      _lastProbeResult = result;
      _lastCheckedAt = DateTime.now();
      _optimisticOnline = result;
      _probeInFlight = null;
      return result;
    });
    _probeInFlight = future;
    return future;
  }

  /// [optimistic] skips the external ping (used for GET after a healthy session).
  static Future<void> requireOnline({bool optimistic = false}) async {
    if (optimistic && _optimisticOnline) return;

    final checkedAt = _lastCheckedAt;
    if (_optimisticOnline &&
        _lastProbeResult == true &&
        checkedAt != null &&
        DateTime.now().difference(checkedAt) < _probeCacheTtl) {
      return;
    }

    final ok = await hasConnection;
    if (!ok) {
      throw HomeApiException(AppErrorMessages.noInternet);
    }
    _optimisticOnline = true;
  }

  static void markRequestSucceeded() {
    _optimisticOnline = true;
    _lastProbeResult = true;
    _lastCheckedAt = DateTime.now();
  }

  static void markRequestFailed() {
    _optimisticOnline = false;
    invalidate();
  }

  static void invalidate() {
    _lastCheckedAt = null;
    _lastProbeResult = null;
    _probeInFlight = null;
  }
}
