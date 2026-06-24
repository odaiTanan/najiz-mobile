import 'package:get/get.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/features/orders/errors/orders_api_exception.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/orders/models/checkout_cart_item.dart';
import 'package:najiz_go_express/features/profile/models/referral_coupon_models.dart';
import 'package:najiz_go_express/features/profile/models/create_address_payload.dart';
import 'package:najiz_go_express/features/profile/models/user_address.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';
import 'package:najiz_go_express/features/orders/models/unavailability_option.dart';
import 'package:najiz_go_express/features/orders/services/checkout_places_service.dart';
import 'dart:async';
import 'dart:convert';

class OrderCheckoutController extends GetxController {
  OrderCheckoutController({
    String? token,
    required this.vendorId,
    required this.items,
    OrdersRepository? ordersRepository,
    ProfileRepository? profileRepository,
    CheckoutPlacesService? placesService,
  })  : token = RxnString(token),
        _ordersRepository = ordersRepository ?? OrdersRepository(),
        _profileRepository = profileRepository ?? ProfileRepository(),
        _placesService = placesService ?? const CheckoutPlacesService();

  final RxnString token;
  final int vendorId;
  final List<CheckoutCartItem> items;
  final OrdersRepository _ordersRepository;
  final ProfileRepository _profileRepository;
  final CheckoutPlacesService _placesService;
  void setAuthToken(String newToken) {
    token.value = newToken;
    if (unavailabilityOptions.isEmpty) {
      loadUnavailabilityOptions();
    }
    unawaited(loadSavedAddresses());
  }

  final isCalculatingPricing = false.obs;
  final isLoadingLocation = false.obs;
  final isPlacingOrder = false.obs;
  final errorMessage = RxnString();
  final hasCalculatedPricing = false.obs;
  final orderPlaced = false.obs;

  final lat = '33.5138'.obs;
  final lng = '36.2765'.obs;
  late final RxString customAddressName;
  final paymentMethod = 'cash';
  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );
  static const Duration _mapsRequestTimeout = Duration(seconds: 5);
  static const Duration _gpsRefineMinAge = Duration(minutes: 2);

  final subtotal = 0.0.obs;
  final deliveryFee = 0.0.obs;
  final serviceFee = 0.0.obs;
  final couponDiscount = 0.0.obs;
  final total = 0.0.obs;
  final appliedCouponCode = RxnString();
  final availableCoupons = <UserCouponItem>[].obs;
  final isLoadingCoupons = false.obs;
  final unavailabilityOptions = <UnavailabilityOption>[].obs;
  final selectedUnavailabilityAction = RxnString();
  final isLoadingUnavailabilityOptions = false.obs;
  final savedAddresses = <UserAddress>[].obs;
  final selectedAddressId = RxnInt();
  final isMapPickedLocation = false.obs;
  final isLoadingSavedAddresses = false.obs;

  @override
  void onInit() {
    super.onInit();
    customAddressName = 'checkout.determiningLocation'.tr.obs;
    _initUserLocationAndCalculate();
  }

  String? get notes => _buildOrderNotes();

  String? _buildOrderNotes() {
    final parts = items
        .map((item) {
          final note = item.note?.trim() ?? '';
          if (note.isEmpty) return '';
          return '${item.name}: $note';
        })
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return null;
    return parts.join(' | ');
  }

  List<Map<String, dynamic>> get apiItems => items
      .map((e) => {
            'product_id': e.productId,
            'quantity': e.quantity,
            if (e.extras.isNotEmpty)
              'extras': e.extras
                  .map((extra) => {
                        'extra_id': extra.extraId,
                        // Backend request requirement: extra quantity is fixed now.
                        'quantity': 1,
                      })
                  .toList(growable: false),
          })
      .toList(growable: false);

  Future<void> _initUserLocationAndCalculate() async {
    isLoadingLocation.value = true;
    final authToken = token.value?.trim() ?? '';

    unawaited(_loadCheckoutExtras());

    try {
      if (authToken.isNotEmpty) {
        await loadSavedAddresses();
        final preferred = _pickPreferredSavedAddress();
        if (preferred != null) {
          await _applySavedAddress(preferred);
          return;
        }
      }
      final resolved = await _fetchGpsPosition(refineInBackground: true);
      if (!resolved) return;
    } finally {
      isLoadingLocation.value = false;
    }

    final pricing = calculate();
    unawaited(_resolveAddressLabel());
    await pricing;
  }

  Future<void> _loadCheckoutExtras() async {
    await Future.wait<void>([
      loadCoupons(),
      loadUnavailabilityOptions(),
    ]);
  }

  Future<void> loadSavedAddresses({bool forceRefresh = false}) async {
    final authToken = token.value?.trim() ?? '';
    if (authToken.isEmpty) {
      savedAddresses.clear();
      return;
    }
    isLoadingSavedAddresses.value = true;
    try {
      final addresses = await _profileRepository.getMyAddresses(
        token: authToken,
        forceRefresh: forceRefresh,
      );
      final sorted = [...addresses];
      sorted.sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }
        final ad = DateTime.tryParse(a.updatedAt ?? a.createdAt ?? '');
        final bd = DateTime.tryParse(b.updatedAt ?? b.createdAt ?? '');
        if (ad == null && bd == null) return b.id.compareTo(a.id);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      savedAddresses.assignAll(sorted);
    } catch (_) {
      savedAddresses.clear();
    } finally {
      isLoadingSavedAddresses.value = false;
    }
  }

  UserAddress? _pickPreferredSavedAddress() {
    if (savedAddresses.isEmpty) return null;
    for (final address in savedAddresses) {
      if (address.isDefault &&
          address.lat != null &&
          address.lng != null) {
        return address;
      }
    }
    for (final address in savedAddresses) {
      if (address.lat != null && address.lng != null) {
        return address;
      }
    }
    return null;
  }

  Future<void> selectSavedAddress(UserAddress address) async {
    if (address.lat == null || address.lng == null) {
      throw OrdersApiException('checkout.savedAddressMissingCoords'.tr);
    }
    await _applySavedAddress(address);
  }

  Future<void> addAddress(CreateAddressPayload payload) async {
    final authToken = token.value?.trim() ?? '';
    if (authToken.isEmpty) {
      throw OrdersApiException('checkout.loginForAddress'.tr);
    }
    await _profileRepository.addUserAddress(
      token: authToken,
      payload: payload.toJson(),
    );
    await loadSavedAddresses(forceRefresh: true);
    final latest = _pickPreferredSavedAddress();
    if (latest != null) {
      await _applySavedAddress(latest);
    }
  }

  Future<void> useCurrentLocationAddress() async {
    selectedAddressId.value = null;
    isMapPickedLocation.value = false;
    isLoadingLocation.value = true;
    customAddressName.value = 'checkout.determiningLocation'.tr;
    try {
      final resolved = await _fetchGpsPosition(refineInBackground: true);
      if (!resolved) return;
    } finally {
      isLoadingLocation.value = false;
    }
    final pricing = calculate();
    unawaited(_resolveAddressLabel());
    await pricing;
  }

  Future<void> _applySavedAddress(UserAddress address) async {
    selectedAddressId.value = address.id;
    isMapPickedLocation.value = false;
    lat.value = address.lat!.toString();
    lng.value = address.lng!.toString();
    customAddressName.value = address.toDisplayText();
    isLoadingLocation.value = false;
    await calculate();
  }

  Future<List<CheckoutPlaceSuggestion>> fetchLocationSuggestions({
    required String query,
  }) async {
    final biasLat = double.tryParse(lat.value) ?? 33.5138;
    final biasLng = double.tryParse(lng.value) ?? 36.2765;
    return _placesService.fetchSuggestions(
      query: query,
      biasLat: biasLat,
      biasLng: biasLng,
    );
  }

  Future<CheckoutPlaceResult?> resolveLocationSuggestion({
    required String placeId,
    required String fallbackDescription,
  }) {
    return _placesService.resolveSuggestion(
      CheckoutPlaceSuggestion(
        placeId: placeId,
        description: fallbackDescription,
        primaryText: fallbackDescription,
        secondaryText: '',
      ),
    );
  }

  Future<bool> _fetchGpsPosition({required bool refineInBackground}) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        customAddressName.value = 'checkout.locationUnavailable'.tr;
        return false;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        lat.value = lastKnown.latitude.toString();
        lng.value = lastKnown.longitude.toString();
        customAddressName.value = 'checkout.determiningLocation'.tr;
        if (refineInBackground) {
          unawaited(_refineGpsPosition(lastKnown));
        }
        return true;
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      lat.value = current.latitude.toString();
      lng.value = current.longitude.toString();
      customAddressName.value = 'checkout.determiningLocation'.tr;
      return true;
    } catch (_) {
      customAddressName.value = 'checkout.locationDetectFailed'.tr;
      return false;
    }
  }

  Future<void> _refineGpsPosition(Position seed) async {
    if (selectedAddressId.value != null) return;
    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final age = current.timestamp.difference(seed.timestamp);
      if (age < _gpsRefineMinAge &&
          Geolocator.distanceBetween(
                seed.latitude,
                seed.longitude,
                current.latitude,
                current.longitude,
              ) <
              120) {
        return;
      }

      final previousLat = lat.value;
      final previousLng = lng.value;
      lat.value = current.latitude.toString();
      lng.value = current.longitude.toString();

      if (!_coordsChanged(previousLat, previousLng)) return;

      unawaited(_resolveAddressLabel());
      await calculate();
    } catch (_) {}
  }

  bool _coordsChanged(String previousLat, String previousLng) {
    final oldLat = double.tryParse(previousLat);
    final oldLng = double.tryParse(previousLng);
    final newLat = double.tryParse(lat.value);
    final newLng = double.tryParse(lng.value);
    if (oldLat == null || oldLng == null || newLat == null || newLng == null) {
      return true;
    }
    final movedMeters = Geolocator.distanceBetween(
      oldLat,
      oldLng,
      newLat,
      newLng,
    );
    return movedMeters >= 120;
  }

  Future<void> _resolveAddressLabel() async {
    final latitude = double.tryParse(lat.value);
    final longitude = double.tryParse(lng.value);
    if (latitude == null || longitude == null) return;
    try {
      customAddressName.value = await _resolveAddress(latitude, longitude);
    } catch (_) {
      // Keep the last known label/coordinates if reverse geocoding fails.
    }
  }

  Future<void> updateDeliveryLocation({
    required double latitude,
    required double longitude,
    String? addressLabel,
  }) async {
    selectedAddressId.value = null;
    isMapPickedLocation.value = true;
    lat.value = latitude.toString();
    lng.value = longitude.toString();
    if (addressLabel != null && addressLabel.trim().isNotEmpty) {
      customAddressName.value = addressLabel.trim();
    } else {
      customAddressName.value = 'checkout.determiningLocation'.tr;
      unawaited(_resolveAddressLabel());
    }
    await calculate();
  }

  Future<String> _resolveAddress(double latitude, double longitude) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$latitude,$longitude',
        'language': 'ar',
        'region': 'sy',
        'key': _mapsApiKey,
      },
    );
    try {
      final res = await http
          .get(
            url,
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_mapsRequestTimeout);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final label = _extractAreaLabel(body);
        if (label != null && label.isNotEmpty) return label;
      }
    } catch (_) {}
    final fallback = await _resolveAddressFromPlacemark(latitude, longitude);
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  Future<String?> _resolveAddressFromPlacemark(
    double latitude,
    double longitude,
  ) async {
    try {
      final marks = await placemarkFromCoordinates(latitude, longitude);
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
        }
        final parts = <String>[
          if (sublocality != null && sublocality.isNotEmpty) sublocality,
          if (locality != null && locality.isNotEmpty) locality,
        ];
        if (parts.isNotEmpty) return parts.join('، ');
      }

      final formatted = (map['formatted_address'] ?? '').toString().trim();
      if (formatted.isNotEmpty && !_looksLikeCoordinates(formatted)) {
        return formatted;
      }
    }
    return null;
  }

  bool _looksLikeCoordinates(String input) {
    final text = input.trim();
    return RegExp(r'^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$').hasMatch(text);
  }

  Future<void> calculate({bool gateRetry = false}) async {
    errorMessage.value = null;
    isCalculatingPricing.value = true;
    hasCalculatedPricing.value = false;
    final currentLat = double.tryParse(lat.value);
    final currentLng = double.tryParse(lng.value);
    if (currentLat == null ||
        currentLng == null ||
        !_isWithinSyria(lat: currentLat, lng: currentLng)) {
      errorMessage.value = 'checkout.locationOutsideSyria'.tr;
      isCalculatingPricing.value = false;
      return;
    }
    try {
      final response = await _ordersRepository.calculateOrder(
        token: token.value,
        vendorId: vendorId,
        lat: lat.value,
        lng: lng.value,
        customAddressName: customAddressName.value,
        paymentMethod: paymentMethod,
        items: apiItems,
        couponCode: appliedCouponCode.value,
        unavailabilityAction: selectedUnavailabilityAction.value,
        notes: notes,
        serviceName: 'food',
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

      subtotal.value = _asDouble(data['subtotal']);
      deliveryFee.value = _asDouble(data['delivery_fee']);
      couponDiscount.value = _asDouble(data['coupon_discount']);
      total.value = _asDouble(data['total']);
      final computedService = total.value - subtotal.value - deliveryFee.value;
      serviceFee.value = computedService < 0 ? 0 : computedService;
      hasCalculatedPricing.value = true;
    } on OrdersApiException catch (e) {
      if (gateRetry) {
        rethrow;
      }
      if (e.isConnectivityIssue) {
        showNoInternetGateIfNeededFeature(
          e,
          retry: () => calculate(gateRetry: true),
        );
        errorMessage.value = null;
      } else {
        errorMessage.value = e.message;
      }
    } catch (_) {
      if (gateRetry) {
        rethrow;
      }
      errorMessage.value = 'checkout.invoiceFailed'.tr;
    } finally {
      isCalculatingPricing.value = false;
    }
  }

  Future<PlacedOrderInfo> placeOrder() async {
    isPlacingOrder.value = true;
    try {
      final authToken = token.value;
      if (authToken == null || authToken.trim().isEmpty) {
        throw OrdersApiException('checkout.loginForOrder'.tr);
      }
      final response = await _ordersRepository.createOrder(
        token: authToken,
        vendorId: vendorId,
        lat: lat.value,
        lng: lng.value,
        customAddressName: customAddressName.value,
        paymentMethod: paymentMethod,
        items: apiItems,
        couponCode: appliedCouponCode.value,
        unavailabilityAction: selectedUnavailabilityAction.value,
        notes: notes,
        serviceName: 'food',
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      final orderId = _asInt(data['id']);
      if (orderId == null) {
        throw OrdersApiException('checkout.noOrderIdFromServer'.tr);
      }
      orderPlaced.value = true;
      return PlacedOrderInfo(
        orderId: orderId,
        orderNumber: (data['order_number'] ?? '').toString(),
        status: (data['status'] ?? 'pending').toString(),
        dispatchStatus: (data['dispatch_status'] ?? '').toString(),
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
    final normalized = code.trim();
    if (normalized.isEmpty) return;
    appliedCouponCode.value = normalized;
    await calculate();
    if (hasCalculatedPricing.value &&
        appliedCouponCode.value != null &&
        couponDiscount.value <= 0) {
      AppSnackbar.show(
        'common.warning'.tr, 'checkout.couponInvalid'.tr,
      );
    }
  }

  Future<void> clearCoupon() async {
    appliedCouponCode.value = null;
    await calculate();
  }

  Future<void> loadUnavailabilityOptions() async {
    final authToken = token.value;
    if (authToken == null || authToken.trim().isEmpty) return;
    isLoadingUnavailabilityOptions.value = true;
    try {
      final options = await _ordersRepository.getOrderUnavailabilityOptions(
        token: authToken,
      );
      unavailabilityOptions.assignAll(options);
      if (selectedUnavailabilityAction.value == null && options.isNotEmpty) {
        selectedUnavailabilityAction.value = options.first.value;
      }
    } catch (_) {
      unavailabilityOptions.clear();
    } finally {
      isLoadingUnavailabilityOptions.value = false;
    }
  }

  void selectUnavailabilityAction(String value) {
    if (value.trim().isEmpty) return;
    selectedUnavailabilityAction.value = value.trim();
  }
}

bool _isWithinSyria({required double lat, required double lng}) {
  const minLat = 32.0;
  const maxLat = 37.5;
  const minLng = 35.5;
  const maxLng = 42.5;
  return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

class PlacedOrderInfo {
  final int orderId;
  final String orderNumber;
  final String status;
  final String dispatchStatus;

  const PlacedOrderInfo({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.dispatchStatus,
  });
}
