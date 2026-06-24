import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/widgets/delivery_map_picker_dialog.dart';
import 'package:najiz_go_express/features/orders/services/checkout_places_service.dart';
import 'package:najiz_go_express/features/profile/utils/profile_geocoding.dart';

const _placesService = CheckoutPlacesService();
const _defaultPoint = ll.LatLng(33.5138, 36.2765);

Future<ll.LatLng> resolveDeliveryMapBiasPoint({
  double? lat,
  double? lng,
}) async {
  if (lat != null && lng != null) {
    return ll.LatLng(lat, lng);
  }
  try {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      return ll.LatLng(lastKnown.latitude, lastKnown.longitude);
    }
  } catch (_) {}
  return _defaultPoint;
}

Future<DeliveryMapPickerResult?> showRestaurantDeliveryMapPicker({
  required BuildContext context,
  double? biasLat,
  double? biasLng,
}) async {
  final initial = await resolveDeliveryMapBiasPoint(
    lat: biasLat,
    lng: biasLng,
  );
  if (!context.mounted) return null;
  return showDeliveryMapPicker(
    context: context,
    initialPoint: initial,
    fetchSuggestions: (query) => _placesService.fetchSuggestions(
      query: query,
      biasLat: initial.latitude,
      biasLng: initial.longitude,
    ),
    resolveSuggestion: (placeId, fallback) => _placesService.resolveSuggestion(
      CheckoutPlaceSuggestion(
        placeId: placeId,
        description: fallback,
        primaryText: fallback,
        secondaryText: '',
      ),
    ),
  );
}

Future<String> resolveMapPickerLabel({
  required ll.LatLng point,
  String? pickedLabel,
}) async {
  final trimmed = pickedLabel?.trim() ?? '';
  if (trimmed.isNotEmpty) return trimmed;
  return ProfileGeocoding.reverseGeocode(point);
}
