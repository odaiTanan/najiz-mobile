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
  });

  final String token;
  final int orderId;
  final String orderNumber;
  final String initialStatus;
  final String initialDispatchStatus;
  final LatLng pickupPoint;
  final LatLng destinationPoint;

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

  OrderWebSocketService? _wsService;
  final HomeRepository _repository = HomeRepository();
  Timer? _pollTimer;

  @override
  void onInit() {
    super.onInit();
    currentStatus.value = initialStatus;
    currentDispatchStatus.value = initialDispatchStatus;
    _connect();
    _startPollingOrderState();
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

    final deliveryMan = payload['delivery_man'] ?? payload['deliveryMan'];
    if (deliveryMan is Map) {
      final lat = double.tryParse(deliveryMan['current_lat']?.toString() ?? '');
      final lng = double.tryParse(deliveryMan['current_lng']?.toString() ?? '');
      if (lat != null && lng != null) {
        driverPoint.value = LatLng(lat, lng);
      }
      driverVehicleType.value = deliveryMan['vehicle_type']?.toString();
      driverPlate.value = deliveryMan['license_plate']?.toString();
      driverRating.value = deliveryMan['rating']?.toString();

      final driverUser = deliveryMan['user'];
      if (driverUser is Map) {
        driverName.value = driverUser['name']?.toString();
        driverPhone.value = driverUser['phone']?.toString();
      }
    }

    // Fallback if backend sends a flat `delivery_man_name`.
    if ((driverName.value ?? '').isEmpty) {
      driverName.value = payload['delivery_man_name']?.toString();
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
      } catch (_) {
        // Keep UI stable; websocket still acts as primary live source.
      }
    });
  }

  int get stageIndex {
    if (_isDelivered()) return 3;
    if (_isOnWayToCustomer()) return 2;
    if (_isHeadingToPickup()) return 1;
    if (_isDriverAccepted()) return 0;
    return -1;
  }

  bool _isDriverAccepted() {
    return currentDispatchStatus.value == 'accepted' ||
        currentStatus.value == 'accepted';
  }

  bool _isHeadingToPickup() {
    final status = currentStatus.value;
    if (status == 'picked_up' || status == 'on_way' || status == 'delivered') {
      return false;
    }
    return status == 'on_the_way_to_pickup' ||
        status == 'accepted' ||
        currentDispatchStatus.value == 'accepted';
  }

  bool _isOnWayToCustomer() {
    return currentStatus.value == 'on_way' || currentStatus.value == 'picked_up';
  }

  bool _isDelivered() => currentStatus.value == 'delivered';

  @override
  void onClose() {
    _pollTimer?.cancel();
    _wsService?.disconnect();
    super.onClose();
  }
}
