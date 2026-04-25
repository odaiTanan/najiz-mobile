class OfferModel {
  final int id;
  final int? vendorId;
  final String name;
  final String? image;
  final bool isActive;
  final OfferVendorModel? vendor;

  const OfferModel({
    required this.id,
    required this.name,
    this.vendorId,
    this.image,
    this.isActive = false,
    this.vendor,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      id: _asInt(json['id']),
      vendorId: _asNullableInt(json['vendor_id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      isActive: _asBool(json['is_active']),
      vendor: json['vendor'] is Map<String, dynamic>
          ? OfferVendorModel.fromJson(json['vendor'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OfferVendorModel {
  final int id;
  final String name;
  final String? image;
  final String? logo;
  final String? description;
  final double? rating;

  const OfferVendorModel({
    required this.id,
    required this.name,
    this.image,
    this.logo,
    this.description,
    this.rating,
  });

  factory OfferVendorModel.fromJson(Map<String, dynamic> json) {
    return OfferVendorModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      rating: _asNullableDouble(json['rating']),
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
