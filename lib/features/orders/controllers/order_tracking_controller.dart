import 'dart:async';

import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:najiz_go_express/core/utils/delivery_eta_helper.dart';
import 'package:najiz_go_express/core/utils/dispatch_timeout_config.dart';
import 'package:najiz_go_express/features/orders/errors/orders_api_exception.dart';
import 'package:najiz_go_express/features/orders/models/order_driver_info.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/orders/services/orders_dependencies.dart';
import 'package:najiz_go_express/core/services/order_websocket_service.dart';
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

  final OrdersRepository _repository = resolveOrdersRepository();
  final PushNotificationService _pushService = Get.find<PushNotificationService>();

  OrderWebSocketService? _wsService;
  Timer? _driverPollTimer;
  Timer? _dispatchTimeoutTimer;
  DateTime? _dispatchTimeoutStartedAt;
  Duration _dispatchTimeoutDuration = DispatchTimeoutConfig.defaultTimeout;
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
    currentStatus.value = initialStatus;
    currentDispatchStatus.value = initialDispatchStatus;
    _rememberActiveStatus(initialStatus);
    _noDriverTracker.shouldHandleNoDriver(
      status: initialStatus,
      dispatchStatus: initialDispatchStatus,
    );
    _checkVendorRejection(
      status: initialStatus,
      dispatchStatus: initialDispatchStatus,
    );
    _syncDispatchTimeoutWatcher(
      status: initialStatus,
      dispatchStatus: initialDispatchStatus,
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
      errorMessage.value = 'tracking.liveConnectFailed'.trParams({'error': e.toString()});
    }
  }

  void _onOrderUpdated(Map<String, dynamic> payload) {
    if (kDebugMode) {
      print('[TRACKING][UPDATE] status=${payload['status']} dispatch=${payload['dispatch_status']}');
    }
    currentStatus.value = (payload['status'] ?? currentStatus.value).toString();
    currentDispatchStatus.value =
        (payload['dispatch_status'] ?? currentDispatchStatus.value).toString();
    _rememberActiveStatus(currentStatus.value);
    _checkVendorRejection(
      status: currentStatus.value,
      dispatchStatus: currentDispatchStatus.value,
      payload: payload,
    );
    if (vendorRejectionDetected.value) return;
    _checkNoDriver(currentStatus.value, currentDispatchStatus.value);
    if (noDriverDetected.value) return;
    _syncDispatchTimeoutWatcher(
      status: currentStatus.value,
      dispatchStatus: currentDispatchStatus.value,
      payload: payload,
    );
    if (noDriverDetected.value) return;
    _emitDriverArrivalNotificationsIfNeeded();
    _refreshDriverInfoIfNeeded();
  }

  void _checkNoDriver(String status, String dispatchStatus) {
    if (_handledNoDriver || vendorRejectionDetected.value) return;
    if (!_noDriverTracker.shouldHandleNoDriver(
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      return;
    }
    _handledNoDriver = true;
    _stopDispatchTimeoutWatcher();
    noDriverDetected.value = true;
  }

  void _syncDispatchTimeoutWatcher({
    required String status,
    required String dispatchStatus,
    Map<String, dynamic>? payload,
  }) {
    if (_handledNoDriver ||
        vendorRejectionDetected.value ||
        noDriverDetected.value) {
      _stopDispatchTimeoutWatcher();
      return;
    }

    if (payload != null && payload.isNotEmpty) {
      _dispatchTimeoutDuration = DispatchTimeoutConfig.resolveFromPayload(payload);
    }

    if (!_shouldWatchDispatchTimeout(status, dispatchStatus)) {
      _stopDispatchTimeoutWatcher();
      return;
    }

    _dispatchTimeoutStartedAt ??=
        DispatchTimeoutConfig.resolveDispatchStartedAt(payload) ??
            DateTime.now();

    final remaining = DispatchTimeoutConfig.remainingTimeout(
      timeout: _dispatchTimeoutDuration,
      startedAt: _dispatchTimeoutStartedAt!,
    );
    if (remaining <= Duration.zero) {
      _checkNoDriver('no_driver', dispatchStatus);
      return;
    }

    _dispatchTimeoutTimer ??= Timer(remaining, () {
      if (_handledNoDriver || vendorRejectionDetected.value) return;
      _checkNoDriver('no_driver', dispatchStatus);
    });
  }

  bool _shouldWatchDispatchTimeout(String status, String dispatchStatus) {
    if (OrderDispatchUtils.isNoDriver(
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      return false;
    }
    if (OrderDispatchUtils.isDriverAssigned(
      kind: OrderDispatchServiceKind.delivery,
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      return false;
    }

    final normalizedStatus = _normalizeStatus(status);
    if (normalizedStatus == 'pending' ||
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled' ||
        normalizedStatus == 'rejected' ||
        normalizedStatus == 'delivered') {
      return false;
    }

    return true;
  }

  void _stopDispatchTimeoutWatcher() {
    _dispatchTimeoutTimer?.cancel();
    _dispatchTimeoutTimer = null;
    _dispatchTimeoutStartedAt = null;
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
    final normalized = _normalizeStatus(status);
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
    if (!_shouldTrackDriverEta()) {
      deliveryEta.value = null;
      driverInfo.value = null;
      return;
    }
    if (_isDriverPollInFlight) return;
    _isDriverPollInFlight = true;
    try {
      await _ensureDestinationCoordinates();
      final driver = await _repository.getOrderDriverByOrderId(
        token: token,
        orderId: orderId,
      );
      if (driver.isEmpty) return;
      driverInfo.value = driver;
      deliveryEta.value = driver.resolveEta(
        destinationLat: _destinationLat,
        destinationLng: _destinationLng,
      );
    } catch (_) {
      // Driver info is best-effort and should not block live tracking.
    } finally {
      _isDriverPollInFlight = false;
    }
  }

  Future<void> _ensureDestinationCoordinates() async {
    if (_destinationLat != null && _destinationLng != null) return;
    final order = await _repository.getOrderById(token: token, orderId: orderId);
    if (order.isEmpty) return;
    final orderStatus = (order['status'] ?? '').toString();
    final orderDispatch = (order['dispatch_status'] ?? '').toString();
    _rememberActiveStatus(orderStatus);
    _checkVendorRejection(
      status: orderStatus,
      dispatchStatus: orderDispatch,
      payload: order,
    );
    if (vendorRejectionDetected.value) return;
    _checkNoDriver(orderStatus, orderDispatch);
    if (noDriverDetected.value) return;
    _syncDispatchTimeoutWatcher(
      status: orderStatus,
      dispatchStatus: orderDispatch,
      payload: order,
    );
    if (noDriverDetected.value) return;
    _destinationLat = _asDouble(order['lat']);
    _destinationLng = _asDouble(order['lng']);
  }

  bool _shouldTrackDriverEta() {
    if (_isCompletedOrCancelled(_normalizeStatus(currentStatus.value))) {
      return false;
    }
    final status = _normalizeStatus(currentStatus.value);
    final dispatch = _normalizeStatus(currentDispatchStatus.value);
    const trackStatuses = {
      'on_way',
      'picked_up',
      'out_for_delivery',
      'food_driver_assigned',
      'driver_assigned',
    };
    const trackDispatch = {'accepted', 'assigned', 'picked_up', 'on_way'};
    return trackStatuses.contains(status) || trackDispatch.contains(dispatch);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void _emitDriverArrivalNotificationsIfNeeded() {
    final status = _normalizeStatus(currentStatus.value);
    final dispatch = _normalizeStatus(currentDispatchStatus.value);

    if (_isCompletedOrCancelled(status)) return;

    final isDriverNearAddress =
        _nearAddressStatuses.contains(status) ||
        _nearAddressStatuses.contains(dispatch);

    final isDriverArrivedWaiting =
        _arrivedWaitingStatuses.contains(status) ||
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

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  bool _isCompletedOrCancelled(String status) {
    return status == 'delivered' ||
        status == 'cancelled' ||
        status == 'canceled' ||
        status == 'rejected';
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

  @override
  void onClose() {
    _driverPollTimer?.cancel();
    _stopDispatchTimeoutWatcher();
    _wsService?.disconnect();
    super.onClose();
  }
}
