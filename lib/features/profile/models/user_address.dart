class UserAddress {
  final int id;
  final String title;
  final String? region;
  final String? street;
  final String? addressDetails;
  final String details;
  final double? lat;
  final double? lng;
  final bool isDefault;
  final String? createdAt;
  final String? updatedAt;

  const UserAddress({
    required this.id,
    required this.title,
    required this.details,
    this.region,
    this.street,
    this.addressDetails,
    this.lat,
    this.lng,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: _asInt(json['id']),
      title: (json['title'] ?? '').toString().trim(),
      region: _asNullableText(json['region']),
      street: _asNullableText(json['street']),
      addressDetails: _asNullableText(json['address_details']),
      details: (json['details'] ?? '').toString().trim(),
      lat: _asNullableDouble(json['lat']),
      lng: _asNullableDouble(json['lng']),
      isDefault: _asBool(json['is_default']),
      createdAt: _asNullableText(json['created_at']),
      updatedAt: _asNullableText(json['updated_at']),
    );
  }

  String toDisplayText() {
    final parts = <String>[
      if (title.trim().isNotEmpty) title.trim(),
      if ((region ?? '').trim().isNotEmpty) region!.trim(),
      if ((street ?? '').trim().isNotEmpty) street!.trim(),
      if (details.trim().isNotEmpty) details.trim(),
    ];
    return parts.isEmpty ? 'عنوان محفوظ' : parts.join(' - ');
  }

  String toShortLabel() {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isNotEmpty) {
      // Older stored values may accidentally contain full-address blobs.
      final normalized = cleanedTitle
          .replaceFirst(RegExp(r'^العنوان\s*:\s*'), '')
          .split('|')
          .first
          .trim();
      if (normalized.isNotEmpty && normalized.length <= 28) return normalized;
    }
    final cleanedRegion = (region ?? '').trim();
    if (cleanedRegion.isNotEmpty) return cleanedRegion;
    return 'عنوان محفوظ';
  }

  /// Subtitle line for delivery address picker (region/street/details).
  String toPickerSubtitle() {
    final detail = details.trim();
    if (detail.isNotEmpty) return detail;

    final parts = <String>[
      if ((region ?? '').trim().isNotEmpty) region!.trim(),
      if ((street ?? '').trim().isNotEmpty) street!.trim(),
      if ((addressDetails ?? '').trim().isNotEmpty) addressDetails!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(' - ');

    return toDisplayText();
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _asNullableText(dynamic value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return text;
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
