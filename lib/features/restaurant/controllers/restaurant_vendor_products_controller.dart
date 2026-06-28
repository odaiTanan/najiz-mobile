import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/features/restaurant/errors/restaurant_api_exception.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_products_model.dart';
import 'package:najiz_go_express/features/restaurant/repositories/restaurant_repository.dart';
import 'dart:convert';
import 'dart:math' as math;

class RestaurantVendorProductsController extends GetxController {
  RestaurantVendorProductsController({
    required this.token,
    required this.vendorId,
    this.serviceId,
    this.customerLat,
    this.customerLng,
    this.vendorLatHint,
    this.vendorLngHint,
    RestaurantRepository? repository,
  }) : _repository = repository ?? RestaurantRepository();

  final String? token;
  final int vendorId;
  final int? serviceId;
  final double? customerLat;
  final double? customerLng;
  final double? vendorLatHint;
  final double? vendorLngHint;
  final RestaurantRepository _repository;
  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final estimatedEtaMinutes = RxnInt();
  final isEstimatingEta = false.obs;

  final vendorProducts = Rxn<VendorProductsModel>();
  final selectedCategoryId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool gateRetry = false}) async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      vendorProducts.value = await _repository.getVendorProducts(
        token: token,
        vendorId: vendorId,
      );
      selectedCategoryId.value = null; // Default "All"
      _estimateDeliveryEtaMinutes();
    } on RestaurantApiException catch (e) {
      if (gateRetry) {
        rethrow;
      }
      if (e.isConnectivityIssue) {
        showNoInternetGateIfNeededFeature(
          e,
          retry: () => load(gateRetry: true),
        );
        errorMessage.value = null;
        vendorProducts.value = null;
      } else {
        errorMessage.value = e.message;
        vendorProducts.value = null;
      }
    } catch (_) {
      if (gateRetry) {
        rethrow;
      }
      errorMessage.value = 'فشل تحميل المنيو';
      vendorProducts.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  String etaMinutesText({String? fallbackText}) {
    final minutes = estimatedEtaMinutes.value;
    if (minutes != null && minutes > 0) {
      return _etaRangeText(minutes);
    }
    final fallback = fallbackText?.trim();
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }
    return '--';
  }

  Future<void> _estimateDeliveryEtaMinutes() async {
    final customerPoint = await _resolveCustomerCoordinates();
    final destinationLat = customerPoint?.lat;
    final destinationLng = customerPoint?.lng;
    final vendor = vendorProducts.value?.vendor;
    final sourceLat = vendor?.latitude ?? vendorLatHint;
    final sourceLng = vendor?.longitude ?? vendorLngHint;
    if (destinationLat == null ||
        destinationLng == null ||
        sourceLat == null ||
        sourceLng == null) {
      return;
    }

    isEstimatingEta.value = true;
    try {
      final haversineKm = _haversineDistanceKm(
        sourceLat: sourceLat,
        sourceLng: sourceLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );
      final baseEta = _estimateFromHaversine(haversineKm);
      // Show ETA immediately from Haversine so UI does not wait on network.
      estimatedEtaMinutes.value = baseEta.clamp(5, 180);

      final googleDrivingMinutes = await _fetchGoogleDrivingMinutes(
        sourceLat: sourceLat,
        sourceLng: sourceLng,
        destinationLat: destinationLat,
        destinationLng: destinationLng,
      );
      if (googleDrivingMinutes != null) {
        final bufferedGoogle = googleDrivingMinutes + _serviceBufferMinutes;
        final refinedEta = ((baseEta + bufferedGoogle) / 2).round();
        estimatedEtaMinutes.value = refinedEta.clamp(5, 180);
      }
    } catch (_) {
      // Keep backend fallback ETA when estimation fails.
    } finally {
      isEstimatingEta.value = false;
    }
  }

  Future<({double lat, double lng})?> _resolveCustomerCoordinates() async {
    if (customerLat != null && customerLng != null) {
      return (lat: customerLat!, lng: customerLng!);
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  int get _serviceBufferMinutes {
    if (serviceId == 3) return 5; // Stores
    return 8; // Restaurants default
  }

  int _estimateFromHaversine(double km) {
    final normalizedKm = km.isFinite ? km : 0;
    final effectiveKm = normalizedKm <= 0 ? 0.2 : normalizedKm;
    final speedKmh = (serviceId == 3) ? 24.0 : 20.0;
    final drivingMinutes = (effectiveKm / speedKmh) * 60.0;
    final totalMinutes = drivingMinutes + _serviceBufferMinutes;
    return totalMinutes.ceil();
  }

  String _etaRangeText(int minutes) {
    final spread = minutes <= 18
        ? 4
        : (minutes <= 35 ? 6 : 8);
    final minMinutes = math.max(5, minutes - spread);
    final maxMinutes = minutes + spread;
    return '$minMinutes-$maxMinutes';
  }

  Future<int?> _fetchGoogleDrivingMinutes({
    required double sourceLat,
    required double sourceLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    if (_mapsApiKey.trim().isEmpty) return null;
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/distancematrix/json',
        {
          'origins': '$sourceLat,$sourceLng',
          'destinations': '$destinationLat,$destinationLng',
          'mode': 'driving',
          'language': Get.locale?.languageCode ?? 'ar',
          'key': _mapsApiKey,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final rows = body['rows'];
      if (rows is! List || rows.isEmpty) return null;
      final firstRow = rows.first;
      if (firstRow is! Map<String, dynamic>) return null;
      final elements = firstRow['elements'];
      if (elements is! List || elements.isEmpty) return null;
      final firstElement = elements.first;
      if (firstElement is! Map<String, dynamic>) return null;
      if ((firstElement['status']?.toString() ?? 'OK') != 'OK') return null;

      final durationInTraffic = firstElement['duration_in_traffic'];
      final duration = firstElement['duration'];
      final durationMap = durationInTraffic is Map<String, dynamic>
          ? durationInTraffic
          : (duration is Map<String, dynamic> ? duration : null);
      final secondsRaw = durationMap?['value'];
      final seconds = secondsRaw is num
          ? secondsRaw.toDouble()
          : double.tryParse(secondsRaw?.toString() ?? '');
      if (seconds == null || seconds <= 0) return null;
      return (seconds / 60.0).ceil();
    } catch (_) {
      return null;
    }
  }

  double _haversineDistanceKm({
    required double sourceLat,
    required double sourceLng,
    required double destinationLat,
    required double destinationLng,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(destinationLat - sourceLat);
    final dLng = _degToRad(destinationLng - sourceLng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_degToRad(sourceLat)) *
            math.cos(_degToRad(destinationLat)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.atan2(math.sqrt(a.toDouble()), math.sqrt(1 - a.toDouble()));
    return earthRadiusKm * c;
  }

  double _degToRad(double value) => value * (math.pi / 180.0);

  void selectCategory(int? categoryId) {
    selectedCategoryId.value = categoryId;
  }

  List<VendorProductsCategory> get regularCategories {
    final data = vendorProducts.value;
    if (data == null) return const [];
    return data.categories
        .where((category) => category.type == 'regular')
        .toList(growable: false);
  }

  List<VendorProductItem> get filteredRegularProducts {
    final data = vendorProducts.value;
    if (data == null) return const [];

    final regularCategoryIds = regularCategories.map((c) => c.id).toSet();
    final regularProducts = data.products.where((product) {
      final byCategoryId = product.categoryId != null &&
          regularCategoryIds.contains(product.categoryId);
      final byInlineCategoryType = product.categoryType == 'regular';
      return byCategoryId || byInlineCategoryType;
    });

    final categoryId = selectedCategoryId.value;
    if (categoryId == null) return regularProducts.toList(growable: false);

    return regularProducts
        .where((product) => product.categoryId == categoryId)
        .toList(growable: false);
  }

  List<VendorProductItem> get offerProducts {
    final data = vendorProducts.value;
    if (data == null) return const [];

    final offerCategoryIds = data.categories
        .where((category) => category.type == 'offers')
        .map((category) => category.id)
        .toSet();

    return data.products.where((product) {
      final byCategoryId = product.categoryId != null &&
          offerCategoryIds.contains(product.categoryId);
      final byInlineCategoryType = product.categoryType == 'offers';
      return byCategoryId || byInlineCategoryType;
    }).toList(growable: false);
  }

  List<VendorProductItem> get filteredProducts {
    final regular = filteredRegularProducts;
    final offers = offerProducts;
    return [...regular, ...offers];
  }
}

