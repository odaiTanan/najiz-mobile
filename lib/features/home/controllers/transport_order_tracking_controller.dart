import 'dart:async';

import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:najiz_go_express/core/services/order_websocket_service.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';

class TransportOrderTrackingController extends GetxController {
  TransportOrderTrackingController({
    required this.token,
    required this.orderId,
    required this.orderNumber,
    required this.initialStatus,
    required this.initialDispatchStatus,
    required this.pickupPoint,
    required this.destinationPoint,
    this.initialTripDistanceKm,
  });

  final String token;
  final int orderId;
  final String orderNumber;
  final String initialStatus;
  final String initialDispatchStatus;
  final LatLng pickupPoint;
  final LatLng destinationPoint;
  final double? initialTripDistanceKm;

  final currentStatus = ''.obs;
  final currentDispatchStatus = ''.obs;
  final isLiveConnected = false.obs;
  final errorMessage = RxnString();
  final driverPoint = Rxn<LatLng>();
  final driverName = RxnString();
  final driverPhone = RxnString();
  final driverVehicleType = RxnString();
  final driverPlate = RxnString();
  final driverRating = RxnString();
  final tripDistanceKm = RxnDouble();
  final finalFare = RxnDouble();
  final isSubmittingRating = false.obs;
  final ratingSubmitted = false.obs;
  final didNotifyDriverArrived = false.obs;
  final didNotifyTripStarted = false.obs;

  OrderWebSocketService? _wsService;
  final HomeRepository _repository = HomeRepository();
  Timer? _pollTimer;

  String? _firstNonEmpty(List<dynamic> candidates) {
    for (final raw in candidates) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  @override
  void onInit() {
    super.onInit();
    currentStatus.value = initialStatus;
    currentDispatchStatus.value = initialDispatchStatus;
    tripDistanceKm.value = initialTripDistanceKm;
    _connect();
    _refreshDriverInfo();
    _startPollingOrderState();
  }

  Future<void> _refreshDriverInfo() async {
    if (!_isDriverAccepted()) return;
    try {
      final driver = await _repository.getOrderDriverByOrderId(
        token: token,
        orderId: orderId,
      );
      if (driver.isNotEmpty) {
        _applyDriverPayload(driver);
      }
    } catch (_) {
      // Driver info endpoint is best-effort; order polling remains primary.
    }
  }

  Future<void> _connect() async {
    errorMessage.value = null;
    _wsService = OrderWebSocketService(token: token);
    try {
      await _wsService!.subscribeToOrder(
        orderId: orderId,
        onOrderUpdated: _onOrderUpdated,
      );
      isLiveConnected.value = true;
    } catch (e) {
      isLiveConnected.value = false;
      errorMessage.value = 'تعذر الاتصال بالتتبع اللحظي: $e';
    }
  }

  void _onOrderUpdated(Map<String, dynamic> payload) {
    _applyOrderPayload(payload);
  }

  void _applyOrderPayload(Map<String, dynamic> payload) {
    currentStatus.value = (payload['status'] ?? currentStatus.value).toString();
    currentDispatchStatus.value =
        (payload['dispatch_status'] ?? currentDispatchStatus.value).toString();
    finalFare.value = _asDouble(payload['total']) ?? finalFare.value;

    final taxiOrder = _asMap(payload['taxi_order'] ?? payload['taxiOrder']);
    if (taxiOrder != null) {
      tripDistanceKm.value = _asDouble(
        taxiOrder['distance'] ??
            taxiOrder['distance_km'] ??
            taxiOrder['actual_distance'] ??
            taxiOrder['route_distance'],
      );
      finalFare.value ??= _asDouble(
        taxiOrder['estimated_price'] ?? taxiOrder['final_price'],
      );
    }

    // Live driver location event payload can come as flat keys:
    // {lat, lng, delivery_man_id, order_id}
    final eventLat = double.tryParse(payload['lat']?.toString() ?? '');
    final eventLng = double.tryParse(payload['lng']?.toString() ?? '');
    if (eventLat != null && eventLng != null) {
      driverPoint.value = LatLng(eventLat, eventLng);
    }

    final deliveryMan = _asMap(payload['delivery_man'] ?? payload['deliveryMan']);
    if (deliveryMan != null) {
      final lat = double.tryParse(deliveryMan['current_lat']?.toString() ?? '');
      final lng = double.tryParse(deliveryMan['current_lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        driverPoint.value = LatLng(lat, lng);
      }
      driverVehicleType.value = _firstNonEmpty([
        deliveryMan['vehicle_type'],
        deliveryMan['vehicleType'],
        deliveryMan['vehicle'],
      ]);
      driverPlate.value = _firstNonEmpty([
        deliveryMan['license_plate'],
        deliveryMan['plate_number'],
        deliveryMan['plate'],
      ]);
      driverRating.value = _firstNonEmpty([deliveryMan['rating'], deliveryMan['rate']]);

      final driverUser = _asMap(
        deliveryMan['user'] ??
            deliveryMan['driver_user'] ??
            deliveryMan['driverUser'] ??
            deliveryMan['account'],
      );
      if (driverUser != null) {
        driverName.value = _firstNonEmpty([
          driverUser['name'],
          driverUser['full_name'],
          driverUser['username'],
        ]);
        driverPhone.value = _firstNonEmpty([
          driverUser['phone'],
          driverUser['mobile'],
        ]);
      }
      driverName.value ??= _firstNonEmpty([
        deliveryMan['name'],
        deliveryMan['full_name'],
        deliveryMan['driver_name'],
      ]);
    }

    // Fallback if backend sends a flat `delivery_man_name`.
    if ((driverName.value ?? '').isEmpty) {
      driverName.value = _firstNonEmpty([
        payload['delivery_man_name'],
        payload['driver_name'],
        payload['captain_name'],
        payload['deliveryManName'],
      ]);
      final flatDriverUser = _asMap(
        payload['delivery_man_user'] ??
            payload['driver_user'] ??
            payload['deliveryManUser'],
      );
      if (flatDriverUser != null) {
        driverName.value ??= _firstNonEmpty([
          flatDriverUser['name'],
          flatDriverUser['full_name'],
          flatDriverUser['username'],
        ]);
      }
    }

    _emitRideMilestonesIfNeeded();
  }

  void _applyDriverPayload(Map<String, dynamic> payload) {
    driverName.value = _firstNonEmpty([
      payload['driver_name'],
      payload['name'],
      driverName.value,
    ]);
    driverPhone.value = _firstNonEmpty([
      payload['driver_phone'],
      payload['phone'],
      driverPhone.value,
    ]);
    driverVehicleType.value = _firstNonEmpty([
      payload['vehicle_type'],
      payload['vehicle'],
      driverVehicleType.value,
    ]);
    driverPlate.value = _firstNonEmpty([
      payload['license_plate'],
      payload['plate_number'],
      driverPlate.value,
    ]);
    driverRating.value = _firstNonEmpty([
      payload['rating'],
      payload['rate'],
      driverRating.value,
    ]);

    final lat = double.tryParse(payload['current_lat']?.toString() ?? '');
    final lng = double.tryParse(payload['current_lng']?.toString() ?? '');
    if (lat != null && lng != null) {
      driverPoint.value = LatLng(lat, lng);
    }
  }

  void _startPollingOrderState() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (_isDelivered()) return;
      try {
        final latest = await _repository.getOrderById(
          token: token,
          orderId: orderId,
        );
        if (latest.isNotEmpty) {
          _applyOrderPayload(latest);
        }
        if (_isDriverAccepted()) {
          final driver = await _repository.getOrderDriverByOrderId(
            token: token,
            orderId: orderId,
          );
          if (driver.isNotEmpty) {
            _applyDriverPayload(driver);
          }
        }
      } catch (_) {
        // Keep UI stable; websocket still acts as primary live source.
      }
    });
  }

  int get stageIndex {
    if (_isDelivered()) return 3;
    if (_isInRidePhase()) return 2;
    if (_isTripStarted()) return 1;
    if (_isDriverAccepted()) return 0;
    return -1;
  }

  bool _isDriverAccepted() {
    return currentDispatchStatus.value == 'accepted' ||
        currentStatus.value == 'accepted';
  }

  bool _isTripStarted() {
    return currentStatus.value == 'picked_up' || currentStatus.value == 'on_way';
  }

  bool _isInRidePhase() {
    return currentStatus.value == 'on_way';
  }

  bool get isHeadingToPickup =>
      currentStatus.value == 'on_the_way_to_pickup' ||
      currentStatus.value == 'accepted' ||
      currentDispatchStatus.value == 'accepted';

  bool get isTripInProgress =>
      currentStatus.value == 'picked_up' || currentStatus.value == 'on_way';

  void _emitRideMilestonesIfNeeded() {
    // 1) Notify when ride starts.
    if (!didNotifyTripStarted.value && isTripInProgress) {
      didNotifyTripStarted.value = true;
      Get.snackbar(
        'بدأت الرحلة',
        'تم الانطلاق، يمكنك متابعة المسار حتى الوجهة',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }

    // 2) Notify when driver reaches pickup point.
    if (didNotifyDriverArrived.value || !isHeadingToPickup) return;
    final driver = driverPoint.value;
    if (driver == null) return;

    final meters = const Distance().as(
      LengthUnit.Meter,
      driver,
      pickupPoint,
    );
    if (meters <= 80) {
      didNotifyDriverArrived.value = true;
      Get.snackbar(
        'وصل السائق',
        'السائق وصل إلى نقطة الالتقاط',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  bool _isDelivered() => currentStatus.value == 'delivered';

  Future<void> submitTripRating({
    required int rating,
    String? comment,
  }) async {
    isSubmittingRating.value = true;
    try {
      await _repository.rateOrder(
        token: token,
        orderId: orderId,
        // Backend requires vendor_rating; for taxi we map the same user score.
        vendorRating: rating,
        deliveryRating: rating,
        comment: comment,
      );
      ratingSubmitted.value = true;
    } on HomeApiException {
      rethrow;
    } catch (_) {
      throw HomeApiException('تعذر إرسال التقييم حالياً');
    } finally {
      isSubmittingRating.value = false;
    }
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    _wsService?.disconnect();
    super.onClose();
  }
}
