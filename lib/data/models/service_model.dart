class ServiceModel {
  final int id;
  final String name;
  final String? icon;

  const ServiceModel({
    required this.id,
    required this.name,
    this.icon,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
