import 'package:latlong2/latlong.dart';

class DeliveryEta {
  const DeliveryEta({
    this.minutes,
    this.distanceKm,
    this.deliveryTime,
  });

  final int? minutes;
  final double? distanceKm;
  final String? deliveryTime;
}

class DeliveryEtaHelper {
  static const double _citySpeedKmh = 35;

  static DeliveryEta? parseFromPayload(Map<String, dynamic> payload) {
    final minutes = _asInt(
      payload['estimated_delivery_minutes'] ??
          payload['estimatedDeliveryMinutes'] ??
          payload['eta_minutes'] ??
          payload['etaMinutes'] ??
          payload['delivery_eta_minutes'],
    );
    final distanceKm = _asDouble(
      payload['distance_km'] ??
          payload['distanceKm'] ??
          payload['delivery_distance_km'],
    );
    final deliveryTime = _firstNonEmpty([
      payload['estimated_delivery_time'],
      payload['estimatedDeliveryTime'],
      payload['estimated_time'],
      payload['estimatedTime'],
      payload['delivery_eta_time'],
    ]);

    if (minutes == null && distanceKm == null && deliveryTime == null) {
      return null;
    }

    return DeliveryEta(
      minutes: minutes,
      distanceKm: distanceKm,
      deliveryTime: deliveryTime,
    );
  }

  static DeliveryEta? calculateFromCoordinates({
    required double driverLat,
    required double driverLng,
    required double destinationLat,
    required double destinationLng,
  }) {
    final driver = LatLng(driverLat, driverLng);
    final destination = LatLng(destinationLat, destinationLng);
    final distanceKm = const Distance().as(LengthUnit.Kilometer, driver, destination);
    if (distanceKm <= 0) return null;

    final minutes = ((distanceKm / _citySpeedKmh) * 60).ceil().clamp(1, 180);
    final arrival = DateTime.now().add(Duration(minutes: minutes));
    final deliveryTime =
        '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';

    return DeliveryEta(
      minutes: minutes,
      distanceKm: distanceKm,
      deliveryTime: deliveryTime,
    );
  }

  static DeliveryEta? resolve({
    Map<String, dynamic>? driverPayload,
    double? destinationLat,
    double? destinationLng,
  }) {
    if (driverPayload != null) {
      final parsed = parseFromPayload(driverPayload);
      if (parsed != null &&
          (parsed.minutes != null ||
              parsed.deliveryTime != null ||
              parsed.distanceKm != null)) {
        return parsed;
      }

      final driverLat = _asDouble(driverPayload['current_lat'] ?? driverPayload['lat']);
      final driverLng = _asDouble(driverPayload['current_lng'] ?? driverPayload['lng']);
      if (driverLat != null &&
          driverLng != null &&
          destinationLat != null &&
          destinationLng != null) {
        return calculateFromCoordinates(
          driverLat: driverLat,
          driverLng: driverLng,
          destinationLat: destinationLat,
          destinationLng: destinationLng,
        );
      }
    }

    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String? _firstNonEmpty(List<dynamic> candidates) {
    for (final raw in candidates) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }
}
