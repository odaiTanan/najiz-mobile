class VendorProductsModel {
  final VendorProductsVendor vendor;
  final List<VendorProductsCategory> categories;
  final List<VendorProductItem> products;

  const VendorProductsModel({
    required this.vendor,
    required this.categories,
    required this.products,
  });

  factory VendorProductsModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return VendorProductsModel(
      vendor: VendorProductsVendor.fromJson(
        data['vendor'] is Map<String, dynamic>
            ? data['vendor'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      categories: _asList(data['categories'])
          .map(VendorProductsCategory.fromJson)
          .toList(),
      products: _asList(data['products']).map(VendorProductItem.fromJson).toList(),
    );
  }
}

class VendorProductsVendor {
  final int id;
  final String name;
  final String? image;
  final String? logo;
  final String? description;
  final double? rating;
  final String? classificationName;
  /// `available` | `busy` | `not_accepting` (same as list vendors API).
  final String? vendorStatus;
  final bool isOpened;
  final String? estimatedDeliveryMinutesText;
  final double? latitude;
  final double? longitude;

  const VendorProductsVendor({
    required this.id,
    required this.name,
    this.image,
    this.logo,
    this.description,
    this.rating,
    this.classificationName,
    this.vendorStatus,
    this.isOpened = false,
    this.estimatedDeliveryMinutesText,
    this.latitude,
    this.longitude,
  });

  factory VendorProductsVendor.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['vendor_status'] ?? json['vendorStatus'];
    final statusStr = statusRaw?.toString().trim();
    return VendorProductsVendor(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      rating: _asNullableDouble(json['rating']),
      classificationName: (json['classification'] is Map)
          ? (json['classification']['name']?.toString())
          : null,
      vendorStatus:
          (statusStr != null && statusStr.isNotEmpty) ? statusStr : null,
      isOpened: _asBool(json['is_opened']),
      estimatedDeliveryMinutesText: _asDeliveryMinutesText(
        json['estimated_delivery_minutes'] ??
            json['estimatedDeliveryMinutes'] ??
            json['delivery_eta_minutes'] ??
            json['eta_minutes'] ??
            json['etaMinutes'],
      ),
      latitude: _asNullableCoordinate(
        json['lat'] ??
            json['latitude'] ??
            json['vendor_lat'] ??
            json['vendor_latitude'],
      ),
      longitude: _asNullableCoordinate(
        json['lng'] ??
            json['longitude'] ??
            json['vendor_lng'] ??
            json['vendor_longitude'],
      ),
    );
  }
}

class VendorProductsCategory {
  final int id;
  final String name;
  final String type;

  const VendorProductsCategory({
    required this.id,
    required this.name,
    required this.type,
  });

  factory VendorProductsCategory.fromJson(Map<String, dynamic> json) {
    return VendorProductsCategory(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'regular').toString().toLowerCase(),
    );
  }
}

class VendorProductItem {
  final int id;
  final int? vendorId;
  final int? categoryId;
  final String name;
  final String? description;
  final String? image;
  final double? price;
  final double? originalPrice;
  final int? stock;
  final String? categoryType;
  final List<VendorProductExtra> activeExtras;

  const VendorProductItem({
    required this.id,
    this.vendorId,
    this.categoryId,
    required this.name,
    this.description,
    this.image,
    this.price,
    this.originalPrice,
    this.stock,
    this.categoryType,
    this.activeExtras = const [],
  });

  factory VendorProductItem.fromJson(Map<String, dynamic> json) {
    return VendorProductItem(
      id: _asInt(json['id']),
      vendorId: _asNullableInt(json['vendor_id']),
      categoryId: _asNullableInt(json['category_id']),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      price: _asNullableDouble(json['price']),
      originalPrice: _asNullableDouble(json['original_price']),
      stock: _asNullableInt(json['stock']),
      categoryType: (json['category'] is Map)
          ? (json['category']['type']?.toString().toLowerCase())
          : null,
      activeExtras: _asList(
        json['active_extras'] ?? json['extras'] ?? const <dynamic>[],
      ).map(VendorProductExtra.fromJson).toList(growable: false),
    );
  }
}

class VendorProductExtra {
  final int id;
  final int? productId;
  final String name;
  final double price;
  final int maxQuantity;
  final bool isRequired;
  final int sortOrder;
  final bool isActive;

  const VendorProductExtra({
    required this.id,
    this.productId,
    required this.name,
    required this.price,
    this.maxQuantity = 1,
    this.isRequired = false,
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory VendorProductExtra.fromJson(Map<String, dynamic> json) {
    return VendorProductExtra(
      id: _asInt(json['id']),
      productId: _asNullableInt(json['product_id']),
      name: (json['name'] ?? '').toString(),
      price: _asNullableDouble(json['price']) ?? 0,
      maxQuantity: _asNullableInt(json['max_quantity']) ?? 1,
      isRequired: (json['is_required'] == true || json['is_required'] == 1),
      sortOrder: _asNullableInt(json['sort_order']) ?? 0,
      isActive: (json['is_active'] == null ||
          json['is_active'] == true ||
          json['is_active'] == 1),
    );
  }
}

List<Map<String, dynamic>> _asList(dynamic data) {
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
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

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  final normalized = value?.toString().toLowerCase();
  return normalized == '1' || normalized == 'true';
}

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _asDeliveryMinutesText(dynamic value) {
  final text = _asNullableString(value);
  if (text == null) return null;
  if (text.contains(':')) return null;
  final compact = text.replaceAll(RegExp(r'\s+'), '');
  if (RegExp(r'^\d+-\d+$').hasMatch(compact)) return compact;
  if (RegExp(r'^\d+$').hasMatch(compact)) return compact;
  final match = RegExp(r'\d+').firstMatch(text);
  return match?.group(0);
}

double? _asNullableCoordinate(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
