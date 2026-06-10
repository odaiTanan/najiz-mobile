import 'package:get/get.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/checkout_cart_item.dart';
import 'package:najiz_go_express/features/home/models/referral_coupon_models.dart';
import 'package:najiz_go_express/features/home/models/unavailability_option.dart';
import 'dart:convert';

class OrderCheckoutController extends GetxController {
  OrderCheckoutController({
    String? token,
    required this.vendorId,
    required this.items,
    HomeRepository? repository,
  })  : token = RxnString(token),
        _repository = repository ?? HomeRepository();

  final RxnString token;
  final int vendorId;
  final List<CheckoutCartItem> items;
  final HomeRepository _repository;
  void setAuthToken(String newToken) {
    token.value = newToken;
    if (unavailabilityOptions.isEmpty) {
      loadUnavailabilityOptions();
    }
  }

  final isLoading = false.obs;
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

  @override
  void onInit() {
    super.onInit();
    customAddressName = 'checkout.determiningLocation'.tr.obs;
    _initUserLocationAndCalculate();
    loadCoupons();
    loadUnavailabilityOptions();
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
    await _initUserLocation();
    await calculate();
  }

  Future<void> _initUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        customAddressName.value = 'checkout.locationUnavailable'.tr;
        return;
      }
      final current = await Geolocator.getCurrentPosition();
      lat.value = current.latitude.toString();
      lng.value = current.longitude.toString();
      customAddressName.value = await _resolveAddress(
        current.latitude,
        current.longitude,
      );
    } catch (_) {
      customAddressName.value = 'checkout.locationDetectFailed'.tr;
    }
  }

  Future<void> updateDeliveryLocation({
    required double latitude,
    required double longitude,
  }) async {
    lat.value = latitude.toString();
    lng.value = longitude.toString();
    customAddressName.value = await _resolveAddress(latitude, longitude);
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
      final res = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
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
    isLoading.value = true;
    hasCalculatedPricing.value = false;
    final currentLat = double.tryParse(lat.value);
    final currentLng = double.tryParse(lng.value);
    if (currentLat == null ||
        currentLng == null ||
        !_isWithinSyria(lat: currentLat, lng: currentLng)) {
      errorMessage.value = 'checkout.locationOutsideSyria'.tr;
      isLoading.value = false;
      return;
    }
    try {
      final response = await _repository.calculateOrder(
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
    } on HomeApiException catch (e) {
      if (gateRetry) {
        rethrow;
      }
      if (e.isConnectivityIssue) {
        showNoInternetGateIfNeeded(
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
      isLoading.value = false;
    }
  }

  Future<PlacedOrderInfo> placeOrder() async {
    isPlacingOrder.value = true;
    try {
      final authToken = token.value;
      if (authToken == null || authToken.trim().isEmpty) {
        throw HomeApiException('checkout.loginForOrder'.tr);
      }
      final response = await _repository.createOrder(
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
        throw HomeApiException('checkout.noOrderIdFromServer'.tr);
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
      final list = await _repository.getMyCoupons(token: authToken);
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
      final options = await _repository.getOrderUnavailabilityOptions(
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
