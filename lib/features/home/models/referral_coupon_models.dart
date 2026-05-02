class ReferralCodeInfo {
  final String referralCode;
  final int referralsCount;

  const ReferralCodeInfo({
    required this.referralCode,
    this.referralsCount = 0,
  });

  factory ReferralCodeInfo.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
    return ReferralCodeInfo(
      referralCode: (data['referral_code'] ?? '').toString(),
      referralsCount: _asInt(data['referrals_count']),
    );
  }
}

class ReferralItem {
  final int id;
  final String referredName;
  final String referredPhone;
  final String createdAt;

  const ReferralItem({
    required this.id,
    required this.referredName,
    required this.referredPhone,
    required this.createdAt,
  });

  factory ReferralItem.fromJson(Map<String, dynamic> json) {
    final user = (json['referred_user'] is Map)
        ? Map<String, dynamic>.from(json['referred_user'] as Map)
        : <String, dynamic>{};
    return ReferralItem(
      id: _asInt(json['id']),
      referredName: (user['name'] ?? '').toString(),
      referredPhone: (user['phone'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class UserCouponItem {
  final int id;
  final String code;
  final String type;
  final double value;
  final bool isActive;
  final String source;
  final String? vendorName;

  const UserCouponItem({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.isActive,
    required this.source,
    this.vendorName,
  });

  factory UserCouponItem.fromJson(Map<String, dynamic> json) {
    // Backend can return either:
    // 1) flat coupon fields directly
    // 2) nested shape: { ..., coupon: { code, type, value, is_active, vendor... } }
    final nestedCoupon = (json['coupon'] is Map)
        ? Map<String, dynamic>.from(json['coupon'] as Map)
        : <String, dynamic>{};

    final source = nestedCoupon.isNotEmpty ? nestedCoupon : json;

    final vendor = (source['vendor'] is Map)
        ? Map<String, dynamic>.from(source['vendor'] as Map)
        : <String, dynamic>{};

    final isActiveRaw = source['is_active'] ?? json['is_active'];

    return UserCouponItem(
      id: _asInt(json['id']),
      code: (source['code'] ?? '').toString(),
      type: (source['type'] ?? '').toString(),
      value: _asDouble(source['value']),
      isActive: _asBool(isActiveRaw),
      source: (json['source'] ?? '').toString(),
      vendorName: vendor['name']?.toString(),
    );
  }

  String get valueLabel => type == 'percentage'
      ? '${value.toInt()}%'
      : '${value.toInt()} ل.س';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  final text = value?.toString().toLowerCase();
  return text == '1' ||
      text == 'true' ||
      text == 'active' ||
      text == 'enabled';
}
