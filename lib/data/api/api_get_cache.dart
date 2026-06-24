import 'package:http/http.dart' as http;

class _CacheEntry {
  _CacheEntry(this.response, this.expiresAt);

  final http.Response response;
  final DateTime expiresAt;

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// In-memory GET deduplication + short-lived response cache.
class ApiGetCache {
  final Map<String, _CacheEntry> _entries = {};
  final Map<String, Future<http.Response>> _inFlight = {};

  Future<http.Response> run({
    required String key,
    required Future<http.Response> Function() fetch,
    Duration ttl = Duration.zero,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final inFlight = _inFlight[key];
      if (inFlight != null) return inFlight;

      if (ttl > Duration.zero) {
        final cached = _entries[key];
        if (cached != null && cached.isValid) {
          return cached.response;
        }
      }
    } else {
      _entries.remove(key);
    }

    final future = fetch().then((response) {
      if (ttl > Duration.zero &&
          response.statusCode >= 200 &&
          response.statusCode < 300) {
        _entries[key] = _CacheEntry(response, DateTime.now().add(ttl));
      }
      _inFlight.remove(key);
      return response;
    }).catchError((Object error) {
      _inFlight.remove(key);
      throw error;
    });

    _inFlight[key] = future;
    return future;
  }

  void invalidatePrefix(String prefix) {
    _entries.removeWhere((key, _) => key.startsWith(prefix));
    _inFlight.removeWhere((key, _) => key.startsWith(prefix));
  }

  void clear() {
    _entries.clear();
    _inFlight.clear();
  }
}
