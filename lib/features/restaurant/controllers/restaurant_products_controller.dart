import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:najiz_go_express/features/restaurant/errors/restaurant_api_exception.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/features/restaurant/models/classification_model.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_model.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/features/profile/models/create_address_payload.dart';
import 'package:najiz_go_express/features/profile/models/user_address.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';
import 'package:najiz_go_express/core/utils/address_label_utils.dart';
import 'package:najiz_go_express/features/restaurant/repositories/restaurant_repository.dart';
import 'package:najiz_go_express/features/restaurant/views/restaurant_vendor_products_screen.dart';
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
    RestaurantRepository? restaurantRepository,
    ProfileRepository? profileRepository,
  })  : _restaurantRepository = restaurantRepository ?? RestaurantRepository(),
        _profileRepository = profileRepository ?? ProfileRepository();

  final String? token;
  final int serviceId;
  final RestaurantRepository _restaurantRepository;
  final ProfileRepository _profileRepository;

  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final errorMessage = RxnString();
  final currentPage = 1.obs;
  final lastPage = 1.obs;

  final classifications = <ClassificationModel>[].obs;
  final selectedClassificationId = RxnInt();
  final selectedStatusFilter = VendorStatusFilter.all.obs;

  final allVendors = <VendorModel>[].obs;
  final vendors = <VendorModel>[].obs;
  final savedAddresses = <UserAddress>[].obs;
  final selectedAddressId = RxnInt();
  final isMapPickedLocation = false.obs;
  final selectedVendorId = RxnInt();
  final selectedDeliveryLat = RxnDouble();
  final selectedDeliveryLng = RxnDouble();
  late final currentDeliveryAddress = ''.obs;
  final isResolvingAddress = false.obs;
  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );

  bool get hasMoreVendors => currentPage.value < lastPage.value;

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

  Future<void> loadDeliveryAddress({bool forceRefresh = false}) async {
    final authToken = token?.trim() ?? '';
    if (authToken.isNotEmpty) {
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
        if (sorted.isNotEmpty) {
          final preferred = sorted.firstWhere(
            (a) => a.isDefault && a.lat != null && a.lng != null,
            orElse: () => sorted.firstWhere(
              (a) => a.lat != null && a.lng != null,
              orElse: () => sorted.first,
            ),
          );
          selectedAddressId.value = preferred.id;
          selectedDeliveryLat.value = preferred.lat;
          selectedDeliveryLng.value = preferred.lng;
          currentDeliveryAddress.value = preferred.toShortLabel();
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
    isMapPickedLocation.value = false;
    selectedDeliveryLat.value = address.lat;
    selectedDeliveryLng.value = address.lng;
    currentDeliveryAddress.value = address.toShortLabel();
  }

  Future<void> useCurrentLocationAddress() async {
    selectedAddressId.value = null;
    isMapPickedLocation.value = false;
    selectedDeliveryLat.value = null;
    selectedDeliveryLng.value = null;
    await loadCurrentDeliveryAddress();
  }

  void applyMapPickedLocation({
    required double lat,
    required double lng,
    required String label,
  }) {
    selectedAddressId.value = null;
    isMapPickedLocation.value = true;
    selectedDeliveryLat.value = lat;
    selectedDeliveryLng.value = lng;
    final trimmed = label.trim();
    currentDeliveryAddress.value = trimmed.isNotEmpty
        ? trimmed
        : '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> addAddress(CreateAddressPayload payload) async {
    final authToken = token?.trim() ?? '';
    if (authToken.isEmpty) {
      throw RestaurantApiException('location.loginForAddress'.tr);
    }
    await _profileRepository.addUserAddress(token: authToken, payload: payload.toJson());
    await loadDeliveryAddress(forceRefresh: true);
  }

  Future<void> load({bool gateRetry = false}) async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      final loadedClassifications = await _restaurantRepository
          .getClassificationsByService(token: token, serviceId: serviceId);

      classifications.assignAll(loadedClassifications);

      // Default "All" tab.
      selectedClassificationId.value = null;

      await _loadVendorsPage(reset: true);
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
      errorMessage.value = 'location.restaurantsFailed'.tr;
      classifications.clear();
      allVendors.clear();
      vendors.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadVendorsPage({required bool reset}) async {
    if (reset) {
      currentPage.value = 1;
      lastPage.value = 1;
      allVendors.clear();
      vendors.clear();
    } else {
      if (isLoadingMore.value || !hasMoreVendors) return;
      isLoadingMore.value = true;
    }

    final page = reset ? 1 : currentPage.value + 1;

    try {
      final result = await _restaurantRepository.getVendorsByService(
        token: token,
        serviceId: serviceId,
        page: page,
        classificationId: selectedClassificationId.value,
      );
      final sorted = _sortVendors(result.items);
      if (reset) {
        allVendors.assignAll(sorted);
      } else {
        allVendors.addAll(sorted);
      }
      currentPage.value = result.currentPage;
      lastPage.value = result.lastPage;
      _applyClassificationFilter();
    } finally {
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMoreVendorsIfNeeded() {
    return _loadVendorsPage(reset: false);
  }

  Future<void> selectClassification(int? classificationId) async {
    selectedClassificationId.value = classificationId;
    errorMessage.value = null;
    try {
      await _loadVendorsPage(reset: true);
    } on RestaurantApiException catch (e) {
      errorMessage.value = e.message;
      allVendors.clear();
      vendors.clear();
    } catch (_) {
      errorMessage.value = 'location.restaurantsFailed'.tr;
      allVendors.clear();
      vendors.clear();
    }
  }

  void selectStatusFilter(VendorStatusFilter filter) {
    selectedStatusFilter.value = filter;
    _applyClassificationFilter();
  }

  Future<void> openVendorProducts(VendorModel vendor) async {
    selectedVendorId.value = vendor.id;
    await Get.to(
      () => RestaurantVendorProductsScreen(
        token: token,
        vendorId: vendor.id,
        serviceId: serviceId,
        customerLat: selectedDeliveryLat.value,
        customerLng: selectedDeliveryLng.value,
        vendorLatHint: vendor.latitude,
        vendorLngHint: vendor.longitude,
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
        currentDeliveryAddress.value = 'location.enableService'.tr;
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        currentDeliveryAddress.value = 'location.allowPermission'.tr;
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        currentDeliveryAddress.value = 'location.permissionDeniedForever'.tr;
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      selectedDeliveryLat.value = position.latitude;
      selectedDeliveryLng.value = position.longitude;

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
      selectedDeliveryLat.value = null;
      selectedDeliveryLng.value = null;
      currentDeliveryAddress.value = 'location.geoFailed'.tr;
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
          if (parts.isNotEmpty) return AddressLabelUtils.joinParts(parts);
        }

        final formatted = (map['formatted_address'] ?? '').toString().trim();
        if (formatted.isNotEmpty && !_looksLikeCoordinates(formatted)) {
          return AddressLabelUtils.format(formatted);
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
      if (parts.isNotEmpty) return AddressLabelUtils.joinParts(parts);
    } catch (_) {}
    return null;
  }
}
