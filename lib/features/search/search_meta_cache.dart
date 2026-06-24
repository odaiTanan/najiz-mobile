/// Shared TTL flag for search meta (trending, vendors, history prefetch).
class SearchMetaCache {
  SearchMetaCache._();

  static DateTime? loadedAt;
  static const ttl = Duration(minutes: 5);

  static bool get isFresh {
    final at = loadedAt;
    if (at == null) return false;
    return DateTime.now().difference(at) < ttl;
  }

  static void markLoaded() => loadedAt = DateTime.now();

  static void invalidate() => loadedAt = null;
}
