import 'package:najiz_go_express/core/constants/api_config.dart';

class MediaUrlResolver {
  MediaUrlResolver._();

  static const List<String> avatarFieldKeys = [
    'avatar_url',
    'avatarUrl',
    'avatar',
    'photo_url',
    'photoUrl',
    'photo',
    'image_url',
    'imageUrl',
    'image',
    'profile_image_url',
    'profileImageUrl',
    'profile_image',
    'profileImage',
    'driver_avatar',
    'driverAvatar',
    'picture_url',
    'pictureUrl',
    'picture',
  ];

  static const List<String> _nestedUrlKeys = [
    'url',
    'original_url',
    'originalUrl',
    'full_url',
    'fullUrl',
    'path',
    'src',
    'href',
  ];

  static String? resolve(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) return 'https:$value';

    final origin = ApiConfig.baseUrl.replaceAll(RegExp(r'/api$'), '');
    if (value.startsWith('/')) return '$origin$value';
    return '$origin/$value';
  }

  /// Reads avatar/profile image URLs from flat maps, nested `{url: ...}` values,
  /// or Spatie-style `media` arrays.
  static String? pickAvatar({
    Map<String, dynamic>? payload,
    Map<String, dynamic>? deliveryMan,
    Map<String, dynamic>? driverUser,
  }) {
    for (final map in [payload, driverUser, deliveryMan]) {
      final fromFields = pickFromMap(map);
      if (fromFields != null) return fromFields;

      final fromMedia = pickFromMediaCollection(map?['media']);
      if (fromMedia != null) return fromMedia;
    }
    return null;
  }

  static String? pickFromMap(
    Map<String, dynamic>? map, {
    List<String> keys = avatarFieldKeys,
  }) {
    if (map == null || map.isEmpty) return null;
    for (final key in keys) {
      final resolved = coerceUrl(map[key]);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static String? pickFromMediaCollection(dynamic media) {
    if (media is! List || media.isEmpty) return null;
    for (final item in media) {
      final resolved = coerceUrl(item);
      if (resolved != null) return resolved;
    }
    return null;
  }

  static String? coerceUrl(dynamic raw) {
    if (raw == null) return null;

    if (raw is String) {
      return resolve(raw);
    }

    if (raw is Map) {
      final map = raw.map((k, v) => MapEntry(k.toString(), v));
      for (final key in _nestedUrlKeys) {
        final nested = coerceUrl(map[key]);
        if (nested != null) return nested;
      }
      for (final key in avatarFieldKeys) {
        if (_nestedUrlKeys.contains(key)) continue;
        final nested = coerceUrl(map[key]);
        if (nested != null) return nested;
      }
    }

    if (raw is List && raw.isNotEmpty) {
      return coerceUrl(raw.first);
    }

    return null;
  }
}
