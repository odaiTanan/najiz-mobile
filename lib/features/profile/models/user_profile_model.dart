import 'package:najiz_go_express/features/profile/models/user_loyalty_model.dart';

class UserProfileModel {
  const UserProfileModel({
    this.name,
    this.email,
    this.phone,
    this.address,
    this.avatarPath,
    this.roles = const [],
    this.loyalty,
  });

  final String? name;
  final String? email;
  final String? phone;
  final String? address;
  final String? avatarPath;
  final List<String> roles;
  final UserLoyaltyModel? loyalty;

  String? get userTypeLabel {
    if (roles.isEmpty) return null;
    return roles.map(_roleDisplayLabel).join(' • ');
  }

  String? get loyaltyTierLabel => loyalty?.tierLabel;

  int? get loyaltyPoints => loyalty?.points;

  UserProfileModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? avatarPath,
    List<String>? roles,
    UserLoyaltyModel? loyalty,
  }) {
    return UserProfileModel(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      avatarPath: avatarPath ?? this.avatarPath,
      roles: roles ?? this.roles,
      loyalty: loyalty ?? this.loyalty,
    );
  }

  factory UserProfileModel.fromBackend(
    Map<String, dynamic>? json, {
    Map<String, String?>? fallback,
  }) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = json?[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return null;
    }

    return UserProfileModel(
      name: pick(['name', 'full_name', 'username']) ?? fallback?['name'],
      email: pick(['email']) ?? fallback?['email'],
      phone: pick(['phone', 'mobile']) ?? fallback?['phone'],
      address: pick(['address', 'full_address']) ?? fallback?['address'],
      avatarPath:
          pick(['avatar', 'avatar_url', 'profile_image']) ?? fallback?['avatarPath'],
    );
  }

  factory UserProfileModel.fromMeResponse(
    Map<String, dynamic> json, {
    Map<String, String?>? fallback,
  }) {
    final root = _unwrapRoot(json);
    final user = _unwrapUser(root);
    final loyaltyRaw = root['loyalty'] ?? user?['loyalty'];
    final loyalty = loyaltyRaw is Map
        ? UserLoyaltyModel.fromJson(
            loyaltyRaw.map((k, v) => MapEntry(k.toString(), v)),
          )
        : _loyaltyFromUser(user);

    return UserProfileModel.fromBackend(
      user,
      fallback: fallback,
    ).copyWith(
      roles: _parseRoles(root['roles'] ?? user?['roles']),
      loyalty: loyalty,
    );
  }

  static Map<String, dynamic> _unwrapRoot(Map<String, dynamic> json) {
    if (json['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(json['data'] as Map<String, dynamic>);
    }
    if (json['data'] is Map) {
      return json['data'].map((k, v) => MapEntry(k.toString(), v));
    }
    return json;
  }

  static Map<String, dynamic>? _unwrapUser(Map<String, dynamic> root) {
    if (root['user'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(root['user'] as Map<String, dynamic>);
    }
    if (root['user'] is Map) {
      return root['user'].map((k, v) => MapEntry(k.toString(), v));
    }
    return root;
  }

  static UserLoyaltyModel? _loyaltyFromUser(Map<String, dynamic>? user) {
    if (user == null) return null;
    final points = user['loyalty_points'] ?? user['points'];
    final tier = user['loyalty_tier'] ?? user['tier'];
    final tierLabel = user['loyalty_tier_label'] ?? user['tier_label'];
    if (points == null && tier == null && tierLabel == null) return null;
    return UserLoyaltyModel(
      points: _asInt(points),
      tier: tier?.toString(),
      tierLabel: tierLabel?.toString() ?? _defaultTierLabel(tier?.toString()),
    );
  }

  static String? _defaultTierLabel(String? tier) {
    switch ((tier ?? '').trim().toLowerCase()) {
      case 'gold':
      case 'golden':
        return 'عضو ذهبي';
      case 'silver':
        return 'عضو فضي';
      case 'regular':
      case 'normal':
        return 'عضو عادي';
      default:
        return null;
    }
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _parseRoles(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((item) {
          if (item is Map) {
            return (item['name'] ?? item['role'] ?? '').toString().trim();
          }
          return item.toString().trim();
        })
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static String _roleDisplayLabel(String role) {
    switch (role.trim().toLowerCase()) {
      case 'customer':
      case 'user':
      case 'client':
        return 'عميل';
      case 'vendor':
      case 'merchant':
        return 'تاجر';
      case 'driver':
        return 'سائق';
      case 'admin':
        return 'مدير';
      default:
        return role;
    }
  }
}
