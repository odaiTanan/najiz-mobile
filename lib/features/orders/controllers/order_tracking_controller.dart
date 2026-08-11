import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:najiz_go_express/core/utils/delivery_eta_helper.dart';
import 'package:najiz_go_express/features/orders/errors/orders_api_exception.dart';
import 'package:najiz_go_express/features/orders/models/order_driver_info.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/orders/services/orders_dependencies.dart';
import 'package:najiz_go_express/core/services/order_websocket_service.dart';
import 'package:najiz_go_express/core/services/order_progress_notification_mapper.dart';
import 'package:najiz_go_express/core/utils/order_dispatch_utils.dart';
import 'package:najiz_go_express/core/utils/vendor_order_rejection.dart';

class OrderTrackingController extends GetxController {
  OrderTrackingController({
    required this.token,
    required this.orderId,
    required this.orderNumber,
    required this.initialStatus,
    required this.initialDispatchStatus,
  });

  final String token;
  final int orderId;
  final String orderNumber;
  final String initialStatus;
  final String initialDispatchStatus;

  final currentStatus = ''.obs;
  final currentDispatchStatus = ''.obs;
  final isLiveConnected = false.obs;
  final errorMessage = RxnString();
  final deliveryEta = Rxn<DeliveryEta>();
  final driverInfo = Rxn<OrderDriverInfo>();
  final isSubmittingRating = false.obs;
  final ratingSubmitted = false.obs;
  final hasPromptedForRating = false.obs;
  final showRatingButton = false.obs;
  final noDriverDetected = false.obs;
  final isCancellingDueToNoDriver = false.obs;
  final vendorRejectionDetected = false.obs;
  /// True only when backend provided a concrete driver identity for this order.
  final hasAssignedDriver = false.obs;

  final OrdersRepository _repository = resolveOrdersRepository();
  final PushNotificationService _pushService =
      Get.find<PushNotificationService>();

  OrderWebSocketService? _wsService;
  Timer? _driverPollTimer;
  bool _cancelledDueToNoDriver = false;
  double? _destinationLat;
  double? _destinationLng;
  bool _isDriverPollInFlight = false;
  bool _didNotifyNearAddress = false;
  bool _didNotifyArrivedWaiting = false;
  bool _handledNoDriver = false;
  bool _handledVendorRejection = false;
  String _lastNonCancelledStatus = '';
  final OrderDispatchTransitionTracker _noDriverTracker =
      OrderDispatchTransitionTracker();

  @override
  void onInit() {
    super.onInit();
    _applyLifecycleSnapshot(
      status: initialStatus,
      dispatchStatus: initialDispatchStatus,
    );
    _noDriverTracker.shouldHandleNoDriver(
      status: currentStatus.value,
      dispatchStatus: currentDispatchStatus.value,
    );
    _checkVendorRejection(
      status: currentStatus.value,
      dispatchStatus: currentDispatchStatus.value,
    );
    _emitDriverArrivalNotificationsIfNeeded();
    _connect();
    _startDriverEtaPolling();
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
      errorMessage.value =
          'tracking.liveConnectFailed'.trParams({'error': e.toString()});
    }
  }

  void _onOrderUpdated(Map<String, dynamic> payload) {
    final statusRaw =
        payload['status']?.toString() ?? payload['order_status']?.toString();
    final dispatchRaw = payload['dispatch_status']?.toString() ??
        payload['driver_status']?.toString();
    if (kDebugMode) {
      print('[TRACKING][UPDATE] status=$statusRaw dispatch=$dispatchRaw');
    }
    _applyLifecycleSnapshot(
      status: statusRaw,
      dispatchStatus: dispatchRaw,
      payload: payload,
    );
  }

  void _applyLifecycleSnapshot({
    String? status,
    String? dispatchStatus,
    Map<String, dynamic>? payload,
  }) {
    final nextStatus = _resolveIncomingStatus(
      statusRaw: status,
      dispatchRaw: dispatchStatus,
    );
    final nextDispatch = _canonicalizeOrKeep(
      dispatchStatus,
      currentDispatchStatus.value,
    );

    if (nextStatus != null) {
      currentStatus.value = nextStatus;
      if (_isPostAssignmentOrderStatus(nextStatus)) {
        hasAssignedDriver.value = true;
      }
    }
    if (nextDispatch != null) {
      currentDispatchStatus.value = nextDispatch;
    }

    if (payload != null) {
      _captureDriverAssignmentEvidence(payload);
    }

    _rememberActiveStatus(currentStatus.value);
    _checkVendorRejection(
      status: currentStatus.value,
      dispatchStatus: currentDispatchStatus.value,
      payload: payload,
    );
    if (vendorRejectionDetected.value) return;
    _checkNoDriver(currentStatus.value, currentDispatchStatus.value);
    if (noDriverDetected.value) return;
    _emitDriverArrivalNotificationsIfNeeded();
    _refreshDriverInfoIfNeeded();
  }

  /// Definitive proof of driver assignment: a concrete driver id / delivery_man
  /// entity on the order payload (not dispatch_status alone).
  void _captureDriverAssignmentEvidence(Map<String, dynamic> payload) {
    final driverId = _extractAssignedDriverId(payload);
    if (driverId != null) {
      hasAssignedDriver.value = true;
    }

    final deliveryMan = _asMap(payload['delivery_man'] ?? payload['deliveryMan']);
    if (deliveryMan != null) {
      final info = OrderDriverInfo.fromPayload(payload);
      if (!info.isEmpty) {
        hasAssignedDriver.value = true;
        driverInfo.value = driverInfo.value?.mergedWith(info) ?? info;
      }
    }
  }

  int? _extractAssignedDriverId(Map<String, dynamic> payload) {
    for (final key in [
      'delivery_man_id',
      'deliveryManId',
      'driver_id',
      'driverId',
    ]) {
      final id = int.tryParse(payload[key]?.toString() ?? '');
      if (id != null && id > 0) return id;
    }
    final deliveryMan = _asMap(payload['delivery_man'] ?? payload['deliveryMan']);
    if (deliveryMan != null) {
      final id = int.tryParse(deliveryMan['id']?.toString() ?? '');
      if (id != null && id > 0) return id;
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

  /// Prefer explicit order status; promote dispatch terminal states when needed.
  String? _resolveIncomingStatus({
    String? statusRaw,
    String? dispatchRaw,
  }) {
    final current = _canonical(currentStatus.value);
    final incomingStatus = _canonical(statusRaw ?? '');
    final incomingDispatch = _canonical(dispatchRaw ?? '');

    String? resolved;
    if (incomingStatus.isNotEmpty) {
      resolved = incomingStatus;
    } else if (_isDeliveredLike(incomingDispatch)) {
      resolved = 'delivered';
    }

    if (resolved == null || resolved.isEmpty) return null;

    // Never let stale WS/location snapshots regress past a terminal status.
    if (_isTerminalLifecycle(current) && !_isTerminalLifecycle(resolved)) {
      return null;
    }
    return resolved;
  }

  String? _canonicalizeOrKeep(String? raw, String fallback) {
    final incoming = (raw ?? '').trim();
    if (incoming.isEmpty) return null;
    final canonical = _canonical(incoming);
    return canonical.isEmpty ? fallback : canonical;
  }

  void _checkNoDriver(String status, String dispatchStatus) {
    if (_handledNoDriver || vendorRejectionDetected.value) return;
    // Only when backend explicitly reports no_driver (never from local timeouts).
    if (!_noDriverTracker.shouldHandleNoDriver(
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      return;
    }
    _handledNoDriver = true;
    noDriverDetected.value = true;
  }

  Future<bool> cancelOrderDueToNoDriver() async {
    if (_cancelledDueToNoDriver) return true;
    isCancellingDueToNoDriver.value = true;
    try {
      await _repository.cancelOrder(
        token: token,
        orderId: orderId,
        cancellationReason: 'dispatch.noDriverCancelReason'.tr,
      );
      _cancelledDueToNoDriver = true;
      return true;
    } on OrdersApiException {
      return false;
    } catch (_) {
      return false;
    } finally {
      isCancellingDueToNoDriver.value = false;
    }
  }

  void _rememberActiveStatus(String status) {
    final normalized = _canonical(status);
    if (normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'rejected') {
      return;
    }
    _lastNonCancelledStatus = status;
  }

  void _checkVendorRejection({
    required String status,
    required String dispatchStatus,
    Map<String, dynamic>? payload,
  }) {
    if (_handledVendorRejection) return;
    if (!VendorOrderRejectionUtils.isVendorRejection(
      status: status,
      dispatchStatus: dispatchStatus,
      payload: payload,
      lastNonCancelledStatus: _lastNonCancelledStatus,
    )) {
      return;
    }
    _handledVendorRejection = true;
    vendorRejectionDetected.value = true;
  }

  void _startDriverEtaPolling() {
    _driverPollTimer?.cancel();
    _driverPollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshDriverInfoIfNeeded(),
    );
    _refreshDriverInfoIfNeeded();
  }

  Future<void> _refreshDriverInfoIfNeeded() async {
    if (_isTerminalLifecycle(_canonical(currentStatus.value)) ||
        noDriverDetected.value ||
        vendorRejectionDetected.value) {
      deliveryEta.value = null;
      return;
    }
    if (_isDriverPollInFlight) return;
    _isDriverPollInFlight = true;
    try {
      await _ensureDestinationCoordinates();
      if (vendorRejectionDetected.value ||
          noDriverDetected.value ||
          isDelivered) {
        return;
      }

      // While waiting for a driver (and after assignment), ask the backend
      // whether a concrete driver entity exists. Empty != no_driver.
      final driver = await _repository.getOrderDriverByOrderId(
        token: token,
        orderId: orderId,
      );
      if (driver.isEmpty) return;

      hasAssignedDriver.value = true;
      driverInfo.value = driverInfo.value?.mergedWith(driver) ?? driver;
      if (_shouldShowDriverEta()) {
        deliveryEta.value = driver.resolveEta(
          destinationLat: _destinationLat,
          destinationLng: _destinationLng,
        );
      }
    } catch (_) {
      // Driver info is best-effort and should not block live tracking.
    } finally {
      _isDriverPollInFlight = false;
    }
  }

  Future<void> _ensureDestinationCoordinates() async {
    final needsCoords = _destinationLat == null || _destinationLng == null;
    final needsLifecycleSync =
        !_isTerminalLifecycle(_canonical(currentStatus.value));
    if (!needsCoords && !needsLifecycleSync) return;

    final order = await _repository.getOrderById(token: token, orderId: orderId);
    if (order.isEmpty) return;

    final nextStatus = _resolveIncomingStatus(
      statusRaw:
          order['status']?.toString() ?? order['order_status']?.toString(),
      dispatchRaw: order['dispatch_status']?.toString() ??
          order['driver_status']?.toString(),
    );
    final nextDispatch = _canonicalizeOrKeep(
      order['dispatch_status']?.toString() ?? order['driver_status']?.toString(),
      currentDispatchStatus.value,
    );
    if (nextStatus != null) currentStatus.value = nextStatus;
    if (nextDispatch != null) currentDispatchStatus.value = nextDispatch;
    _captureDriverAssignmentEvidence(order);

    _rememberActiveStatus(currentStatus.value);
    _checkVendorRejection(
      status: currentStatus.value,
      dispatchStatus: currentDispatchStatus.value,
      payload: order,
    );
    if (vendorRejectionDetected.value) return;
    _checkNoDriver(currentStatus.value, currentDispatchStatus.value);
    if (noDriverDetected.value || isDelivered) return;

    _destinationLat ??= _asDouble(order['lat']);
    _destinationLng ??= _asDouble(order['lng']);
  }

  bool _shouldShowDriverEta() {
    if (!hasAssignedDriver.value) return false;
    if (_isTerminalLifecycle(_canonical(currentStatus.value))) return false;
    final status = _canonical(currentStatus.value);
    const etaStatuses = {
      'assigned',
      'on_the_way_to_pickup',
      'picked_up',
      'on_way',
      'out_for_delivery',
    };
    return etaStatuses.contains(status);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _emitDriverArrivalNotificationsIfNeeded() {
    final status = _canonical(currentStatus.value);
    final dispatch = _canonical(currentDispatchStatus.value);

    if (_isTerminalLifecycle(status)) return;

    final isDriverNearAddress = _nearAddressStatuses.contains(status) ||
        _nearAddressStatuses.contains(dispatch);

    final isDriverArrivedWaiting = _arrivedWaitingStatuses.contains(status) ||
        _arrivedWaitingStatuses.contains(dispatch);

    if (!_didNotifyNearAddress && isDriverNearAddress) {
      _didNotifyNearAddress = true;
      _pushService.pushLocalInAppNotification(
        title: 'tracking.deliveryAlert'.tr,
        body: 'tracking.driverNearby'.tr,
        dedupeKey: 'order-$orderId-near-address',
        data: {'order_id': orderId, 'event': 'driver_near_address'},
      );
    }

    if (!_didNotifyArrivedWaiting && isDriverArrivedWaiting) {
      _didNotifyArrivedWaiting = true;
      _pushService.pushLocalInAppNotification(
        title: 'tracking.deliveryAlert'.tr,
        body: 'tracking.driverWaiting'.tr,
        dedupeKey: 'order-$orderId-arrived-waiting',
        data: {'order_id': orderId, 'event': 'driver_arrived_waiting'},
      );
    }
  }

  String _canonical(String raw) {
    return OrderProgressNotificationMapper.canonicalStatus(raw);
  }

  bool _isDeliveredLike(String status) {
    return status == 'delivered' || status == 'completed';
  }

  bool _isPostAssignmentOrderStatus(String orderStatus) {
    const postAssignment = {
      'assigned',
      'on_the_way_to_pickup',
      'heading_to_pickup',
      'driver_heading_to_pickup',
      'picked_up',
      'on_way',
    };
    return postAssignment.contains(orderStatus);
  }

  bool _isTerminalLifecycle(String status) {
    return _isDeliveredLike(status) ||
        status == 'cancelled' ||
        status == 'canceled' ||
        status == 'rejected' ||
        status == 'no_driver';
  }

  static const Set<String> _nearAddressStatuses = {
    'on_way',
    'near_destination',
    'nearby',
    'approaching_destination',
    'driver_near',
  };

  static const Set<String> _arrivedWaitingStatuses = {
    'arrived',
    'waiting',
    'arrived_waiting',
    'driver_arrived',
    'at_destination',
    'at_pickup',
    'waiting_at_destination',
    'waiting_at_pickup',
  };

  Future<void> submitRating({
    required int vendorRating,
    int? deliveryRating,
    String? comment,
  }) async {
    isSubmittingRating.value = true;
    try {
      await _repository.rateOrder(
        token: token,
        orderId: orderId,
        vendorRating: vendorRating,
        deliveryRating: deliveryRating,
        comment: comment,
      );
      ratingSubmitted.value = true;
      showRatingButton.value = false;
    } on OrdersApiException catch (e) {
      throw e.message;
    } catch (_) {
      throw 'tracking.rateFailed'.tr;
    } finally {
      isSubmittingRating.value = false;
    }
  }

  void postponeRating() {
    showRatingButton.value = true;
  }

  bool get isDelivered =>
      _isDeliveredLike(_canonical(currentStatus.value)) ||
      _isDeliveredLike(_canonical(currentDispatchStatus.value));

  @override
  void onClose() {
    _driverPollTimer?.cancel();
    _wsService?.disconnect();
    super.onClose();
  }
}
