import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/features/taxi/errors/taxi_api_exception.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/utils/address_label_utils.dart';
import 'package:najiz_go_express/features/taxi/models/taxi_pricing_model.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/taxi/repositories/taxi_repository.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';
import 'package:najiz_go_express/features/orders/models/live_order_info.dart';
import 'package:najiz_go_express/features/profile/models/referral_coupon_models.dart';
import 'dart:convert';

class TaxiBookingController extends GetxController {
  TaxiBookingController({
    String? token,
    TaxiRepository? taxiRepository,
    OrdersRepository? ordersRepository,
    ProfileRepository? profileRepository,
  }) : token = RxnString(token),
       _taxiRepository = taxiRepository ?? TaxiRepository(),
       _ordersRepository = ordersRepository ?? OrdersRepository(),
       _profileRepository = profileRepository ?? ProfileRepository();

  final RxnString token;
  final TaxiRepository _taxiRepository;
  final OrdersRepository _ordersRepository;
  final ProfileRepository _profileRepository;
  void setAuthToken(String newToken) {
    token.value = newToken;
  }


  final isLoading = false.obs;
  final isPlacingOrder = false.obs;
  final errorMessage = RxnString();

  final pickupLat = 33.5138.obs;
  final pickupLng = 36.2765.obs;
  final dropoffLat = RxnDouble();
  final dropoffLng = RxnDouble();
  late final pickupAddress = ''.obs;
  final dropoffAddress = RxnString();
  final selectingPickupOnMap = true.obs;

  final pricing = Rxn<TaxiPricingModel>();
  final selectedCategoryId = RxnInt();
  final appliedCouponCode = RxnString();
  final couponDiscount = 0.0.obs;
  final availableCoupons = <UserCouponItem>[].obs;
  final isLoadingCoupons = false.obs;
  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  void onInit() {
    super.onInit();
    _initUserLocation();
    loadCoupons();
  }

  Future<void> _initUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        pickupAddress.value = 'location.permissionDenied'.tr;
        return;
      }

      final current = await Geolocator.getCurrentPosition();
      pickupLat.value = current.latitude;
      pickupLng.value = current.longitude;
      await _resolveAddress(
        lat: pickupLat.value,
        lng: pickupLng.value,
        isPickup: true,
      );
    } catch (_) {
      pickupAddress.value = 'location.geoFailed'.tr;
    }
  }

  Future<void> calculatePrices() async {
    if (dropoffLat.value == null || dropoffLng.value == null) {
      errorMessage.value = 'taxi.selectDestination'.tr;
      pricing.value = null;
      return;
    }

    errorMessage.value = null;
    isLoading.value = true;
    try {
      final result = await _taxiRepository.calculateTaxiPrice(
        token: token.value,
        pickupLat: pickupLat.value,
        pickupLng: pickupLng.value,
        dropoffLat: dropoffLat.value!,
        dropoffLng: dropoffLng.value!,
      );
      pricing.value = result;
      if (result.categories.isNotEmpty) {
        selectedCategoryId.value = result.categories.first.vehicleCategory.id;
        if (appliedCouponCode.value != null) {
          _revalidateAppliedCoupon();
        }
      } else {
        selectedCategoryId.value = null;
        couponDiscount.value = 0;
      }
    } on TaxiApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'taxi.priceFailed'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updatePickup({
    required double lat,
    required double lng,
  }) async {
    pickupLat.value = lat;
    pickupLng.value = lng;
    await _resolveAddress(lat: lat, lng: lng, isPickup: true);
    await calculatePrices();
  }

  Future<void> updateDropoff({
    required double lat,
    required double lng,
  }) async {
    dropoffLat.value = lat;
    dropoffLng.value = lng;
    await _resolveAddress(lat: lat, lng: lng, isPickup: false);
    await calculatePrices();
  }

  void setMapSelectionMode(bool isPickup) {
    selectingPickupOnMap.value = isPickup;
  }

  void applyMapSelection({
    required double lat,
    required double lng,
  }) {
    if (!_isWithinSyria(lat: lat, lng: lng)) {
      errorMessage.value = 'location.outsideSyriaBound'.tr;
      return;
    }
    if (selectingPickupOnMap.value) {
      updatePickup(lat: lat, lng: lng);
      return;
    }
    updateDropoff(lat: lat, lng: lng);
  }

  Future<bool> searchAndSelectLocation({
    required String query,
    required bool asPickup,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return false;
    try {
      final suggestions = await fetchLocationSuggestions(query: q);
      if (suggestions.isEmpty) {
        errorMessage.value = 'location.noResultsInSyria'.tr;
        return false;
      }
      return await selectSuggestion(
        suggestion: suggestions.first,
        asPickup: asPickup,
      );
    } catch (_) {
      errorMessage.value = 'location.searchFailed'.tr;
      return false;
    }
  }

  Future<List<PlaceSuggestion>> fetchLocationSuggestions({
    required String query,
  }) async {
    final q = query.trim();
    if (q.length < 2 || _mapsApiKey.trim().isEmpty) return const [];
    final biasLocation = '${pickupLat.value},${pickupLng.value}';
    final sessionToken = _newPlacesSessionToken();
    final localParams = <String, String>{
      'input': q,
      'key': _mapsApiKey,
      'language': 'ar',
      'region': 'sy',
      'components': 'country:sy',
      'location': biasLocation,
      'origin': biasLocation,
      'radius': '45000',
      'strictbounds': 'true',
      'sessiontoken': sessionToken,
    };

    final responses = await Future.wait<List<PlaceSuggestion>>([
      _fetchGoogleSuggestions(
        endpoint: '/maps/api/place/autocomplete/json',
        params: {...localParams, 'types': 'geocode'},
      ),
      _fetchGoogleSuggestions(
        endpoint: '/maps/api/place/autocomplete/json',
        params: localParams,
      ),
      _fetchGoogleSuggestions(
        endpoint: '/maps/api/place/queryautocomplete/json',
        params: localParams,
      ),
    ]);

    final merged = <PlaceSuggestion>[];
    final byPlaceId = <String>{};
    final byDescription = <String>{};
    for (final batch in responses) {
      for (final item in batch) {
        final placeKey = item.placeId.trim();
        final textKey = item.description.trim().toLowerCase();
        if (placeKey.isNotEmpty && byPlaceId.contains(placeKey)) continue;
        if (textKey.isNotEmpty && byDescription.contains(textKey)) continue;
        if (placeKey.isNotEmpty) byPlaceId.add(placeKey);
        if (textKey.isNotEmpty) byDescription.add(textKey);
        merged.add(item);
      }
    }

    merged.sort((a, b) {
      final aScore = _suggestionScore(a, q);
      final bScore = _suggestionScore(b, q);
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.description.length.compareTo(b.description.length);
    });

    if (merged.length > 12) {
      return merged.sublist(0, 12);
    }
    return merged;
  }

  Future<List<PlaceSuggestion>> _fetchGoogleSuggestions({
    required String endpoint,
    required Map<String, String> params,
  }) async {
    final url = Uri.https('maps.googleapis.com', endpoint, params);
    try {
      final response = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return const [];
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];
      final status = (body['status'] ?? '').toString();
      if (status != 'OK' && status != 'ZERO_RESULTS') return const [];
      final predictions = body['predictions'];
      if (predictions is! List) return const [];
      return predictions
          .whereType<Map>()
          .map((raw) => PlaceSuggestion.fromJson(Map<String, dynamic>.from(raw)))
          .where((item) => item.placeId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  int _suggestionScore(PlaceSuggestion item, String query) {
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
    if (secondary.contains('?????') || secondary.contains('????')) score += 15;
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

  String _newPlacesSessionToken() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    return 'taxi_$ms';
  }

  Future<bool> selectSuggestion({
    required PlaceSuggestion suggestion,
    required bool asPickup,
  }) async {
    if (suggestion.placeId.trim().isEmpty || _mapsApiKey.trim().isEmpty) {
      return false;
    }
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': suggestion.placeId,
        'fields': 'geometry/location,formatted_address,name',
        'language': 'ar',
        'key': _mapsApiKey,
      },
    );

    try {
      final response = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) {
        errorMessage.value = 'location.detailsLoadFailed'.tr;
        return false;
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        errorMessage.value = 'location.invalidResponse'.tr;
        return false;
      }
      final status = (body['status'] ?? '').toString();
      if (status != 'OK') {
        errorMessage.value = 'location.detailsLoadFailed'.tr;
        return false;
      }
      final result = _asMap(body['result']);
      final geometry = _asMap(result?['geometry']);
      final location = _asMap(geometry?['location']);
      final lat = _asDouble(location?['lat']);
      final lng = _asDouble(location?['lng']);
      if (lat == null || lng == null || !_isWithinSyria(lat: lat, lng: lng)) {
        errorMessage.value = 'location.resultOutsideSyria'.tr;
        return false;
      }
      final rawLabel =
          (result?['formatted_address'] ?? result?['name'])?.toString().trim();
      final label =
          rawLabel == null || rawLabel.isEmpty
              ? null
              : AddressLabelUtils.format(rawLabel);
      selectingPickupOnMap.value = asPickup;
      errorMessage.value = null;
      if (asPickup) {
        await updatePickup(lat: lat, lng: lng);
        if (label != null && label.isNotEmpty) {
          pickupAddress.value = label;
        }
      } else {
        await updateDropoff(lat: lat, lng: lng);
        if (label != null && label.isNotEmpty) {
          dropoffAddress.value = label;
        }
      }
      return true;
    } catch (_) {
      errorMessage.value = 'location.locationFailed'.tr;
      return false;
    }
  }

  Future<void> _resolveAddress({
    required double lat,
    required double lng,
    required bool isPickup,
  }) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$lat,$lng',
        'language': 'ar',
        'region': 'sy',
        'key': _mapsApiKey,
      },
    );
    try {
      final response = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final label = _extractAreaLabel(body);
        if (label != null && label.isNotEmpty) {
          if (isPickup) {
            pickupAddress.value = label;
          } else {
            dropoffAddress.value = label;
          }
          return;
        }
      }
    } catch (_) {}

    final fallback = await _resolveAddressFromPlacemark(lat, lng);
    if (isPickup) {
      pickupAddress.value =
          fallback ?? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    } else {
      dropoffAddress.value =
          fallback ?? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    }
  }

  Future<String?> _resolveAddressFromPlacemark(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      final p = marks.first;
      final parts = <String>[
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
      ];
      if (parts.isNotEmpty) return AddressLabelUtils.joinParts(parts);
    } catch (_) {}
    return null;
  }

  String? _extractAreaLabel(Map<String, dynamic> body) {
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
        if (parts.isNotEmpty) return AddressLabelUtils.joinParts(parts);
      }

      final formatted = (map['formatted_address'] ?? '').toString().trim();
      if (formatted.isNotEmpty && !_looksLikeCoordinates(formatted)) {
        return AddressLabelUtils.format(formatted);
      }
      final name = (map['name'] ?? '').toString().trim();
      if (name.isNotEmpty && !_looksLikeCoordinates(name)) {
        return AddressLabelUtils.format(name);
      }
    }
    return null;
  }

  bool _looksLikeCoordinates(String input) {
    final text = input.trim();
    return RegExp(r'^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$').hasMatch(text);
  }

  void selectCategory(int id) {
    selectedCategoryId.value = id;
    if (appliedCouponCode.value != null) {
      _revalidateAppliedCoupon();
    }
  }

  TaxiPricingCategory? get selectedCategory {
    final data = pricing.value;
    if (data == null) return null;
    final selectedId = selectedCategoryId.value;
    if (selectedId == null) return null;
    return data.categories.firstWhereOrNull(
      (c) => c.vehicleCategory.id == selectedId,
    );
  }

  Future<LiveOrderInfo> confirmTaxiOrder() async {
    final selected = selectedCategory;
    if (selected == null) {
      throw TaxiApiException('taxi.selectCategory'.tr);
    }
    if (dropoffLat.value == null || dropoffLng.value == null) {
      throw TaxiApiException('taxi.selectDestination'.tr);
    }

    isPlacingOrder.value = true;
    try {
      final authToken = token.value;
      if (authToken == null || authToken.trim().isEmpty) {
        throw TaxiApiException('taxi.loginRequired'.tr);
      }
      final response = await _taxiRepository.createTaxiOrder(
        token: authToken,
        vehicleCategoryId: selected.vehicleCategory.id,
        pickupLat: pickupLat.value,
        pickupLng: pickupLng.value,
        dropoffLat: dropoffLat.value!,
        dropoffLng: dropoffLng.value!,
        couponCode: appliedCouponCode.value,
        paymentMethod: 'cash',
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      final taxiOrder = _asMap(data['taxi_order'] ?? data['taxiOrder']);
      final orderId = _asInt(data['id']);
      if (orderId == null) {
        throw TaxiApiException('taxi.noOrderId'.tr);
      }
      return LiveOrderInfo(
        orderId: orderId,
        orderNumber: (data['order_number'] ?? 'ORD-$orderId').toString(),
        status: (data['status'] ?? 'pending').toString(),
        dispatchStatus: (data['dispatch_status'] ?? '').toString(),
        pickupLat: pickupLat.value,
        pickupLng: pickupLng.value,
        destinationLat: dropoffLat.value!,
        destinationLng: dropoffLng.value!,
        // Match backend: distance comes from taxi_order on create response.
        estimatedDistanceKm:
            _asDouble(taxiOrder?['distance'] ?? taxiOrder?['distance_km']) ??
            selected.pricing.distanceKm,
      );
    } finally {
      isPlacingOrder.value = false;
    }
  }

  Future<void> loadCoupons() async {
    final authToken = token.value;
    if (authToken == null || authToken.trim().isEmpty) return;
    isLoadingCoupons.value = true;
    try {
      final list = await _profileRepository.getMyCoupons(token: authToken);
      availableCoupons.assignAll(
        list.where((e) => e.code.trim().isNotEmpty),
      );
    } catch (_) {
      availableCoupons.clear();
    } finally {
      isLoadingCoupons.value = false;
    }
  }

  Future<void> applyCoupon(String code) async {
    final selected = selectedCategory;
    final authToken = token.value;
    final normalized = code.trim();
    if (selected == null) {
      throw TaxiApiException('taxi.selectCategoryFirst'.tr);
    }
    if (authToken == null || authToken.trim().isEmpty) {
      throw TaxiApiException('taxi.loginForCoupon'.tr);
    }
    if (normalized.isEmpty) return;
    final response = await _ordersRepository.validateCoupon(
      token: authToken,
      code: normalized,
      orderAmount: selected.pricing.estimatedPrice,
    );
    final data = _asMap(response['data']) ?? <String, dynamic>{};
    couponDiscount.value = _asDouble(data['discount']) ?? 0;
    appliedCouponCode.value = normalized;
    if (couponDiscount.value <= 0) {
      AppSnackbar.show(
        'common.warning'.tr, 'checkout.couponInvalid'.tr,
      );
    }
  }

  Future<void> clearCoupon() async {
    appliedCouponCode.value = null;
    couponDiscount.value = 0;
  }

  Future<void> _revalidateAppliedCoupon() async {
    final code = appliedCouponCode.value;
    if (code == null || code.trim().isEmpty) return;
    try {
      await applyCoupon(code);
    } catch (_) {
      couponDiscount.value = 0;
    }
  }

  bool _isWithinSyria({required double lat, required double lng}) {
    const minLat = 32.0;
    const maxLat = 37.5;
    const minLng = 35.5;
    const maxLng = 42.5;
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String primaryText;
  final String secondaryText;
  final int? distanceMeters;
  final List<String> types;

  const PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.primaryText,
    required this.secondaryText,
    this.distanceMeters,
    this.types = const [],
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structured = (json['structured_formatting'] is Map)
        ? Map<String, dynamic>.from(json['structured_formatting'] as Map)
        : const <String, dynamic>{};
    final description = AddressLabelUtils.format(
      (json['description'] ?? '').toString().trim(),
    );
    return PlaceSuggestion(
      placeId: (json['place_id'] ?? '').toString().trim(),
      description: description,
      primaryText: AddressLabelUtils.format(
        (structured['main_text'] ?? description).toString().trim(),
      ),
      secondaryText: AddressLabelUtils.format(
        (structured['secondary_text'] ?? '').toString().trim(),
      ),
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

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

