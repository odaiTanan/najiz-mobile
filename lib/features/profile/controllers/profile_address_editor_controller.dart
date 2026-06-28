import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:najiz_go_express/features/profile/models/address_picker_result.dart';
import 'package:najiz_go_express/features/profile/models/address_place_suggestion.dart';
import 'package:najiz_go_express/features/profile/models/create_address_payload.dart';
import 'package:najiz_go_express/features/profile/profile_maps_config.dart';
import 'package:najiz_go_express/core/utils/address_label_utils.dart';
import 'package:najiz_go_express/features/profile/utils/profile_geocoding.dart';

class AddressEditorFeedback {
  const AddressEditorFeedback({this.success, this.error});

  final String? success;
  final String? error;
}

class ProfileAddressEditorController extends GetxController {
  ProfileAddressEditorController({
    this.initialAddress,
    required this.onSave,
  });

  final String? initialAddress;
  final Future<void> Function(CreateAddressPayload payload) onSave;

  final selectedPoint = const LatLng(33.5138, 36.2765).obs;
  final selectedAddress = RxnString();
  final isSaving = false.obs;
  final isSearching = false.obs;
  final suggestions = <PlaceSuggestion>[].obs;

  Timer? _searchDebounce;

  @override
  void onInit() {
    super.onInit();
    final initial = initialAddress?.trim();
    if (initial != null && initial.isNotEmpty) {
      selectedAddress.value = initial;
    }
    bootstrapLocation();
  }

  @override
  void onClose() {
    _searchDebounce?.cancel();
    super.onClose();
  }

  Future<void> bootstrapLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final current = LatLng(pos.latitude, pos.longitude);
      selectedPoint.value = current;
      if (selectedAddress.value == null) {
        final label = await ProfileGeocoding.reverseGeocode(current);
        selectedAddress.value = label;
      }
    } catch (_) {}
  }

  void onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      if (suggestions.isNotEmpty) {
        suggestions.clear();
      }
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      fetchAutocompleteSuggestions(query);
    });
  }

  Future<void> fetchAutocompleteSuggestions(String query) async {
    if (isSearching.value) return;
    isSearching.value = true;
    try {
      final suggestUrl = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'language': 'ar',
          'components': 'country:sy',
          'key': profileMapsApiKey,
        },
      );
      final suggestRes = await http.get(
        suggestUrl,
        headers: const {'Accept': 'application/json'},
      );
      if (suggestRes.statusCode != 200) {
        suggestions.clear();
        return;
      }
      final suggestBody = jsonDecode(suggestRes.body);
      if (suggestBody is! Map<String, dynamic>) {
        suggestions.clear();
        return;
      }
      final predictions = suggestBody['predictions'];
      if (predictions is! List) {
        suggestions.clear();
        return;
      }
      final nextSuggestions = predictions
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .map(
            (p) => PlaceSuggestion(
              placeId: (p['place_id'] ?? '').toString(),
              description: AddressLabelUtils.format(
                (p['description'] ?? '').toString(),
              ),
            ),
          )
          .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
          .take(6)
          .toList(growable: false);
      suggestions.assignAll(nextSuggestions);
    } catch (_) {
      suggestions.clear();
    } finally {
      isSearching.value = false;
    }
  }

  Future<AddressEditorFeedback> searchByName(String query) async {
    if (query.isEmpty || isSearching.value) {
      return const AddressEditorFeedback();
    }
    isSearching.value = true;
    try {
      final suggestUrl = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'language': 'ar',
          'components': 'country:sy',
          'key': profileMapsApiKey,
        },
      );
      final suggestRes = await http.get(
        suggestUrl,
        headers: const {'Accept': 'application/json'},
      );
      if (suggestRes.statusCode != 200) {
        return AddressEditorFeedback(error: 'address.searchFailed'.tr);
      }
      final suggestBody = jsonDecode(suggestRes.body);
      if (suggestBody is! Map<String, dynamic>) {
        return AddressEditorFeedback(error: 'address.searchReadFailed'.tr);
      }
      final predictions = suggestBody['predictions'];
      if (predictions is! List || predictions.isEmpty) {
        return AddressEditorFeedback(error: 'address.noResultsInSyria'.tr);
      }
      final first = Map<String, dynamic>.from(predictions.first as Map);
      final placeId = (first['place_id'] ?? '').toString().trim();
      if (placeId.isEmpty) {
        return AddressEditorFeedback(error: 'address.locationReadFailed'.tr);
      }
      final detailsResult = await _fetchPlaceDetails(placeId);
      if (detailsResult.error != null) {
        return AddressEditorFeedback(error: detailsResult.error);
      }
      final point = detailsResult.point!;
      selectedPoint.value = point;
      selectedAddress.value = detailsResult.formattedAddress?.isNotEmpty == true
          ? detailsResult.formattedAddress
          : selectedAddress.value;
      return AddressEditorFeedback(success: 'address.locationFound'.tr);
    } catch (_) {
      return AddressEditorFeedback(error: 'address.locationSearchFailed'.tr);
    } finally {
      isSearching.value = false;
    }
  }

  Future<AddressEditorFeedback> selectSuggestion(PlaceSuggestion suggestion) async {
    suggestions.clear();
    isSearching.value = true;
    try {
      final detailsResult = await _fetchPlaceDetails(suggestion.placeId);
      if (detailsResult.error != null) {
        return AddressEditorFeedback(error: detailsResult.error);
      }
      final point = detailsResult.point!;
      selectedPoint.value = point;
      selectedAddress.value = detailsResult.formattedAddress?.isNotEmpty == true
          ? detailsResult.formattedAddress
          : suggestion.description;
      return AddressEditorFeedback(success: 'address.locationSelected'.tr);
    } catch (_) {
      return AddressEditorFeedback(error: 'address.locationSelectFailed'.tr);
    } finally {
      isSearching.value = false;
    }
  }

  void applyMapPickerResult(AddressPickerResult result) {
    selectedPoint.value = result.point;
    selectedAddress.value = result.address;
  }

  String? validateSelectedAddress() {
    if (selectedAddress.value == null || selectedAddress.value!.trim().isEmpty) {
      return 'address.selectFirst'.tr;
    }
    return null;
  }

  CreateAddressPayload buildPayload({
    required String title,
    required String region,
    required String street,
    required String addressDetails,
  }) {
    return CreateAddressPayload(
      title: title.trim(),
      region: region.trim(),
      street: street.trim(),
      addressDetails: addressDetails.trim(),
      details: selectedAddress.value!.trim(),
      lat: selectedPoint.value.latitude,
      lng: selectedPoint.value.longitude,
      isDefault: false,
    );
  }

  Future<void> saveAddress({
    required String title,
    required String region,
    required String street,
    required String addressDetails,
  }) async {
    isSaving.value = true;
    try {
      final payload = buildPayload(
        title: title,
        region: region,
        street: street,
        addressDetails: addressDetails,
      );
      await onSave(payload);
    } finally {
      isSaving.value = false;
    }
  }

  Future<({String? error, LatLng? point, String? formattedAddress})>
      _fetchPlaceDetails(String placeId) async {
    final detailsUrl = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'fields': 'geometry/location,formatted_address',
        'language': 'ar',
        'key': profileMapsApiKey,
      },
    );
    final detailsRes = await http.get(
      detailsUrl,
      headers: const {'Accept': 'application/json'},
    );
    if (detailsRes.statusCode != 200) {
      return (error: 'address.detailsLoadFailed'.tr, point: null, formattedAddress: null);
    }
    final detailsBody = jsonDecode(detailsRes.body);
    if (detailsBody is! Map<String, dynamic>) {
      return (error: 'address.detailsReadFailed'.tr, point: null, formattedAddress: null);
    }
    final result = (detailsBody['result'] is Map)
        ? Map<String, dynamic>.from(detailsBody['result'] as Map)
        : <String, dynamic>{};
    final geometry = (result['geometry'] is Map)
        ? Map<String, dynamic>.from(result['geometry'] as Map)
        : <String, dynamic>{};
    final location = (geometry['location'] is Map)
        ? Map<String, dynamic>.from(geometry['location'] as Map)
        : <String, dynamic>{};
    final lat = double.tryParse(location['lat']?.toString() ?? '');
    final lng = double.tryParse(location['lng']?.toString() ?? '');
    if (lat == null || lng == null) {
      return (error: 'address.locationReadFailed'.tr, point: null, formattedAddress: null);
    }
    final rawFormattedAddress = result['formatted_address']?.toString().trim();
    final formattedAddress =
        rawFormattedAddress == null || rawFormattedAddress.isEmpty
            ? null
            : AddressLabelUtils.format(rawFormattedAddress);
    return (
      error: null,
      point: LatLng(lat, lng),
      formattedAddress: formattedAddress,
    );
  }
}
