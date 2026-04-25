import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/checkout_cart_item.dart';
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
  }

  final isLoading = false.obs;
  final isPlacingOrder = false.obs;
  final errorMessage = RxnString();
  final hasCalculatedPricing = false.obs;

  final lat = '33.5138'.obs;
  final lng = '36.2765'.obs;
  final customAddressName = 'جاري تحديد موقعك...'.obs;
  final paymentMethod = 'cash';
  final notes = 'كترلنا حد';

  final subtotal = 0.0.obs;
  final deliveryFee = 0.0.obs;
  final serviceFee = 0.0.obs;
  final total = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    _initUserLocationAndCalculate();
  }

  List<Map<String, dynamic>> get apiItems => items
      .map((e) => {'product_id': e.productId, 'quantity': e.quantity})
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
        customAddressName.value = 'الموقع غير متاح، يمكنك اختياره من الخريطة';
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
      customAddressName.value = 'تعذر تحديد الموقع تلقائيا';
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
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$latitude&lon=$longitude',
    );
    try {
      final res = await http.get(
        url,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'najiz_go_express/1.0',
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final label = (body['display_name'] as String?)?.trim();
        if (label != null && label.isNotEmpty) return label;
      }
    } catch (_) {}
    return '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';
  }

  Future<void> calculate() async {
    errorMessage.value = null;
    isLoading.value = true;
    hasCalculatedPricing.value = false;
    final currentLat = double.tryParse(lat.value);
    final currentLng = double.tryParse(lng.value);
    if (currentLat == null ||
        currentLng == null ||
        !_isWithinSyria(lat: currentLat, lng: currentLng)) {
      errorMessage.value = 'يرجى اختيار عنوان داخل سوريا لحساب السعر';
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
        notes: notes,
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};

      subtotal.value = _asDouble(data['subtotal']);
      deliveryFee.value = _asDouble(data['delivery_fee']);
      total.value = _asDouble(data['total']);
      final computedService = total.value - subtotal.value - deliveryFee.value;
      serviceFee.value = computedService < 0 ? 0 : computedService;
      hasCalculatedPricing.value = true;
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'فشل حساب الفاتورة';
    } finally {
      isLoading.value = false;
    }
  }

  Future<PlacedOrderInfo> placeOrder() async {
    isPlacingOrder.value = true;
    try {
      final authToken = token.value;
      if (authToken == null || authToken.trim().isEmpty) {
        throw HomeApiException('يرجى تسجيل الدخول لإكمال الطلب');
      }
      final response = await _repository.createOrder(
        token: authToken,
        vendorId: vendorId,
        lat: lat.value,
        lng: lng.value,
        customAddressName: customAddressName.value,
        paymentMethod: paymentMethod,
        items: apiItems,
        notes: notes,
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      final orderId = _asInt(data['id']);
      if (orderId == null) {
        throw HomeApiException('لم يتم استلام رقم الطلب من الخادم');
      }
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
