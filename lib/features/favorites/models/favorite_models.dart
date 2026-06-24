class FavoriteListItem {
  final int favoriteId;
  final String type;
  final Map<String, dynamic> entity;

  const FavoriteListItem({
    required this.favoriteId,
    required this.type,
    required this.entity,
  });

  int get entityId {
    final raw = entity['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  factory FavoriteListItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> entity = {};
    final entityRaw = json['entity'];
    if (entityRaw is Map) {
      entity = Map<String, dynamic>.from(entityRaw);
    }
    return FavoriteListItem(
      favoriteId: _asInt(json['favorite_id']),
      type: (json['type'] ?? '').toString(),
      entity: entity,
    );
  }
}

class FavoritesPageResult {
  final List<FavoriteListItem> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const FavoritesPageResult({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory FavoritesPageResult.fromJson(Map<String, dynamic> json) {
    final list = _asList(json['data'])
        .map((e) => FavoriteListItem.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    Map<String, dynamic> map = {};
    final p = json['pagination'];
    if (p is Map) {
      map = Map<String, dynamic>.from(p);
    }
    return FavoritesPageResult(
      items: list,
      currentPage: _asInt(map['current_page'], fallback: 1),
      lastPage: _asInt(map['last_page'], fallback: 1),
      perPage: _asInt(map['per_page'], fallback: 20),
      total: _asInt(map['total']),
    );
  }
}

class FavoriteToggleResult {
  final bool isFavorite;
  final String action;

  const FavoriteToggleResult({
    required this.isFavorite,
    required this.action,
  });

  factory FavoriteToggleResult.fromJson(Map<String, dynamic> json) {
    return FavoriteToggleResult(
      isFavorite: json['is_favorite'] == true,
      action: (json['action'] ?? '').toString(),
    );
  }
}

List<Map<String, dynamic>> _asList(dynamic data) {
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
