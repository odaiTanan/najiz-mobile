import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/data/models/taxi_pricing_model.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/live_order_info.dart';
import 'dart:convert';

class TaxiBookingController extends GetxController {
  TaxiBookingController({
    String? token,
    HomeRepository? repository,
  }) : token = RxnString(token),
       _repository = repository ?? HomeRepository();

  final RxnString token;
  final HomeRepository _repository;
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
  final pickupAddress = 'جاري تحديد موقعك...'.obs;
  final dropoffAddress = RxnString();
  final selectingPickupOnMap = true.obs;

  final pricing = Rxn<TaxiPricingModel>();
  final selectedCategoryId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
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
        lat: pickupLat.value,
        lng: pickupLng.value,
        isPickup: true,
      );
    } catch (_) {
      pickupAddress.value = 'تعذر تحديد الموقع الحالي';
    }
  }

  Future<void> calculatePrices() async {
    if (dropoffLat.value == null || dropoffLng.value == null) {
      errorMessage.value = 'يرجى تحديد الوجهة من الخريطة';
      pricing.value = null;
      return;
    }

    errorMessage.value = null;
    isLoading.value = true;
    try {
      final result = await _repository.calculateTaxiPrice(
        token: token.value,
        pickupLat: pickupLat.value,
        pickupLng: pickupLng.value,
        dropoffLat: dropoffLat.value!,
        dropoffLng: dropoffLng.value!,
      );
      pricing.value = result;
      if (result.categories.isNotEmpty) {
        selectedCategoryId.value = result.categories.first.vehicleCategory.id;
      } else {
        selectedCategoryId.value = null;
      }
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'فشل حساب أسعار التاكسي';
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
      errorMessage.value = 'الاختيار خارج حدود سوريا';
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
      if (response.statusCode != 200) {
        errorMessage.value = 'تعذر تنفيذ البحث';
        return false;
      }
      final results = jsonDecode(response.body);
      if (results is! List || results.isEmpty) {
        errorMessage.value = 'لا توجد نتائج داخل سوريا';
        return false;
      }
      final first = results.first as Map<String, dynamic>;
      final lat = double.tryParse(first['lat']?.toString() ?? '');
      final lng = double.tryParse(first['lon']?.toString() ?? '');
      if (lat == null || lng == null || !_isWithinSyria(lat: lat, lng: lng)) {
        errorMessage.value = 'النتيجة خارج سوريا';
        return false;
      }
      selectingPickupOnMap.value = asPickup;
      errorMessage.value = null;
      if (asPickup) {
        await updatePickup(lat: lat, lng: lng);
      } else {
        await updateDropoff(lat: lat, lng: lng);
      }
      return true;
    } catch (_) {
      errorMessage.value = 'فشل البحث عن الموقع';
      return false;
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
            dropoffAddress.value = label;
          }
          return;
        }
      }
    } catch (_) {}

    final fallback = '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
    if (isPickup) {
      pickupAddress.value = fallback;
    } else {
      dropoffAddress.value = fallback;
    }
  }

  void selectCategory(int id) {
    selectedCategoryId.value = id;
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
      throw HomeApiException('يرجى اختيار فئة تاكسي');
    }
    if (dropoffLat.value == null || dropoffLng.value == null) {
      throw HomeApiException('يرجى تحديد الوجهة من الخريطة');
    }

    isPlacingOrder.value = true;
    try {
      final authToken = token.value;
      if (authToken == null || authToken.trim().isEmpty) {
        throw HomeApiException('يرجى تسجيل الدخول لإكمال الطلب');
      }
      final response = await _repository.createTaxiOrder(
        token: authToken,
        vehicleCategoryId: selected.vehicleCategory.id,
        pickupLat: pickupLat.value,
        pickupLng: pickupLng.value,
        dropoffLat: dropoffLat.value!,
        dropoffLng: dropoffLng.value!,
        paymentMethod: 'cash',
      );
      final data = (response['data'] is Map)
          ? Map<String, dynamic>.from(response['data'] as Map)
          : <String, dynamic>{};
      final orderId = _asInt(data['id']);
      if (orderId == null) {
        throw HomeApiException('لم يتم استلام رقم طلب التاكسي');
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
      );
    } finally {
      isPlacingOrder.value = false;
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

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

