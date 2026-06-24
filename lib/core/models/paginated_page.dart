import 'package:najiz_go_express/data/api/api_response.dart';

class PaginatedPage<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginatedPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory PaginatedPage.fromEnvelopeData(
    dynamic envelopeData,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (envelopeData is Map) {
      final map = Map<String, dynamic>.from(envelopeData);
      final itemsRaw = map['data'];
      if (itemsRaw is List) {
        return PaginatedPage(
          items: itemsRaw
              .whereType<Map>()
              .map((e) => fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false),
          currentPage: ApiResponse.asInt(map['current_page']) ?? 1,
          lastPage: ApiResponse.asInt(map['last_page']) ?? 1,
          perPage: ApiResponse.asInt(map['per_page']) ?? 20,
          total: ApiResponse.asInt(map['total']) ?? 0,
        );
      }
    }

    if (envelopeData is List) {
      final items = envelopeData
          .whereType<Map>()
          .map((e) => fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
      return PaginatedPage(
        items: items,
        currentPage: 1,
        lastPage: 1,
        perPage: items.isEmpty ? 20 : items.length,
        total: items.length,
      );
    }

    return const PaginatedPage(
      items: [],
      currentPage: 1,
      lastPage: 1,
      perPage: 20,
      total: 0,
    );
  }
}
