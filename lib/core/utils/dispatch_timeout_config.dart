/// Reads driver-dispatch timeout from backend order payloads.
class DispatchTimeoutConfig {
  DispatchTimeoutConfig._();

  static const Duration defaultTimeout = Duration(seconds: 80);

  static const List<String> _timeoutKeys = [
    'driver_dispatch_timeout',
    'driver_dispatch_timeout_seconds',
    'dispatch_timeout_seconds',
    'driver_search_timeout_seconds',
    'driver_search_timeout',
    'dispatch_timeout',
    'driver_timeout_seconds',
    'driver_timeout',
    'assign_driver_timeout',
    'assign_driver_timeout_seconds',
  ];

  static const List<String> _startedAtKeys = [
    'dispatch_started_at',
    'driver_search_started_at',
    'driver_dispatch_started_at',
    'assign_driver_started_at',
  ];

  static Duration resolveFromPayload(
    Map<String, dynamic>? payload, {
    Duration fallback = defaultTimeout,
  }) {
    if (payload == null || payload.isEmpty) return fallback;

    for (final key in _timeoutKeys) {
      final seconds = _asPositiveInt(payload[key]);
      if (seconds != null) return Duration(seconds: seconds);
    }

    final settings = _asMap(payload['settings'] ?? payload['dispatch_settings']);
    if (settings != null) {
      for (final key in _timeoutKeys) {
        final seconds = _asPositiveInt(settings[key]);
        if (seconds != null) return Duration(seconds: seconds);
      }
    }

    final meta = _asMap(payload['meta'] ?? payload['order_meta']);
    if (meta != null) {
      for (final key in _timeoutKeys) {
        final seconds = _asPositiveInt(meta[key]);
        if (seconds != null) return Duration(seconds: seconds);
      }
    }

    return fallback;
  }

  static DateTime? resolveDispatchStartedAt(Map<String, dynamic>? payload) {
    if (payload == null || payload.isEmpty) return null;

    for (final key in _startedAtKeys) {
      final parsed = DateTime.tryParse(payload[key]?.toString() ?? '');
      if (parsed != null) return parsed.toLocal();
    }

    for (final nested in [
      _asMap(payload['settings']),
      _asMap(payload['meta']),
      _asMap(payload['order_meta']),
    ]) {
      if (nested == null) continue;
      for (final key in _startedAtKeys) {
        final parsed = DateTime.tryParse(nested[key]?.toString() ?? '');
        if (parsed != null) return parsed.toLocal();
      }
    }

    return null;
  }

  static Duration remainingTimeout({
    required Duration timeout,
    required DateTime startedAt,
    DateTime? now,
  }) {
    final elapsed = (now ?? DateTime.now()).difference(startedAt);
    final remaining = timeout - elapsed;
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }

  static int? _asPositiveInt(dynamic value) {
    if (value is int) return value > 0 ? value : null;
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }
}
