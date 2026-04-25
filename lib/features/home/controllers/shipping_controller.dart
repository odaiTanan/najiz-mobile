import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/live_order_info.dart';

class ShippingController extends GetxController {
  ShippingController({String? token, HomeRepository? repository})
    : token = RxnString(token),
      _repository = repository ?? HomeRepository();

  final RxnString token;
  final HomeRepository _repository;
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

  final pickupLat = RxnDouble();
  final pickupLng = RxnDouble();
  final destLat = RxnDouble();
  final destLng = RxnDouble();
  final pickupAddress = 'جاري تحديد موقع الاستلام...'.obs;
  final destinationAddress = RxnString();

  final isLoadingLocation = false.obs;
  final isCalculating = false.obs;
  final isCreatingOrder = false.obs;
  final errorMessage = RxnString();

  final subtotal = RxnDouble();
  final deliveryFee = RxnDouble();
  final total = RxnDouble();
  final distance = RxnDouble();
  final parcelCategory = RxnString();

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

  Future<void> _initUserLocation() async {
    isLoadingLocation.value = true;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        pickupAddress.value = 'لم يتم منح صلاحية الموقع';
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
      pickupAddress.value = 'تعذر تحديد موقعك الحالي';
    } finally {
      isLoadingLocation.value = false;
    }
  }

  Future<void> setPickupLocation({
    required double lat,
    required double lng,
  }) async {
    if (!_isWithinSyria(lat: lat, lng: lng)) {
      errorMessage.value = 'الموقع المحدد خارج سوريا';
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
      errorMessage.value = 'الموقع المحدد خارج سوريا';
      return;
    }
    destLat.value = lat;
    destLng.value = lng;
    await _resolveAddress(lat: lat, lng: lng, isPickup: false);
    _scheduleCalculate();
  }

  Future<({double lat, double lng})?> searchLocationInSyria(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final url = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'format': 'jsonv2',
        'q': q,
        'countrycodes': 'sy',
        'limit': '1',
        'addressdetails': '1',
        'accept-language': 'ar',
      },
    );
    try {
      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'najiz_go_express/1.0',
        },
      );
      if (response.statusCode != 200) return null;
      final list = jsonDecode(response.body);
      if (list is! List || list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null || !_isWithinSyria(lat: lat, lng: lng)) {
        return null;
      }
      return (lat: lat, lng: lng);
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
      (senderNameController.value.trim().isNotEmpty) &&
      (senderPhoneController.value.trim().isNotEmpty) &&
      (receiverNameController.value.trim().isNotEmpty) &&
      (receiverPhoneController.value.trim().isNotEmpty);

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
      final result = await _repository.calculateShippingPrice(
        token: token.value,
        weight: weight,
        length: length,
        width: width,
        height: height,
        pickupLat: pickupLat.value!,
        pickupLng: pickupLng.value!,
        destLat: destLat.value!,
        destLng: destLng.value!,
        paymentMethod: 'cash',
      );
      final data =
          (result['data'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          <String, dynamic>{};
      subtotal.value = _numToDouble(data['subtotal']);
      deliveryFee.value = _numToDouble(data['delivery_fee']);
      total.value = _numToDouble(data['total']);
      distance.value = _numToDouble(data['distance']);
      parcelCategory.value = data['parcel_category']?.toString();
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
      subtotal.value = null;
      deliveryFee.value = null;
      total.value = null;
      distance.value = null;
      parcelCategory.value = null;
    } catch (e) {
      print('[SHIPPING][CALCULATE][ERROR] $e');
      errorMessage.value = 'تعذر حساب سعر الشحن: $e';
      subtotal.value = null;
      deliveryFee.value = null;
      total.value = null;
      distance.value = null;
      parcelCategory.value = null;
    } finally {
      isCalculating.value = false;
    }
  }

  Future<LiveOrderInfo> createShippingOrder() async {
    if (!canConfirmOrder) {
      throw HomeApiException('يرجى تعبئة جميع الحقول المطلوبة');
    }
    isCreatingOrder.value = true;
    try {
      final authToken = token.value;
      if (authToken == null || authToken.trim().isEmpty) {
        throw HomeApiException('يرجى تسجيل الدخول لإكمال الطلب');
      }
      final response = await _repository.createShippingOrder(
        token: authToken,
        weight: _parseDouble(weightController.value)!,
        length: _parseDouble(lengthController.value)!,
        width: _parseDouble(widthController.value)!,
        height: _parseDouble(heightController.value)!,
        pickupLat: pickupLat.value!,
        pickupLng: pickupLng.value!,
        destLat: destLat.value!,
        destLng: destLng.value!,
        senderName: senderNameController.value.trim(),
        senderPhone: senderPhoneController.value.trim(),
        receiverName: receiverNameController.value.trim(),
        receiverPhone: receiverPhoneController.value.trim(),
        paymentMethod: 'cash',
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      final orderId = _asInt(data['id']);
      if (orderId == null) {
        throw HomeApiException('لم يتم استلام رقم طلب الشحن');
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

  Future<void> _resolveAddress({
    required double lat,
    required double lng,
    required bool isPickup,
  }) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng',
    );
    try {
      final response = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'najiz_go_express/1.0',
        },
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final label = (body['display_name'] as String?)?.trim();
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

    final fallback = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    if (isPickup) {
      pickupAddress.value = fallback;
    } else {
      destinationAddress.value = fallback;
    }
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

  bool _isWithinSyria({required double lat, required double lng}) {
    const minLat = 32.0;
    const maxLat = 37.5;
    const minLng = 35.5;
    const maxLng = 42.5;
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
