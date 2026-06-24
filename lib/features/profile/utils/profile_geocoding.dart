import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:najiz_go_express/features/profile/profile_maps_config.dart';

abstract final class ProfileGeocoding {
  static Future<String> reverseGeocode(LatLng point) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${point.latitude},${point.longitude}',
        'language': 'ar',
        'region': 'sy',
        'key': profileMapsApiKey,
      },
    );
    try {
      final res = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final areaLabel = extractAreaLabelFromGoogle(body);
        if (areaLabel != null && areaLabel.isNotEmpty) {
          return areaLabel;
        }
      }
    } catch (_) {}
    final placemarkLabel = await reverseGeocodeByPlacemark(point);
    if (placemarkLabel != null && placemarkLabel.isNotEmpty) {
      return placemarkLabel;
    }
    return 'address.selectedOnMap'.tr;
  }

  static Future<String?> reverseGeocodeGoogleOnly(LatLng point) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${point.latitude},${point.longitude}',
        'language': 'ar',
        'region': 'sy',
        'key': profileMapsApiKey,
      },
    );
    try {
      final res = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        return extractAreaLabelFromGoogle(body);
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> reverseGeocodeByPlacemark(LatLng point) async {
    try {
      final marks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (marks.isEmpty) return null;
      final p = marks.first;
      final parts = <String>[
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
      ];
      if (parts.isNotEmpty) return parts.join('، ');
    } catch (_) {}
    return null;
  }

  static String? extractAreaLabelFromGoogle(Map<String, dynamic> body) {
    final results = body['results'];
    if (results is! List || results.isEmpty) return null;
    for (final raw in results) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final types = (map['types'] is List)
          ? (map['types'] as List).map((e) => e.toString()).toList()
          : const <String>[];
      if (types.contains('plus_code')) continue;

      final componentsRaw = map['address_components'];
      if (componentsRaw is List) {
        String? locality;
        String? sublocality;
        String? route;
        for (final cRaw in componentsRaw) {
          if (cRaw is! Map) continue;
          final c = Map<String, dynamic>.from(cRaw);
          final longName = (c['long_name'] ?? '').toString().trim();
          if (longName.isEmpty) continue;
          final cTypes = (c['types'] is List)
              ? (c['types'] as List).map((e) => e.toString()).toList()
              : const <String>[];
          if (cTypes.contains('locality') && locality == null) {
            locality = longName;
          }
          if ((cTypes.contains('sublocality') ||
                  cTypes.contains('sublocality_level_1')) &&
              sublocality == null) {
            sublocality = longName;
          }
          if (cTypes.contains('route') && route == null) {
            route = longName;
          }
        }
        final parts = <String>[
          if (sublocality != null && sublocality.isNotEmpty) sublocality,
          if (locality != null && locality.isNotEmpty) locality,
          if (route != null && route.isNotEmpty) route,
        ];
        if (parts.isNotEmpty) return parts.join('، ');
      }

      final formatted = (map['formatted_address'] ?? '').toString().trim();
      if (formatted.isNotEmpty && !looksLikeCoordinates(formatted)) {
        return formatted;
      }
    }
    return null;
  }

  static bool looksLikeCoordinates(String input) {
    final text = input.trim();
    return RegExp(r'^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$').hasMatch(text);
  }
}
