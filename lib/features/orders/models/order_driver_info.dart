import 'package:najiz_go_express/core/utils/delivery_eta_helper.dart';
import 'package:najiz_go_express/core/utils/media_url_resolver.dart';

class OrderDriverInfo {
  const OrderDriverInfo({
    this.name,
    this.phone,
    this.vehicleType,
    this.plate,
    this.rating,
    this.deliveryCode,
    this.avatarUrl,
    this.currentLat,
    this.currentLng,
    required this.rawPayload,
  });

  final String? name;
  final String? phone;
  final String? vehicleType;
  final String? plate;
  final String? rating;
  final String? deliveryCode;
  final String? avatarUrl;
  final double? currentLat;
  final double? currentLng;
  final Map<String, dynamic> rawPayload;

  bool get isEmpty =>
      rawPayload.isEmpty &&
      name == null &&
      phone == null &&
      avatarUrl == null &&
      currentLat == null &&
      currentLng == null;

  bool get hasDisplayableData =>
      (name != null && name!.isNotEmpty) ||
      (avatarUrl != null && avatarUrl!.isNotEmpty) ||
      (vehicleType != null && vehicleType!.isNotEmpty) ||
      (plate != null && plate!.isNotEmpty) ||
      (phone != null && phone!.isNotEmpty);

  OrderDriverInfo mergedWith(OrderDriverInfo other) {
    return OrderDriverInfo(
      name: other.name ?? name,
      phone: other.phone ?? phone,
      vehicleType: other.vehicleType ?? vehicleType,
      plate: other.plate ?? plate,
      rating: other.rating ?? rating,
      deliveryCode: other.deliveryCode ?? deliveryCode,
      avatarUrl: other.avatarUrl ?? avatarUrl,
      currentLat: other.currentLat ?? currentLat,
      currentLng: other.currentLng ?? currentLng,
      rawPayload: {...rawPayload, ...other.rawPayload},
    );
  }

  factory OrderDriverInfo.fromPayload(Map<String, dynamic> payload) {
    final deliveryMan = _asMap(payload['delivery_man'] ?? payload['deliveryMan']);
    final driverUser = _resolveDriverUser(payload, deliveryMan);

    final lat = _asDouble(
      payload['current_lat'] ??
          payload['driver_lat'] ??
          payload['driverLat'] ??
          deliveryMan?['current_lat'] ??
          deliveryMan?['lat'],
    );
    final lng = _asDouble(
      payload['current_lng'] ??
          payload['driver_lng'] ??
          payload['driverLng'] ??
          deliveryMan?['current_lng'] ??
          deliveryMan?['lng'],
    );

    return OrderDriverInfo(
      name: _firstNonEmpty([
        payload['driver_name'],
        payload['name'],
        driverUser?['name'],
        driverUser?['full_name'],
        driverUser?['username'],
        deliveryMan?['name'],
        deliveryMan?['full_name'],
        deliveryMan?['driver_name'],
        payload['delivery_man_name'],
        payload['captain_name'],
        payload['deliveryManName'],
      ]),
      phone: _firstNonEmpty([
        payload['driver_phone'],
        payload['phone'],
        driverUser?['phone'],
        driverUser?['mobile'],
        deliveryMan?['phone'],
        deliveryMan?['mobile'],
      ]),
      vehicleType: _firstNonEmpty([
        payload['vehicle_type'],
        payload['vehicle'],
        deliveryMan?['vehicle_type'],
        deliveryMan?['vehicleType'],
        deliveryMan?['vehicle'],
      ]),
      plate: _firstNonEmpty([
        payload['license_plate'],
        payload['plate_number'],
        payload['plate'],
        deliveryMan?['license_plate'],
        deliveryMan?['plate_number'],
        deliveryMan?['plate'],
      ]),
      rating: _firstNonEmpty([
        payload['rating'],
        payload['rate'],
        deliveryMan?['rating'],
        deliveryMan?['rate'],
      ]),
      deliveryCode: _firstNonEmpty([
        payload['delivery_code'],
        payload['deliveryCode'],
        _asMap(payload['shipping_order'] ?? payload['shippingOrder'])?['delivery_code'],
        _asMap(payload['shipping_order'] ?? payload['shippingOrder'])?['deliveryCode'],
      ]),
      avatarUrl: MediaUrlResolver.pickAvatar(
        payload: payload,
        deliveryMan: deliveryMan,
        driverUser: driverUser,
      ),
      currentLat: lat,
      currentLng: lng,
      rawPayload: payload,
    );
  }

  DeliveryEta? resolveEta({
    double? destinationLat,
    double? destinationLng,
  }) {
    return DeliveryEtaHelper.resolve(
      driverPayload: rawPayload,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
    );
  }

  static Map<String, dynamic>? _resolveDriverUser(
    Map<String, dynamic> payload,
    Map<String, dynamic>? deliveryMan,
  ) {
    if (deliveryMan != null) {
      return _asMap(
        deliveryMan['user'] ??
            deliveryMan['driver_user'] ??
            deliveryMan['driverUser'] ??
            deliveryMan['account'],
      );
    }
    return _asMap(
      payload['user'] ??
          payload['delivery_man_user'] ??
          payload['driver_user'] ??
          payload['deliveryManUser'],
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
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
