class CreateAddressPayload {
  final String title;
  final String? region;
  final String? street;
  final String? addressDetails;
  final String details;
  final double lat;
  final double lng;
  final bool isDefault;

  const CreateAddressPayload({
    required this.title,
    required this.details,
    required this.lat,
    required this.lng,
    this.region,
    this.street,
    this.addressDetails,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (region != null && region!.trim().isNotEmpty) 'region': region!.trim(),
      if (street != null && street!.trim().isNotEmpty) 'street': street!.trim(),
      if (addressDetails != null && addressDetails!.trim().isNotEmpty)
        'address_details': addressDetails!.trim(),
      'details': details,
      'lat': lat,
      'lng': lng,
      'is_default': isDefault,
    };
  }

  String toDisplayText() {
    final parts = <String>[
      title.trim(),
      if (region != null && region!.trim().isNotEmpty) region!.trim(),
      if (street != null && street!.trim().isNotEmpty) street!.trim(),
      details.trim(),
    ];
    return parts.join(' - ');
  }
}
