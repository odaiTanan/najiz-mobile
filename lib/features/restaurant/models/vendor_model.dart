class VendorModel {
  final int id;
  final int? serviceId;
  final int? classificationId;
  final String name;
  final String? image;
  final String? logo;
  final String? description;
  final bool isOpened;
  final bool isActive;
  final double? rating;
  final String? openingTime;
  final String? closingTime;
  final String? estimatedDeliveryMinutesText;
  final double? latitude;
  final double? longitude;
  /// From `/classifications/.../vendors`: `available` | `busy` | `not_accepting`
  final String? vendorStatus;

  const VendorModel({
    required this.id,
    required this.name,
    this.serviceId,
    this.classificationId,
    this.image,
    this.logo,
    this.description,
    this.isOpened = false,
    this.isActive = false,
    this.rating,
    this.openingTime,
    this.closingTime,
    this.estimatedDeliveryMinutesText,
    this.latitude,
    this.longitude,
    this.vendorStatus,
  });

  factory VendorModel.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['vendor_status'] ?? json['vendorStatus'];
    final statusStr = statusRaw?.toString().trim();
    return VendorModel(
      id: _asInt(json['id']),
      serviceId: _asNullableInt(json['service_id']),
      classificationId: _asNullableInt(json['classification_id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      isOpened: _asBool(json['is_opened']),
      isActive: _asBool(json['is_active']),
      rating: _asNullableDouble(json['rating']),
      openingTime: _asNullableString(json['opening_time'] ?? json['openingTime']),
      closingTime: _asNullableString(json['closing_time'] ?? json['closingTime']),
      estimatedDeliveryMinutesText: _asDeliveryMinutesText(json),
      latitude: _asNullableCoordinate(
        json['lat'] ?? json['latitude'] ?? json['vendor_lat'] ?? json['vendor_latitude'],
      ),
      longitude: _asNullableCoordinate(
        json['lng'] ?? json['longitude'] ?? json['vendor_lng'] ?? json['vendor_longitude'],
      ),
      vendorStatus:
          (statusStr != null && statusStr.isNotEmpty) ? statusStr : null,
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

String? _asNullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String? _asDeliveryMinutesText(Map<String, dynamic> json) {
  final raw = json['estimated_delivery_minutes'] ??
      json['estimatedDeliveryMinutes'] ??
      json['delivery_eta_minutes'] ??
      json['eta_minutes'] ??
      json['etaMinutes'];
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return null;
  if (value.contains(':')) return null;
  final compact = value.replaceAll(RegExp(r'\s+'), '');
  if (RegExp(r'^\d+-\d+$').hasMatch(compact)) return compact;
  if (RegExp(r'^\d+$').hasMatch(compact)) return compact;
  final match = RegExp(r'\d+').firstMatch(value);
  return match?.group(0);
}

double? _asNullableCoordinate(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final parsed = double.tryParse(value.toString());
  return parsed;
}
