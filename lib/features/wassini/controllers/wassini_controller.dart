import 'dart:async';
import 'dart:convert';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/utils/address_label_utils.dart';
import 'package:najiz_go_express/features/orders/models/live_order_info.dart';
import 'package:najiz_go_express/features/shipping/errors/shipping_api_exception.dart';
import 'package:najiz_go_express/features/shipping/controllers/shipping_controller.dart'
    show ShippingPlaceSuggestion;
import 'package:najiz_go_express/features/wassini/repositories/wassini_repository.dart';

class WassiniController extends GetxController {
  WassiniController({String? token, WassiniRepository? repository})
    : token = RxnString(token),
      _repository = repository ?? WassiniRepository();

  final RxnString token;
  final WassiniRepository _repository;

  final requestDescription = ''.obs;
  final purchaseAmountText = ''.obs;
  final purchaseCurrency = 'SYP'.obs;

  final senderName = ''.obs;
  final senderPhone = ''.obs;
  final receiverName = ''.obs;
  final receiverPhone = ''.obs;

  final pickupLat = RxnDouble();
  final pickupLng = RxnDouble();
  final destLat = RxnDouble();
  final destLng = RxnDouble();

  final pickupAddress = ''.obs;
  final destinationAddress = ''.obs;

  final pickupArea = ''.obs;
  final pickupStreet = ''.obs;
  final pickupDetails = ''.obs;

  final destinationArea = ''.obs;
  final destinationStreet = ''.obs;
  final destinationDetails = ''.obs;

  final isLoadingLocation = false.obs;
  final isCalculating = false.obs;
  final isCreatingOrder = false.obs;

  final deliveryFee = RxnDouble();
  final total = RxnDouble();
  final distance = RxnDouble();

  final errorMessage = RxnString();

  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );

  Timer? _calculateDebounce;

  @override
  void onInit() {
    super.onInit();
    _initUserLocation();
  }

  @override
  void onClose() {
    _calculateDebounce?.cancel();
    super.onClose();
  }

  void setAuthToken(String value) {
    token.value = value;
  }

  void setRequestDescription(String value) {
    requestDescription.value = value;
  }

  void setPurchaseAmount(String value) {
    purchaseAmountText.value = value;
  }

  void setPurchaseCurrency(String value) {
    purchaseCurrency.value = value;
    _scheduleCalculate();
  }

  void setContacts({
    required String senderNameValue,
    required String senderPhoneValue,
    required String receiverNameValue,
    required String receiverPhoneValue,
  }) {
    senderName.value = senderNameValue;
    senderPhone.value = senderPhoneValue;
    receiverName.value = receiverNameValue;
    receiverPhone.value = receiverPhoneValue;
  }

  Future<void> _initUserLocation() async {
    isLoadingLocation.value = true;

    try {
      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        pickupAddress.value = 'تعذر الوصول إلى موقعك';
        return;
      }

      final current = await Geolocator.getCurrentPosition();

      destLat.value = current.latitude;
      destLng.value = current.longitude;

      await _resolveAddress(
        lat: current.latitude,
        lng: current.longitude,
        isPickup: false,
      );
    } catch (_) {
      pickupAddress.value = 'تعذر تحديد الموقع';
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> setPickupLocation({
    required double lat,
    required double lng,
  }) async {
    if (!_isWithinSyria(lat: lat, lng: lng)) {
      errorMessage.value = 'الموقع خارج نطاق الخدمة';
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
      errorMessage.value = 'الموقع خارج نطاق الخدمة';
      return;
    }

    destLat.value = lat;
    destLng.value = lng;

    await _resolveAddress(lat: lat, lng: lng, isPickup: false);

    _scheduleCalculate();
  }

  Future<bool> setAddressFromText({
    required String address,
    required bool isPickup,
  }) async {
    final query = address.trim();

    if (query.length < 3) {
      errorMessage.value = 'يرجى كتابة عنوان أوضح';
      return false;
    }

    errorMessage.value = null;
    isLoadingLocation.value = true;

    try {
      final url = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': '$query, سوريا',
        'key': _mapsApiKey,
        'language': 'ar',
        'region': 'sy',
      });

      final response = await http.get(url);

      if (response.statusCode != 200) {
        errorMessage.value = 'تعذر البحث عن العنوان';
        return false;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        errorMessage.value = 'تعذر قراءة العنوان';
        return false;
      }

      final results = decoded['results'];

      if (results is! List || results.isEmpty) {
        errorMessage.value = 'لم يتم العثور على العنوان';
        return false;
      }

      final first = Map<String, dynamic>.from(results.first as Map);
      final geometry = first['geometry'];

      if (geometry is! Map) {
        errorMessage.value = 'تعذر تحديد الموقع';
        return false;
      }

      final location = geometry['location'];

      if (location is! Map) {
        errorMessage.value = 'تعذر تحديد الموقع';
        return false;
      }

      final lat = _numToDouble(location['lat']);
      final lng = _numToDouble(location['lng']);

      if (lat == null || lng == null) {
        errorMessage.value = 'تعذر تحديد إحداثيات العنوان';
        return false;
      }

      if (!_isWithinSyria(lat: lat, lng: lng)) {
        errorMessage.value = 'الموقع خارج نطاق الخدمة';
        return false;
      }

      final rawLabel = (first['formatted_address'] ?? query).toString().trim();

      final label = rawLabel.isEmpty
          ? query
          : AddressLabelUtils.format(rawLabel);

      if (isPickup) {
        pickupLat.value = lat;
        pickupLng.value = lng;
        pickupAddress.value = label;
      } else {
        destLat.value = lat;
        destLng.value = lng;
        destinationAddress.value = label;
      }

      _scheduleCalculate();
      return true;
    } catch (_) {
      errorMessage.value = 'تعذر البحث عن العنوان';
      return false;
    } finally {
      isLoadingLocation.value = false;
    }
  }

  bool get canCalculate =>
      pickupLat.value != null &&
      pickupLng.value != null &&
      destLat.value != null &&
      destLng.value != null;

  bool get canConfirmOrder =>
      canCalculate &&
      total.value != null &&
      requestDescription.value.trim().length >= 3 &&
      senderName.value.trim().isNotEmpty &&
      senderPhone.value.trim().isNotEmpty &&
      receiverName.value.trim().isNotEmpty &&
      receiverPhone.value.trim().isNotEmpty;

  double? get purchaseAmount {
    final value = purchaseAmountText.value.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  Future<void> calculatePrice() async {
    if (!canCalculate) {
      deliveryFee.value = null;
      total.value = null;
      distance.value = null;
      return;
    }

    errorMessage.value = null;
    isCalculating.value = true;

    try {
      final result = await _repository.calculatePrice(
        token: token.value,
        pickupLat: pickupLat.value!,
        pickupLng: pickupLng.value!,
        destLat: destLat.value!,
        destLng: destLng.value!,
        purchaseAmount: purchaseAmount,
        purchaseCurrency: purchaseAmount == null
            ? null
            : purchaseCurrency.value,
      );

      final data = (result['data'] is Map)
          ? Map<String, dynamic>.from(result['data'] as Map)
          : <String, dynamic>{};

      deliveryFee.value = _numToDouble(data['delivery_fee']);
      total.value = _numToDouble(data['total']);
      distance.value = _numToDouble(data['distance']);
    } on ShippingApiException catch (e) {
      errorMessage.value = e.message;
      deliveryFee.value = null;
      total.value = null;
      distance.value = null;
    } catch (_) {
      errorMessage.value = 'تعذر حساب سعر الخدمة';
      deliveryFee.value = null;
      total.value = null;
      distance.value = null;
    } finally {
      isCalculating.value = false;
    }
  }

  Future<LiveOrderInfo> createOrder() async {
    if (!canConfirmOrder) {
      throw ShippingApiException('يرجى تعبئة جميع البيانات المطلوبة');
    }

    final authToken = token.value;

    if (authToken == null || authToken.trim().isEmpty) {
      throw ShippingApiException('يجب تسجيل الدخول أولاً');
    }

    isCreatingOrder.value = true;

    try {
      final response = await _repository.createOrder(
        token: authToken,
        requestDescription: requestDescription.value,
        pickupLat: pickupLat.value!,
        pickupLng: pickupLng.value!,
        destLat: destLat.value!,
        destLng: destLng.value!,
        purchaseAmount: purchaseAmount,
        purchaseCurrency: purchaseAmount == null
            ? null
            : purchaseCurrency.value,
        senderName: senderName.value,
        senderPhone: senderPhone.value,
        receiverName: receiverName.value,
        receiverPhone: receiverPhone.value,
        region: destinationArea.value.trim().isNotEmpty
            ? destinationArea.value.trim()
            : pickupArea.value.trim(),
        street: destinationStreet.value.trim().isNotEmpty
            ? destinationStreet.value.trim()
            : pickupStreet.value.trim(),
        addressDetails: destinationDetails.value.trim().isNotEmpty
            ? destinationDetails.value.trim()
            : pickupDetails.value.trim(),
        paymentMethod: 'cash',
      );

      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

      final orderId = _asInt(data['id']);

      if (orderId == null) {
        throw ShippingApiException('لم يتم إرجاع رقم الطلب');
      }

      return LiveOrderInfo(
        orderId: orderId,
        orderNumber: (data['order_number'] ?? 'WSN-$orderId').toString(),
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

  Future<List<ShippingPlaceSuggestion>> fetchLocationSuggestions({
    required String query,
  }) async {
    final q = query.trim();

    if (q.length < 2 || _mapsApiKey.trim().isEmpty) {
      return const [];
    }

    final bias = '${pickupLat.value ?? 33.5138},${pickupLng.value ?? 36.2765}';

    final url =
        Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
          'input': q,
          'key': _mapsApiKey,
          'language': 'ar',
          'region': 'sy',
          'components': 'country:sy',
          'location': bias,
          'radius': '45000',
        });

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return const [];
      }

      final body = jsonDecode(response.body);

      if (body is! Map<String, dynamic>) {
        return const [];
      }

      final predictions = body['predictions'];

      if (predictions is! List) {
        return const [];
      }

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
    if (suggestion.placeId.trim().isEmpty) {
      return null;
    }

    final url =
        Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
          'place_id': suggestion.placeId,
          'fields': 'geometry/location,formatted_address,name',
          'language': 'ar',
          'key': _mapsApiKey,
        });

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return null;
      }

      final body = jsonDecode(response.body);

      if (body is! Map<String, dynamic>) {
        return null;
      }

      final result = body['result'];

      if (result is! Map) {
        return null;
      }

      final geometry = result['geometry'];

      if (geometry is! Map) {
        return null;
      }

      final location = geometry['location'];

      if (location is! Map) {
        return null;
      }

      final lat = _numToDouble(location['lat']);
      final lng = _numToDouble(location['lng']);

      if (lat == null || lng == null || !_isWithinSyria(lat: lat, lng: lng)) {
        return null;
      }

      final rawLabel = (result['formatted_address'] ?? result['name'])
          ?.toString()
          .trim();

      return (
        lat: lat,
        lng: lng,
        label: rawLabel == null || rawLabel.isEmpty
            ? null
            : AddressLabelUtils.format(rawLabel),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolveAddress({
    required double lat,
    required double lng,
    required bool isPickup,
  }) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);

      if (marks.isNotEmpty) {
        final p = marks.first;

        final parts = <String>[
          if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
          if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
        ];

        if (parts.isNotEmpty) {
          final label = AddressLabelUtils.joinParts(parts);

          if (isPickup) {
            pickupAddress.value = label;
          } else {
            destinationAddress.value = label;
          }

          return;
        }
      }
    } catch (_) {}

    final fallback = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';

    if (isPickup) {
      pickupAddress.value = fallback;
    } else {
      destinationAddress.value = fallback;
    }
  }

  void _scheduleCalculate() {
    _calculateDebounce?.cancel();

    _calculateDebounce = Timer(
      const Duration(milliseconds: 500),
      calculatePrice,
    );
  }

  bool _isWithinSyria({required double lat, required double lng}) {
    const minLat = 32.0;
    const maxLat = 37.5;
    const minLng = 35.5;
    const maxLng = 42.5;

    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  double? _numToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
