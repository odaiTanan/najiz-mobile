class UnavailabilityOption {
  final String value;
  final String label;
  final String description;

  const UnavailabilityOption({
    required this.value,
    required this.label,
    required this.description,
  });

  factory UnavailabilityOption.fromJson(Map<String, dynamic> json) {
    return UnavailabilityOption(
      value: (json['value'] ?? '').toString().trim(),
      label: (json['label'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
    );
  }
}
