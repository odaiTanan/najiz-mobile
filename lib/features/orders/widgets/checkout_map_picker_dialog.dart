import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/widgets/delivery_map_picker_dialog.dart';
import 'package:najiz_go_express/features/orders/controllers/order_checkout_controller.dart';

export 'package:najiz_go_express/core/widgets/delivery_map_picker_dialog.dart'
    show DeliveryMapPickerResult, showDeliveryMapPicker;

typedef CheckoutMapPickerResult = DeliveryMapPickerResult;

Future<DeliveryMapPickerResult?> showCheckoutMapPicker({
  required BuildContext context,
  required OrderCheckoutController controller,
}) {
  final lat = double.tryParse(controller.lat.value) ?? 33.5138;
  final lng = double.tryParse(controller.lng.value) ?? 36.2765;
  return showDeliveryMapPicker(
    context: context,
    initialPoint: ll.LatLng(lat, lng),
    fetchSuggestions: (query) =>
        controller.fetchLocationSuggestions(query: query),
    resolveSuggestion: (placeId, fallback) =>
        controller.resolveLocationSuggestion(
          placeId: placeId,
          fallbackDescription: fallback,
        ),
  );
}
