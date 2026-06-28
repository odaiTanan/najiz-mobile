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
    final parsedMinutes = _asInt(
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
    final deliveryTimeRaw = _firstNonEmpty([
      payload['estimated_delivery_time'],
      payload['estimatedDeliveryTime'],
      payload['estimated_time'],
      payload['estimatedTime'],
      payload['delivery_eta_time'],
    ]);
    final minutesFromTimeField = _asInt(deliveryTimeRaw);
    final minutes = parsedMinutes ?? minutesFromTimeField;
    final deliveryTime = _normalizeClockTime(deliveryTimeRaw);

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
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    if (raw.contains(':')) return null;
    final direct = int.tryParse(raw);
    if (direct != null) return direct;
    final match = RegExp(r'\d+').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
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

  static String? _normalizeClockTime(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (!value.contains(':')) return null;
    return value;
  }
}
