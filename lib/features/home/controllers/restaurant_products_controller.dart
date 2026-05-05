import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/data/models/classification_model.dart';
import 'package:najiz_go_express/data/models/vendor_model.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/create_address_payload.dart';
import 'package:najiz_go_express/features/home/models/user_address.dart';
import 'package:najiz_go_express/features/home/views/restaurant_vendor_products_screen.dart';
import 'dart:convert';

enum VendorStatusFilter {
  all,
  active,
  inactive,
  freeDelivery,
  topRated,
}

class RestaurantProductsController extends GetxController {
  RestaurantProductsController({
    required this.token,
    required this.serviceId,
    HomeRepository? repository,
  }) : _repository = repository ?? HomeRepository();

  final String? token;
  final int serviceId;
  final HomeRepository _repository;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  final classifications = <ClassificationModel>[].obs;
  final selectedClassificationId = RxnInt();
  final selectedStatusFilter = VendorStatusFilter.all.obs;

  final allVendors = <VendorModel>[].obs;
  final vendors = <VendorModel>[].obs;
  final savedAddresses = <UserAddress>[].obs;
  final selectedAddressId = RxnInt();
  final selectedVendorId = RxnInt();
  final currentDeliveryAddress = 'جاري تحديد موقعك...'.obs;
  final isResolvingAddress = false.obs;
  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );

  String get deliveryAddressLabel {
    final selectedId = selectedAddressId.value;
    if (selectedId != null) {
      for (final address in savedAddresses) {
        if (address.id == selectedId) return address.toShortLabel();
      }
    }
    return currentDeliveryAddress.value;
  }

  @override
  void onInit() {
    super.onInit();
    load();
    loadDeliveryAddress();
  }

  Future<void> loadDeliveryAddress() async {
    final authToken = token?.trim() ?? '';
    if (authToken.isNotEmpty) {
      try {
        final addresses = await _repository.getMyAddresses(token: authToken);
        final sorted = [...addresses];
        sorted.sort((a, b) {
          final ad = DateTime.tryParse(a.updatedAt ?? a.createdAt ?? '');
          final bd = DateTime.tryParse(b.updatedAt ?? b.createdAt ?? '');
          if (ad == null && bd == null) return b.id.compareTo(a.id);
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
        savedAddresses.assignAll(sorted);
        if (sorted.isNotEmpty) {
          final latest = sorted.first;
          selectedAddressId.value = latest.id;
          currentDeliveryAddress.value = latest.toShortLabel();
          return;
        }
      } catch (_) {
        // Fall back to current location if loading saved addresses fails.
      }
    }
    await loadCurrentDeliveryAddress();
  }

  void selectSavedAddress(UserAddress address) {
    selectedAddressId.value = address.id;
    currentDeliveryAddress.value = address.toShortLabel();
  }

  Future<void> useCurrentLocationAddress() async {
    selectedAddressId.value = null;
    await loadCurrentDeliveryAddress();
  }

  Future<void> addAddress(CreateAddressPayload payload) async {
    final authToken = token?.trim() ?? '';
    if (authToken.isEmpty) {
      throw HomeApiException('يرجى تسجيل الدخول لإضافة عنوان جديد');
    }
    await _repository.addUserAddress(token: authToken, payload: payload.toJson());
    await loadDeliveryAddress();
  }

  Future<void> load({bool gateRetry = false}) async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      final loadedClassifications = await _repository
          .getClassificationsByService(token: token, serviceId: serviceId);

      classifications.assignAll(loadedClassifications);

      // Default "All" tab.
      selectedClassificationId.value = null;

      await _loadVendorsFromRepository();
      _applyClassificationFilter();
    } on HomeApiException catch (e) {
      if (gateRetry) {
        rethrow;
      }
      if (e.isConnectivityIssue) {
        showNoInternetGateIfNeeded(
          e,
          retry: () => load(gateRetry: true),
        );
        errorMessage.value = null;
        classifications.clear();
        allVendors.clear();
        vendors.clear();
      } else {
        errorMessage.value = e.message;
        classifications.clear();
        allVendors.clear();
        vendors.clear();
      }
    } catch (_) {
      if (gateRetry) {
        rethrow;
      }
      errorMessage.value = 'فشل تحميل المطاعم';
      classifications.clear();
      allVendors.clear();
      vendors.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadVendorsFromRepository() async {
    final loaded = await _repository.getVendorsByService(
      token: token,
      serviceId: serviceId,
    );
    final sorted = _sortVendors(loaded);
    allVendors.assignAll(sorted);
  }

  Future<void> selectClassification(int? classificationId) async {
    selectedClassificationId.value = classificationId;
    _applyClassificationFilter();
  }

  void selectStatusFilter(VendorStatusFilter filter) {
    selectedStatusFilter.value = filter;
    _applyClassificationFilter();
  }

  Future<void> openVendorProducts(int vendorId) async {
    selectedVendorId.value = vendorId;
    await Get.to(
      () => RestaurantVendorProductsScreen(
        token: token,
        vendorId: vendorId,
        serviceId: serviceId,
      ),
    );
  }

  List<VendorModel> _sortVendors(List<VendorModel> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final ar = a.rating ?? -1;
      final br = b.rating ?? -1;
      final byRating = br.compareTo(ar);
      if (byRating != 0) return byRating;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  void _applyClassificationFilter() {
    final selectedClassification = selectedClassificationId.value;
    final selectedStatus = selectedStatusFilter.value;

    final filtered = allVendors.where((vendor) {
      final matchesClassification =
          selectedClassification == null ||
          vendor.classificationId == selectedClassification;
      final matchesStatus = switch (selectedStatus) {
        VendorStatusFilter.all => true,
        VendorStatusFilter.active => vendor.isActive,
        VendorStatusFilter.inactive => !vendor.isActive,
        VendorStatusFilter.freeDelivery => _hasFreeDelivery(vendor),
        VendorStatusFilter.topRated => true,
      };
      return matchesClassification && matchesStatus;
    }).toList();

    if (selectedStatus == VendorStatusFilter.topRated) {
      filtered.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
    }

    vendors.assignAll(filtered);
    selectedVendorId.value = vendors.isNotEmpty ? vendors.first.id : null;
  }

  bool _hasFreeDelivery(VendorModel vendor) {
    final text = '${vendor.name} ${vendor.description ?? ''}'.toLowerCase();
    return text.contains('توصيل مجاني') ||
        text.contains('free delivery') ||
        text.contains('مجاني');
  }

  Future<void> loadCurrentDeliveryAddress() async {
    if (isResolvingAddress.value) return;
    isResolvingAddress.value = true;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        currentDeliveryAddress.value = 'فعّل خدمة الموقع لعرض العنوان الحالي';
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        currentDeliveryAddress.value = 'يلزم السماح بالموقع لعرض العنوان';
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        currentDeliveryAddress.value = 'صلاحية الموقع مرفوضة نهائيا';
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final resolved = await _resolveAddressFromGoogle(
        position.latitude,
        position.longitude,
      );
      if (resolved != null && resolved.isNotEmpty) {
        currentDeliveryAddress.value = resolved;
        return;
      }
      final fallback = await _resolveAddressFromPlacemark(
        position.latitude,
        position.longitude,
      );
      currentDeliveryAddress.value =
          fallback ??
          '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
    } catch (_) {
      currentDeliveryAddress.value = 'تعذر تحديد الموقع الحالي';
    } finally {
      isResolvingAddress.value = false;
    }
  }

  Future<String?> _resolveAddressFromGoogle(double lat, double lng) async {
    if (_mapsApiKey.trim().isEmpty) return null;
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
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
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
          if (parts.isNotEmpty) return parts.join('، ');
        }

        final formatted = (map['formatted_address'] ?? '').toString().trim();
        if (formatted.isNotEmpty && !_looksLikeCoordinates(formatted)) {
          return formatted;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeCoordinates(String input) {
    final text = input.trim();
    return RegExp(r'^\s*-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?\s*$').hasMatch(text);
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
      if (parts.isNotEmpty) return parts.join('، ');
    } catch (_) {}
    return null;
  }
}
