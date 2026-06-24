class OfferModel {
  final int id;
  final int? vendorId;
  final int? serviceId;
  final String? service;
  final String name;
  final String? image;
  final bool isActive;
  final OfferVendorModel? vendor;

  const OfferModel({
    required this.id,
    required this.name,
    this.vendorId,
    this.serviceId,
    this.service,
    this.image,
    this.isActive = false,
    this.vendor,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    final vendorRaw = json['vendor'];
    OfferVendorModel? vendor;
    if (vendorRaw is Map<String, dynamic>) {
      vendor = OfferVendorModel.fromJson(vendorRaw);
    } else if (vendorRaw is Map) {
      vendor = OfferVendorModel.fromJson(
        vendorRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    return OfferModel(
      id: _asInt(json['id']),
      vendorId: _asNullableInt(json['vendor_id']),
      serviceId: _asNullableInt(json['service_id']),
      service: _firstNonEmpty([
        json['service'],
        json['service_type'],
        json['type'],
      ]),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      isActive: _asBool(json['is_active']),
      vendor: vendor,
    );
  }

  static OfferServiceKind resolveServiceKind(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.contains('ship') ||
        normalized.contains('شحن') ||
        normalized == 'shipping') {
      return OfferServiceKind.shipping;
    }
    return OfferServiceKind.taxi;
  }
}

enum OfferServiceKind {
  taxi,
  shipping,
}

class OfferVendorModel {
  final int id;
  final int? serviceId;
  final String name;
  final String? image;
  final String? logo;
  final String? description;
  final double? rating;

  const OfferVendorModel({
    required this.id,
    this.serviceId,
    required this.name,
    this.image,
    this.logo,
    this.description,
    this.rating,
  });

  factory OfferVendorModel.fromJson(Map<String, dynamic> json) {
    return OfferVendorModel(
      id: _asInt(json['id']),
      serviceId: _asNullableInt(json['service_id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      rating: _asNullableDouble(json['rating']),
    );
  }
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final raw in values) {
    final value = raw?.toString().trim();
    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }
  return null;
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
