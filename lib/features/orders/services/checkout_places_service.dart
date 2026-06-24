import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:najiz_go_express/features/profile/profile_maps_config.dart';

const Duration _mapsRequestTimeout = Duration(seconds: 5);

class CheckoutPlaceSuggestion {
  const CheckoutPlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.primaryText,
    required this.secondaryText,
    this.distanceMeters,
    this.types = const [],
  });

  final String placeId;
  final String description;
  final String primaryText;
  final String secondaryText;
  final int? distanceMeters;
  final List<String> types;

  factory CheckoutPlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structured = (json['structured_formatting'] is Map)
        ? Map<String, dynamic>.from(json['structured_formatting'] as Map)
        : const <String, dynamic>{};
    final description = (json['description'] ?? '').toString().trim();
    return CheckoutPlaceSuggestion(
      placeId: (json['place_id'] ?? '').toString().trim(),
      description: description,
      primaryText: (structured['main_text'] ?? description).toString().trim(),
      secondaryText: (structured['secondary_text'] ?? '').toString().trim(),
      distanceMeters: _asInt(json['distance_meters']),
      types: (json['types'] is List)
          ? (json['types'] as List)
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
  }
}

class CheckoutPlaceResult {
  const CheckoutPlaceResult({
    required this.latitude,
    required this.longitude,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final String label;
}

class CheckoutPlacesService {
  const CheckoutPlacesService();

  Future<List<CheckoutPlaceSuggestion>> fetchSuggestions({
    required String query,
    required double biasLat,
    required double biasLng,
  }) async {
    final q = query.trim();
    if (q.length < 2 || profileMapsApiKey.trim().isEmpty) return const [];

    final biasLocation = '$biasLat,$biasLng';
    final sessionToken = 'checkout_${DateTime.now().millisecondsSinceEpoch}';
    final results = await _fetchGoogleSuggestions(
      endpoint: '/maps/api/place/autocomplete/json',
      params: {
        'input': q,
        'key': profileMapsApiKey,
        'language': 'ar',
        'region': 'sy',
        'components': 'country:sy',
        'location': biasLocation,
        'origin': biasLocation,
        'radius': '45000',
        'strictbounds': 'true',
        'sessiontoken': sessionToken,
      },
    );

    final sorted = [...results];
    sorted.sort((a, b) {
      final aScore = _suggestionScore(a, q);
      final bScore = _suggestionScore(b, q);
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.description.length.compareTo(b.description.length);
    });

    if (sorted.length > 12) {
      return sorted.sublist(0, 12);
    }
    return sorted;
  }

  Future<CheckoutPlaceResult?> resolveSuggestion(
    CheckoutPlaceSuggestion suggestion,
  ) async {
    if (suggestion.placeId.trim().isEmpty || profileMapsApiKey.trim().isEmpty) {
      return null;
    }

    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': suggestion.placeId,
        'fields': 'geometry/location,formatted_address,name',
        'language': 'ar',
        'key': profileMapsApiKey,
      },
    );

    try {
      final response = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(_mapsRequestTimeout);
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final status = (body['status'] ?? '').toString();
      if (status != 'OK') return null;

      final result = _asMap(body['result']);
      final geometry = _asMap(result?['geometry']);
      final location = _asMap(geometry?['location']);
      final lat = _asDouble(location?['lat']);
      final lng = _asDouble(location?['lng']);
      if (lat == null || lng == null || !_isWithinSyria(lat: lat, lng: lng)) {
        return null;
      }

      final label =
          (result?['formatted_address'] ?? result?['name'])?.toString().trim();
      return CheckoutPlaceResult(
        latitude: lat,
        longitude: lng,
        label: (label != null && label.isNotEmpty)
            ? label
            : suggestion.description,
      );
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<CheckoutPlaceSuggestion>> _fetchGoogleSuggestions({
    required String endpoint,
    required Map<String, String> params,
  }) async {
    final url = Uri.https('maps.googleapis.com', endpoint, params);
    try {
      final response = await http
          .get(url, headers: const {'Accept': 'application/json'})
          .timeout(_mapsRequestTimeout);
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];
      final status = (body['status'] ?? '').toString();
      if (status != 'OK' && status != 'ZERO_RESULTS') return const [];
      final predictions = body['predictions'];
      if (predictions is! List) return const [];
      return predictions
          .whereType<Map>()
          .map((raw) => CheckoutPlaceSuggestion.fromJson(
                Map<String, dynamic>.from(raw),
              ))
          .where((item) => item.placeId.isNotEmpty)
          .toList(growable: false);
    } on TimeoutException {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  int _suggestionScore(CheckoutPlaceSuggestion item, String query) {
    final q = query.trim().toLowerCase();
    final primary = item.primaryText.toLowerCase();
    final secondary = item.secondaryText.toLowerCase();
    final description = item.description.toLowerCase();
    var score = 0;
    if (primary == q) score += 120;
    if (primary.startsWith(q)) score += 90;
    if (description.startsWith(q)) score += 70;
    if (primary.contains(q)) score += 45;
    if (description.contains(q)) score += 25;
    if (secondary.contains('دمشق') || secondary.contains('syria')) score += 15;
    if (item.distanceMeters != null) {
      final km = item.distanceMeters! / 1000.0;
      if (km <= 2) {
        score += 28;
      } else if (km <= 8) {
        score += 18;
      } else if (km <= 20) {
        score += 9;
      }
    }
    if (item.types.any((t) => t == 'street_address' || t == 'premise')) {
      score += 12;
    } else if (item.types.any((t) => t == 'route' || t == 'subpremise')) {
      score += 8;
    }
    if (secondary.isNotEmpty) score += 5;
    return score;
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

bool _isWithinSyria({required double lat, required double lng}) {
  const minLat = 32.0;
  const maxLat = 37.5;
  const minLng = 35.5;
  const maxLng = 42.5;
  return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}
