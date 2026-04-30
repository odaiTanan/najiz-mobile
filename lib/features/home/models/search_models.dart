class SearchResultModel {
  final String query;
  final String type;
  final int totalResults;
  final List<SearchProductModel> products;
  final List<SearchVendorModel> vendors;

  const SearchResultModel({
    required this.query,
    required this.type,
    required this.totalResults,
    required this.products,
    required this.vendors,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    final productsRaw = (data['products'] is List) ? data['products'] as List : const [];
    final vendorsRaw = (data['vendors'] is List) ? data['vendors'] as List : const [];
    return SearchResultModel(
      query: (json['query'] ?? '').toString(),
      type: (json['type'] ?? 'all').toString(),
      totalResults: _asInt(json['total_results']),
      products: productsRaw
          .whereType<Map>()
          .map((e) => SearchProductModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      vendors: vendorsRaw
          .whereType<Map>()
          .map((e) => SearchVendorModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
    );
  }
}

class SearchProductModel {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? image;
  final int? vendorId;
  final String? vendorName;
  final String? vendorType;

  const SearchProductModel({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.image,
    this.vendorId,
    this.vendorName,
    this.vendorType,
  });

  factory SearchProductModel.fromJson(Map<String, dynamic> json) {
    final vendor = (json['vendor'] is Map)
        ? Map<String, dynamic>.from(json['vendor'] as Map)
        : <String, dynamic>{};
    return SearchProductModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      price: _asDouble(json['price']),
      image: json['image']?.toString(),
      vendorId: _asNullableInt(vendor['id']),
      vendorName: vendor['name']?.toString(),
      vendorType: vendor['type']?.toString(),
    );
  }
}

class SearchVendorModel {
  final int id;
  final String name;
  final String? description;
  final String? image;
  final String? address;
  final String type;
  final bool isOpened;
  final bool isActive;
  final double? rating;
  final bool hasFreeDelivery;

  const SearchVendorModel({
    required this.id,
    required this.name,
    this.description,
    this.image,
    this.address,
    required this.type,
    required this.isOpened,
    this.isActive = false,
    this.rating,
    this.hasFreeDelivery = false,
  });

  factory SearchVendorModel.fromJson(Map<String, dynamic> json) {
    return SearchVendorModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      address: json['address']?.toString(),
      type: (json['type'] ?? 'store').toString(),
      isOpened: _asBool(json['is_opened']),
      isActive: _asBool(json['is_active']),
      rating: _asNullableDouble(json['rating']),
      hasFreeDelivery: _asBool(
        json['free_delivery'] ?? json['is_free_delivery'] ?? _isZeroFee(json['delivery_fee']),
      ),
    );
  }
}

class SearchTrendingItem {
  final String query;
  final int searchCount;

  const SearchTrendingItem({required this.query, required this.searchCount});

  factory SearchTrendingItem.fromJson(Map<String, dynamic> json) {
    return SearchTrendingItem(
      query: (json['query'] ?? '').toString(),
      searchCount: _asInt(json['search_count']),
    );
  }
}

class SearchHistoryItem {
  final int id;
  final String query;
  final String type;
  final int resultsCount;
  final String searchedAt;

  const SearchHistoryItem({
    required this.id,
    required this.query,
    required this.type,
    required this.resultsCount,
    required this.searchedAt,
  });

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: _asInt(json['id']),
      query: (json['query'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      resultsCount: _asInt(json['results_count']),
      searchedAt: (json['searched_at'] ?? '').toString(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  final text = value?.toString().toLowerCase();
  return text == '1' || text == 'true';
}

bool _isZeroFee(dynamic value) {
  if (value == null) return false;
  if (value is num) return value == 0;
  return double.tryParse(value.toString()) == 0;
}
