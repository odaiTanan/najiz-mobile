class ClassificationModel {
  final int id;
  final String name;
  final String? image;
  final int? serviceId;
  final bool isActive;

  const ClassificationModel({
    required this.id,
    required this.name,
    this.image,
    this.serviceId,
    this.isActive = false,
  });

  factory ClassificationModel.fromJson(Map<String, dynamic> json) {
    return ClassificationModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      serviceId: _asNullableInt(json['service_id']),
      isActive: _asBool(json['is_active']),
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

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  final normalized = value?.toString().toLowerCase();
  return normalized == '1' || normalized == 'true';
}

