import 'dart:async';
import 'dart:convert';
import 'package:najiz_go_express/features/shipping/errors/shipping_api_exception.dart';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/utils/address_label_utils.dart';
import 'package:najiz_go_express/features/shipping/repositories/shipping_repository.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';
import 'package:najiz_go_express/features/orders/models/live_order_info.dart';
import 'package:najiz_go_express/features/profile/models/referral_coupon_models.dart';

class ShippingController extends GetxController {
  ShippingController({
    String? token,
    ShippingRepository? shippingRepository,
    ProfileRepository? profileRepository,
  }) : token = RxnString(token),
       _shippingRepository = shippingRepository ?? ShippingRepository(),
       _profileRepository = profileRepository ?? ProfileRepository();

  final RxnString token;
  final ShippingRepository _shippingRepository;
  final ProfileRepository _profileRepository;
  void setAuthToken(String newToken) {
    token.value = newToken;
  }


  final weightController = ''.obs;
  final lengthController = ''.obs;
  final widthController = ''.obs;
  final heightController = ''.obs;
  final senderNameController = ''.obs;
  final senderPhoneController = ''.obs;
  final receiverNameController = ''.obs;
  final receiverPhoneController = ''.obs;
  final packageType = RxnString();
  final isBreakable = false.obs;

  final pickupLat = RxnDouble();
  final pickupLng = RxnDouble();
  final destLat = RxnDouble();
  final destLng = RxnDouble();
  late final pickupAddress = ''.obs;
  final destinationAddress = RxnString();
  final pickupAddressName = ''.obs;
  final pickupArea = ''.obs;
  final pickupStreet = ''.obs;
  final pickupBuilding = ''.obs;
  final pickupDetails = ''.obs;
  final destinationAddressName = ''.obs;
  final destinationArea = ''.obs;
  final destinationStreet = ''.obs;
  final destinationBuilding = ''.obs;
  final destinationDetails = ''.obs;

  final isLoadingLocation = false.obs;
  final isCalculating = false.obs;
  final isCreatingOrder = false.obs;
  final errorMessage = RxnString();

  final subtotal = RxnDouble();
  final deliveryFee = RxnDouble();
  final couponDiscount = 0.0.obs;
  final total = RxnDouble();
  final distance = RxnDouble();
  final parcelCategory = RxnString();
  final appliedCouponCode = RxnString();
  final availableCoupons = <UserCouponItem>[].obs;
  final isLoadingCoupons = false.obs;
  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );

  Timer? _calculateDebounce;

  @override
  void onInit() {
    super.onInit();
    _initUserLocation();
    loadCoupons();
  }

  @override
  void onClose() {
    _calculateDebounce?.cancel();
    super.onClose();
  }

  Future<void> _initUserLocation() async {
    isLoadingLocation.value = true;
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
        lat: current.latitude,
        lng: current.longitude,
        isPickup: true,
      );
    } catch (_) {
      pickupAddress.value = 'location.geoFailed'.tr;
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> setPickupLocation({
    required double lat,
    required double lng,
  }) async {
    if (!_isWithinSyria(lat: lat, lng: lng)) {
      errorMessage.value = 'shipping.outsideSyria'.tr;
      return;
    }
    pickupLat.value = lat;
    pickupLng.value = lng;
    await _resolveAddress(lat: lat, lng: lng, isPickup: true);
    _scheduleCalculate();
  }

  Future<void> setDestinationLocation({
    required double lat,
    required double lng,
  }) async {
    if (!_isWithinSyria(lat: lat, lng: lng)) {
      errorMessage.value = 'shipping.outsideSyria'.tr;
      return;
    }
    destLat.value = lat;
    destLng.value = lng;
    await _resolveAddress(lat: lat, lng: lng, isPickup: false);
    _scheduleCalculate();
  }

  Future<void> applyPickupAddressSelection({
    required double lat,
    required double lng,
    required String mapLabel,
    required String addressName,
    required String area,
    required String street,
    required String building,
    required String details,
  }) async {
    await setPickupLocation(lat: lat, lng: lng);
    pickupAddressName.value = addressName.trim();
    pickupArea.value = area.trim();
    pickupStreet.value = street.trim();
    pickupBuilding.value = building.trim();
    pickupDetails.value = details.trim();
    pickupAddress.value = _composeDisplayAddress(
      mapLabel: mapLabel,
      addressName: pickupAddressName.value,
      area: pickupArea.value,
      street: pickupStreet.value,
      building: pickupBuilding.value,
      details: pickupDetails.value,
    );
  }

  Future<void> applyDestinationAddressSelection({
    required double lat,
    required double lng,
    required String mapLabel,
    required String addressName,
    required String area,
    required String street,
    required String building,
    required String details,
  }) async {
    await setDestinationLocation(lat: lat, lng: lng);
    destinationAddressName.value = addressName.trim();
    destinationArea.value = area.trim();
    destinationStreet.value = street.trim();
    destinationBuilding.value = building.trim();
    destinationDetails.value = details.trim();
    destinationAddress.value = _composeDisplayAddress(
      mapLabel: mapLabel,
      addressName: destinationAddressName.value,
      area: destinationArea.value,
      street: destinationStreet.value,
      building: destinationBuilding.value,
      details: destinationDetails.value,
    );
  }

  String _composeDisplayAddress({
    required String mapLabel,
    required String addressName,
    required String area,
    required String street,
    required String building,
    required String details,
  }) {
    final meta = <String>[
      if (addressName.trim().isNotEmpty) addressName.trim(),
      if (area.trim().isNotEmpty) area.trim(),
      if (street.trim().isNotEmpty) street.trim(),
      if (building.trim().isNotEmpty) 'shipping.buildingPrefix'.trParams({'name': building}),
      if (details.trim().isNotEmpty) details.trim(),
    ];
    if (meta.isEmpty) return mapLabel.trim();
    final label = mapLabel.trim();
    if (label.isEmpty) return meta.join(' - ');
    return '${meta.join(' - ')}\n$label';
  }

  Future<({double lat, double lng})?> searchLocationInSyria(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    try {
      final suggestions = await fetchLocationSuggestions(query: q);
      if (suggestions.isEmpty) return null;
      final selected = await selectSuggestionLocation(
        suggestion: suggestions.first,
      );
      if (selected == null) return null;
      return (lat: selected.lat, lng: selected.lng);
    } catch (_) {
      return null;
    }
  }

  Future<List<ShippingPlaceSuggestion>> fetchLocationSuggestions({
    required String query,
  }) async {
    final q = query.trim();
    if (q.length < 2 || _mapsApiKey.trim().isEmpty) return const [];
    final sessionToken = _newPlacesSessionToken();
    final biasLocation = '${pickupLat.value ?? 33.5138},${pickupLng.value ?? 36.2765}';
    final params = <String, String>{
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
    final responses = await Future.wait<List<ShippingPlaceSuggestion>>([
      _fetchGoogleSuggestions(
        endpoint: '/maps/api/place/autocomplete/json',
        params: {...params, 'types': 'geocode'},
      ),
      _fetchGoogleSuggestions(
        endpoint: '/maps/api/place/queryautocomplete/json',
        params: params,
      ),
    ]);
    final merged = <ShippingPlaceSuggestion>[];
    final seenIds = <String>{};
    for (final batch in responses) {
      for (final item in batch) {
        if (item.placeId.isEmpty || seenIds.contains(item.placeId)) continue;
        seenIds.add(item.placeId);
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

  int _suggestionScore(ShippingPlaceSuggestion item, String query) {
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
    return 'ship_$ms';
  }

  Future<List<ShippingPlaceSuggestion>> _fetchGoogleSuggestions({
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
          .map(
            (raw) => ShippingPlaceSuggestion.fromJson(
              Map<String, dynamic>.from(raw),
            ),
          )
          .where((item) => item.placeId.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<({double lat, double lng, String? label})?> selectSuggestionLocation({
    required ShippingPlaceSuggestion suggestion,
  }) async {
    if (suggestion.placeId.trim().isEmpty || _mapsApiKey.trim().isEmpty) {
      return null;
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
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final status = (body['status'] ?? '').toString();
      if (status != 'OK') return null;
      final result = (body['result'] is Map)
          ? Map<String, dynamic>.from(body['result'] as Map)
          : <String, dynamic>{};
      final geometry = (result['geometry'] is Map)
          ? Map<String, dynamic>.from(result['geometry'] as Map)
          : <String, dynamic>{};
      final location = (geometry['location'] is Map)
          ? Map<String, dynamic>.from(geometry['location'] as Map)
          : <String, dynamic>{};
      final lat = _numToDouble(location['lat']);
      final lng = _numToDouble(location['lng']);
      if (lat == null || lng == null || !_isWithinSyria(lat: lat, lng: lng)) {
        return null;
      }
      final rawLabel =
          (result['formatted_address'] ?? result['name'])?.toString().trim();
      final label =
          rawLabel == null || rawLabel.isEmpty
              ? null
              : AddressLabelUtils.format(rawLabel);
      return (lat: lat, lng: lng, label: label);
    } catch (_) {
      return null;
    }
  }

  void onShippingInputsChanged({
    required String weight,
    required String length,
    required String width,
    required String height,
  }) {
    final normalizedWeight = weight.trim();
    final normalizedLength = length.trim();
    final normalizedWidth = width.trim();
    final normalizedHeight = height.trim();
    final didChange =
        weightController.value.trim() != normalizedWeight ||
        lengthController.value.trim() != normalizedLength ||
        widthController.value.trim() != normalizedWidth ||
        heightController.value.trim() != normalizedHeight;

    weightController.value = weight;
    lengthController.value = length;
    widthController.value = width;
    heightController.value = height;
    if (didChange) {
      _scheduleCalculate();
    }
  }

  void onContactsChanged({
    required String senderName,
    required String senderPhone,
    required String receiverName,
    required String receiverPhone,
  }) {
    senderNameController.value = senderName;
    senderPhoneController.value = senderPhone;
    receiverNameController.value = receiverName;
    receiverPhoneController.value = receiverPhone;
  }

  bool get canCalculate =>
      _parseDouble(weightController.value) != null &&
      _parseDouble(lengthController.value) != null &&
      _parseDouble(widthController.value) != null &&
      _parseDouble(heightController.value) != null &&
      pickupLat.value != null &&
      pickupLng.value != null &&
      destLat.value != null &&
      destLng.value != null;

  bool get canConfirmOrder =>
      canCalculate &&
      total.value != null &&
      (packageType.value?.trim().isNotEmpty ?? false) &&
      _isValidFullName(senderNameController.value) &&
      _isValidPhone(senderPhoneController.value) &&
      _isValidFullName(receiverNameController.value) &&
      _isValidPhone(receiverPhoneController.value);

  void setPackageType(String value) {
    packageType.value = value.trim();
    _scheduleCalculate();
  }

  void setBreakable(bool value) {
    isBreakable.value = value;
    _scheduleCalculate();
  }

  Future<void> calculateShippingPrice() async {
    if (!canCalculate) {
      subtotal.value = null;
      deliveryFee.value = null;
      total.value = null;
      distance.value = null;
      parcelCategory.value = null;
      return;
    }

    final weight = _parseDouble(weightController.value)!;
    final length = _parseDouble(lengthController.value)!;
    final width = _parseDouble(widthController.value)!;
    final height = _parseDouble(heightController.value)!;

    errorMessage.value = null;
    isCalculating.value = true;
    try {
      final result = await _shippingRepository.calculateShippingPrice(
        token: token.value,
        weight: weight,
        length: length,
        width: width,
        height: height,
        pickupLat: pickupLat.value!,
        pickupLng: pickupLng.value!,
        destLat: destLat.value!,
        destLng: destLng.value!,
        packageType: packageType.value,
        isBreakable: isBreakable.value,
        couponCode: appliedCouponCode.value,
        paymentMethod: 'cash',
      );
      final data =
          (result['data'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          <String, dynamic>{};
      subtotal.value = _numToDouble(data['subtotal']);
      deliveryFee.value = _numToDouble(data['delivery_fee']);
      couponDiscount.value = _numToDouble(data['coupon_discount']) ?? 0;
      total.value = _numToDouble(data['total']);
      distance.value = _numToDouble(data['distance']);
      parcelCategory.value = data['parcel_category']?.toString();
    } on ShippingApiException catch (e) {
      errorMessage.value = e.message;
      subtotal.value = null;
      deliveryFee.value = null;
      couponDiscount.value = 0;
      total.value = null;
      distance.value = null;
      parcelCategory.value = null;
    } catch (e) {
      errorMessage.value = 'shipping.calcFailed'.tr;
      subtotal.value = null;
      deliveryFee.value = null;
      couponDiscount.value = 0;
      total.value = null;
      distance.value = null;
      parcelCategory.value = null;
    } finally {
      isCalculating.value = false;
    }
  }

  Future<LiveOrderInfo> createShippingOrder() async {
    if (!canConfirmOrder) {
      if (!_isValidFullName(senderNameController.value)) {
        throw ShippingApiException(_nameValidationMessage(senderNameController.value));
      }
      if (!_isValidPhone(senderPhoneController.value)) {
        final digits = _phoneDigits(senderPhoneController.value);
        if (!digits.startsWith('09')) {
          throw ShippingApiException('shipping.phoneStart09'.trParams({'field': 'shipping.senderPhone'.tr}));
        }
        throw ShippingApiException('shipping.phone10Digits'.trParams({'field': 'shipping.senderPhone'.tr}));
      }
      if (!_isValidFullName(receiverNameController.value)) {
        throw ShippingApiException(_nameValidationMessage(receiverNameController.value));
      }
      if (!_isValidPhone(receiverPhoneController.value)) {
        final digits = _phoneDigits(receiverPhoneController.value);
        if (!digits.startsWith('09')) {
          throw ShippingApiException('shipping.phoneStart09'.trParams({'field': 'shipping.receiverPhone'.tr}));
        }
        throw ShippingApiException('shipping.phone10Digits'.trParams({'field': 'shipping.receiverPhone'.tr}));
      }
      throw ShippingApiException('shipping.fillAllFields'.tr);
    }
    isCreatingOrder.value = true;
    try {
      final authToken = token.value;
      if (authToken == null || authToken.trim().isEmpty) {
        throw ShippingApiException('shipping.loginRequired'.tr);
      }
      final response = await _shippingRepository.createShippingOrder(
        token: authToken,
        weight: _parseDouble(weightController.value)!,
        length: _parseDouble(lengthController.value)!,
        width: _parseDouble(widthController.value)!,
        height: _parseDouble(heightController.value)!,
        pickupLat: pickupLat.value!,
        pickupLng: pickupLng.value!,
        destLat: destLat.value!,
        destLng: destLng.value!,
        packageType: packageType.value!,
        isBreakable: isBreakable.value,
        senderName: senderNameController.value.trim(),
        senderPhone: senderPhoneController.value.trim(),
        receiverName: receiverNameController.value.trim(),
        receiverPhone: receiverPhoneController.value.trim(),
        region: destinationArea.value.trim().isNotEmpty
            ? destinationArea.value.trim()
            : pickupArea.value.trim(),
        street: destinationStreet.value.trim().isNotEmpty
            ? destinationStreet.value.trim()
            : pickupStreet.value.trim(),
        addressDetails: destinationDetails.value.trim().isNotEmpty
            ? destinationDetails.value.trim()
            : pickupDetails.value.trim(),
        couponCode: appliedCouponCode.value,
        paymentMethod: 'cash',
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      final orderId = _asInt(data['id']);
      if (orderId == null) {
        throw ShippingApiException('shipping.noOrderId'.tr);
      }
      return LiveOrderInfo(
        orderId: orderId,
        orderNumber: (data['order_number'] ?? 'ORD-$orderId').toString(),
        status: (data['status'] ?? 'pending').toString(),
        dispatchStatus: (data['dispatch_status'] ?? '').toString(),
        pickupLat: pickupLat.value!,
        pickupLng: pickupLng.value!,
        destinationLat: destLat.value!,
        destinationLng: destLng.value!,
      );
    } finally {
      isCreatingOrder.value = false;
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
    final normalized = code.trim();
    if (normalized.isEmpty) return;
    appliedCouponCode.value = normalized;
    await calculateShippingPrice();
    if (appliedCouponCode.value != null && couponDiscount.value <= 0) {
      AppSnackbar.show(
        'common.warning'.tr, 'checkout.couponInvalid'.tr,
      );
    }
  }

  Future<void> clearCoupon() async {
    appliedCouponCode.value = null;
    await calculateShippingPrice();
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
            destinationAddress.value = label;
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
      destinationAddress.value =
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

  void _scheduleCalculate() {
    _calculateDebounce?.cancel();
    _calculateDebounce = Timer(const Duration(milliseconds: 550), () {
      calculateShippingPrice();
    });
  }

  double? _parseDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.trim());
  }

  double? _numToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  bool _isValidFullName(String value) {
    final input = value.trim();
    if (input.runes.length < 5) return false;
    return RegExp(r'^[\p{L}\s]+$', unicode: true).hasMatch(input);
  }

  String _nameValidationMessage(String value) {
    final input = value.trim();
    if (input.runes.length < 5) return 'shipping.nameTooShort'.tr;
    if (!RegExp(r'^[\p{L}\s]+$', unicode: true).hasMatch(input)) {
      return 'shipping.nameCharsOnly'.tr;
    }
    return 'shipping.nameInvalid'.tr;
  }

  bool _isValidPhone(String value) {
    final digits = _phoneDigits(value);
    return digits.length == 10 && digits.startsWith('09');
  }

  String _phoneDigits(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  String? liveNameError(String value, {required String label}) {
    final input = value.trim();
    if (input.isEmpty) return null;
    if (!_isValidFullName(input)) return _nameValidationMessage(input);
    return null;
  }

  String? livePhoneError(String value, {required String label}) {
    final input = value.trim();
    if (input.isEmpty) return null;
    final digits = _phoneDigits(input);
    if (!digits.startsWith('09')) return 'shipping.phoneStart09'.trParams({'field': label});
    if (digits.length < 10) return 'shipping.phoneTooShort'.trParams({'field': label});
    if (digits.length > 10) return 'shipping.phone10Digits'.trParams({'field': label});
    return null;
  }

  bool _isWithinSyria({required double lat, required double lng}) {
    const minLat = 32.0;
    const maxLat = 37.5;
    const minLng = 35.5;
    const maxLng = 42.5;
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }
}

class ShippingPlaceSuggestion {
  final String placeId;
  final String description;
  final String primaryText;
  final String secondaryText;
  final int? distanceMeters;
  final List<String> types;

  const ShippingPlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.primaryText,
    required this.secondaryText,
    this.distanceMeters,
    this.types = const [],
  });

  factory ShippingPlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structured = (json['structured_formatting'] is Map)
        ? Map<String, dynamic>.from(json['structured_formatting'] as Map)
        : const <String, dynamic>{};
    final description = AddressLabelUtils.format(
      (json['description'] ?? '').toString().trim(),
    );
    return ShippingPlaceSuggestion(
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
