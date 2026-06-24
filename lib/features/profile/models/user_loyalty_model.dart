class UserLoyaltyModel {
  const UserLoyaltyModel({
    required this.points,
    this.tier,
    this.tierLabel,
  });

  final int points;
  final String? tier;
  final String? tierLabel;

  factory UserLoyaltyModel.fromJson(Map<String, dynamic> json) {
    return UserLoyaltyModel(
      points: _asInt(json['points']),
      tier: _nullableString(json['tier']),
      tierLabel: _nullableString(json['tier_label'] ?? json['tierLabel']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
