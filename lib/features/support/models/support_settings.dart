class SupportSettings {
  const SupportSettings({
    required this.whatsAppEnabled,
    required this.whatsAppNumber,
    required this.phoneEnabled,
    required this.phoneNumber,
  });

  final bool whatsAppEnabled;
  final String whatsAppNumber;
  final bool phoneEnabled;
  final String phoneNumber;

  static const fallback = SupportSettings(
    whatsAppEnabled: true,
    whatsAppNumber: '+963961102030',
    phoneEnabled: true,
    phoneNumber: '+963961102030',
  );

  factory SupportSettings.fromJson(Map<String, dynamic> json) {
    return SupportSettings(
      whatsAppEnabled:
          json['whatsapp_enabled'] == true ||
          json['whatsapp_enabled'] == 1 ||
          json['whatsapp_enabled']?.toString() == '1',
      whatsAppNumber: (json['whatsapp_number'] ?? fallback.whatsAppNumber)
          .toString()
          .trim(),
      phoneEnabled:
          json['phone_enabled'] == true ||
          json['phone_enabled'] == 1 ||
          json['phone_enabled']?.toString() == '1',
      phoneNumber: (json['phone_number'] ?? fallback.phoneNumber)
          .toString()
          .trim(),
    );
  }
}
