import 'dart:async';

import 'package:najiz_go_express/core/utils/delivery_eta_helper.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/features/orders/errors/orders_api_exception.dart';
import 'package:najiz_go_express/features/orders/models/order_driver_info.dart';
import 'package:najiz_go_express/features/orders/services/orders_dependencies.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/disconnect_dialog.dart';
import 'package:latlong2/latlong.dart';
import 'package:najiz_go_express/core/services/order_websocket_service.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/order_progress_notification_mapper.dart';
import 'package:najiz_go_express/core/services/shipping_order_state.dart';
import 'package:najiz_go_express/core/services/taxi_order_state.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';

class TransportOrderTrackingController extends GetxController {
  TransportOrderTrackingController({
    required this.token,
    required this.orderId,
    required this.orderNumber,
    required this.orderType,
    required this.initialStatus,
    required this.initialDispatchStatus,
    required this.pickupPoint,
    required this.destinationPoint,
    this.initialTripDistanceKm,
  });

  final String token;
  final int orderId;
  final String orderNumber;
  final String orderType;
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
  final deliveryCode = RxnString();
  final driverInfo = Rxn<OrderDriverInfo>();
  final tripDistanceKm = RxnDouble();
  final finalFare = RxnDouble();
  final deliveryEta = Rxn<DeliveryEta>();
  final isSubmittingRating = false.obs;
  final ratingSubmitted = false.obs;
  final didNotifyDriverArrived = false.obs;
  final didNotifyTripStarted = false.obs;
  final isSubmittingSos = false.obs;
  final sosSubmitted = false.obs;

  OrderWebSocketService? _wsService;
  final OrdersRepository _repository = resolveOrdersRepository();
  final PushNotificationService _pushService = Get.find<PushNotificationService>();
  Timer? _pollTimer;
  bool _didNotifyNearDestination = false;
  bool _didNotifyArrivedWaitingAtDestination = false;
  bool _isPollingRequestInFlight = false;
  DateTime? _lastTimeoutPopupAt;

  String? _extractDeliveryCode(Map<String, dynamic> payload) {
    final shippingOrder =
        _asMap(payload['shipping_order'] ?? payload['shippingOrder']);
    return _firstNonEmpty([
      payload['delivery_code'],
      payload['deliveryCode'],
      shippingOrder?['delivery_code'],
      shippingOrder?['deliveryCode'],
      deliveryCode.value,
    ]);
  }

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
      if (!driver.isEmpty) {
        _applyDriverInfo(driver);
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
    } catch (_) {
      isLiveConnected.value = false;
      errorMessage.value = 'tracking.connectFailed'.tr;
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
    deliveryCode.value = _extractDeliveryCode(payload);

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

    // Live driver GPS may arrive as flat keys on websocket events only.
    // Order payloads also include lat/lng for pickup/destination — never treat those as driver location.
    final hasLiveDriverEvent = payload.containsKey('delivery_man_id') ||
        payload.containsKey('deliveryManId') ||
        payload.containsKey('driver_id') ||
        payload.containsKey('driverId');
    if (hasLiveDriverEvent) {
      final eventLat = double.tryParse(payload['lat']?.toString() ?? '');
      final eventLng = double.tryParse(payload['lng']?.toString() ?? '');
      if (eventLat != null && eventLng != null) {
        driverPoint.value = LatLng(eventLat, eventLng);
      }
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

    _applyDriverInfo(OrderDriverInfo.fromPayload(payload));
    _emitRideMilestonesIfNeeded();
    _refreshDeliveryEta();
  }

  void _applyDriverInfo(OrderDriverInfo incoming) {
    if (incoming.isEmpty) return;

    final merged = driverInfo.value == null
        ? incoming
        : driverInfo.value!.mergedWith(incoming);
    driverInfo.value = merged;

    driverName.value = merged.name ?? driverName.value;
    driverPhone.value = merged.phone ?? driverPhone.value;
    driverVehicleType.value = merged.vehicleType ?? driverVehicleType.value;
    driverPlate.value = merged.plate ?? driverPlate.value;
    driverRating.value = merged.rating ?? driverRating.value;
    deliveryCode.value = merged.deliveryCode ?? deliveryCode.value;

    if (merged.currentLat != null && merged.currentLng != null) {
      driverPoint.value = LatLng(merged.currentLat!, merged.currentLng!);
    }

    _refreshDeliveryEta(driver: merged);
    _emitRideMilestonesIfNeeded();
  }

  LatLng get _etaDestination =>
      isTripInProgress ? destinationPoint : pickupPoint;

  void _refreshDeliveryEta({OrderDriverInfo? driver}) {
    if (_isDelivered()) {
      deliveryEta.value = null;
      return;
    }

    final destination = _etaDestination;
    var payload = <String, dynamic>{...?driver?.rawPayload};
    final point = driverPoint.value;
    if (point != null) {
      payload = {
        ...payload,
        'current_lat': point.latitude,
        'current_lng': point.longitude,
      };
    }

    deliveryEta.value = DeliveryEtaHelper.resolve(
      driverPayload: payload.isEmpty ? null : payload,
      destinationLat: destination.latitude,
      destinationLng: destination.longitude,
    );
  }

  void _startPollingOrderState() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollOrderState());
    _pollOrderState();
  }

  Future<void> _pollOrderState({bool force = false}) async {
    if (_isDelivered()) return;
    if (_isPollingRequestInFlight && !force) return;
    _isPollingRequestInFlight = true;
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
        if (!driver.isEmpty) {
          _applyDriverInfo(driver);
        }
      }
    } on OrdersApiException catch (e) {
      if (_isTimeoutMessage(e.message)) {
        _showTimeoutPopup();
      }
    } catch (_) {
      // Keep UI stable; websocket still acts as primary live source.
    } finally {
      _isPollingRequestInFlight = false;
    }
  }

  bool _isTimeoutMessage(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('مهلة');
  }

  void _showTimeoutPopup() {
    final now = DateTime.now();
    final previous = _lastTimeoutPopupAt;
    if (previous != null && now.difference(previous) < const Duration(seconds: 20)) {
      return;
    }
    _lastTimeoutPopupAt = now;
    if (Get.isDialogOpen == true) return;

    final ctx = Get.context;
    if (ctx == null) return;
    showDisconnectDialog(ctx, onRetry: () => _pollOrderState(force: true));
  }

  int get stageIndex {
    if (orderType == 'taxi') {
      final status = TaxiOrderState.normalizeStatus(currentStatus.value);
      if (!TaxiOrderState.isAllowed(status)) return -1;
      return TaxiOrderState.stepIndexFor(status);
    }

    if (orderType == 'shipping') {
      return OrderProgressNotificationMapper.shippingTimelineStageIndex(
        currentStatus.value,
        dispatchStatusRaw: currentDispatchStatus.value,
      );
    }

    if (_isDelivered()) return 3;
    if (_isInRidePhase()) return 2;
    if (_isTripStarted()) return 1;
    if (_isDriverAccepted()) return 0;
    return -1;
  }

  bool _isDriverAccepted() {
    if (orderType == 'taxi') {
      return TaxiOrderState.stepIndexFor(currentStatus.value) >= 1;
    }
    if (orderType == 'shipping') {
      return stageIndex >= 0;
    }
    return currentStatus.value == 'accepted';
  }

  bool _isTripStarted() {
    if (orderType == 'taxi') {
      return TaxiOrderState.normalizeStatus(currentStatus.value) == 'on_way';
    }
    if (orderType == 'shipping') {
      return ShippingOrderState.isOnWayToDelivery(
        currentStatus.value,
        dispatchStatusRaw: currentDispatchStatus.value,
      );
    }
    return currentStatus.value == 'picked_up' || currentStatus.value == 'on_way';
  }

  bool _isInRidePhase() {
    if (orderType == 'taxi') {
      return TaxiOrderState.normalizeStatus(currentStatus.value) == 'on_way';
    }
    if (orderType == 'shipping') {
      return ShippingOrderState.isOnWayToDelivery(
        currentStatus.value,
        dispatchStatusRaw: currentDispatchStatus.value,
      );
    }
    return currentStatus.value == 'on_way';
  }

  bool get isHeadingToPickup {
    if (orderType == 'taxi') {
      return TaxiOrderState.normalizeStatus(currentStatus.value) ==
          'on_the_way_to_pickup';
    }
    const headingStatuses = {
      'on_the_way_to_pickup',
      'heading_to_pickup',
      'driver_heading_to_pickup',
    };
    final status = _normalizeStatus(currentStatus.value);
    return headingStatuses.contains(status);
  }

  bool get isTripInProgress {
    if (orderType == 'taxi') {
      return TaxiOrderState.normalizeStatus(currentStatus.value) == 'on_way';
    }
    if (orderType == 'shipping') {
      return ShippingOrderState.isOnWayToDelivery(
        currentStatus.value,
        dispatchStatusRaw: currentDispatchStatus.value,
      );
    }
    return currentStatus.value == 'picked_up' || currentStatus.value == 'on_way';
  }

  bool get isShippingPickedUp {
    if (orderType != 'shipping') return false;
    return ShippingOrderState.isPickedUp(
      currentStatus.value,
      dispatchStatusRaw: currentDispatchStatus.value,
    );
  }

  bool get isShippingDelivered {
    if (orderType != 'shipping') return false;
    return stageIndex >= 4 ||
        ShippingOrderState.isDelivered(currentStatus.value);
  }

  bool get shouldShowShippingDeliveryCode {
    if (orderType != 'shipping') return false;
    final code = (deliveryCode.value ?? '').trim();
    if (code.isEmpty) return false;
    return !isShippingDelivered;
  }

  String? get shippingDeliveryCode =>
      (deliveryCode.value ?? '').trim().isEmpty
          ? null
          : deliveryCode.value!.trim();

  String get shippingStatusTitleKey {
    if (orderType != 'shipping') return 'tracking.pending';
    return ShippingOrderState.titleKeyForStage(stageIndex);
  }

  void _emitRideMilestonesIfNeeded() {
    if (orderType == 'taxi') return;
    // 1) Notify when ride starts.
    if (!didNotifyTripStarted.value && isTripInProgress) {
      didNotifyTripStarted.value = true;
      AppSnackbar.show(
        'tracking.tripStarted'.tr,
        'tracking.tripStartedSubtitle'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }

    // 2) Notify when driver reaches pickup point.
    if (!didNotifyDriverArrived.value) {
      final status = _normalizeStatus(currentStatus.value);
      final dispatch = _normalizeStatus(currentDispatchStatus.value);
      final arrivedByStatus =
          _arrivedWaitingPickupStatuses.contains(status) ||
          _arrivedWaitingPickupStatuses.contains(dispatch);

      var arrivedByDistance = false;
      if (isHeadingToPickup || arrivedByStatus) {
        final driver = driverPoint.value;
        if (driver != null) {
          final meters = const Distance().as(
            LengthUnit.Meter,
            driver,
            pickupPoint,
          );
          arrivedByDistance = meters <= 80;
        }
      }

      if (arrivedByStatus || (isHeadingToPickup && arrivedByDistance)) {
        didNotifyDriverArrived.value = true;
        AppSnackbar.show(
          'tracking.driverArrived'.tr,
          'tracking.driverArrivedSubtitle'.tr,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        _pushService.pushLocalInAppNotification(
          title: 'tracking.tripAlert'.tr,
          body: 'tracking.driverWaiting'.tr,
          dedupeKey: 'order-$orderId-driver-arrived-pickup',
          data: {'order_id': orderId, 'event': 'driver_arrived_waiting'},
          showSnack: false,
        );
      }
    }

    _emitDestinationProximityNotificationsIfNeeded();
  }

  bool _isDelivered() {
    if (orderType == 'taxi') {
      return TaxiOrderState.normalizeStatus(currentStatus.value) == 'delivered';
    }
    return currentStatus.value == 'delivered';
  }

  void _emitDestinationProximityNotificationsIfNeeded() {
    if (!isTripInProgress) return;

    final driver = driverPoint.value;
    if (driver == null || _isDelivered()) return;

    final status = _normalizeStatus(currentStatus.value);
    final dispatch = _normalizeStatus(currentDispatchStatus.value);

    final metersToDestination = const Distance().as(
      LengthUnit.Meter,
      driver,
      destinationPoint,
    );

    final isNearByDistance = metersToDestination <= 250;
    final isNearByStatus =
        _nearDestinationStatuses.contains(status) ||
        _nearDestinationStatuses.contains(dispatch);

    if (!_didNotifyNearDestination && (isNearByDistance || isNearByStatus)) {
      _didNotifyNearDestination = true;
      _pushService.pushLocalInAppNotification(
        title: 'tracking.deliveryAlert'.tr,
        body: 'tracking.driverNearby'.tr,
        dedupeKey: 'order-$orderId-near-destination',
        data: {'order_id': orderId, 'event': 'driver_near_address'},
      );
    }

    final arrivedByDistance = metersToDestination <= 70;
    final arrivedByStatus =
        _arrivedWaitingDestinationStatuses.contains(status) ||
        _arrivedWaitingDestinationStatuses.contains(dispatch);

    if (!_didNotifyArrivedWaitingAtDestination &&
        (arrivedByDistance || arrivedByStatus)) {
      _didNotifyArrivedWaitingAtDestination = true;
      _pushService.pushLocalInAppNotification(
        title: 'tracking.deliveryAlert'.tr,
        body: 'tracking.driverWaiting'.tr,
        dedupeKey: 'order-$orderId-arrived-destination',
        data: {'order_id': orderId, 'event': 'driver_arrived_waiting'},
      );
    }
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  static const Set<String> _arrivedWaitingPickupStatuses = {
    'at_pickup',
    'waiting_at_pickup',
    'arrived_at_pickup',
    'driver_at_pickup',
    'waiting',
    'arrived_waiting',
    'driver_arrived',
    'arrived',
  };

  static const Set<String> _nearDestinationStatuses = {
    'on_way',
    'picked_up',
    'near_destination',
    'nearby',
    'approaching_destination',
    'driver_near',
  };

  static const Set<String> _arrivedWaitingDestinationStatuses = {
    'arrived',
    'waiting',
    'arrived_waiting',
    'driver_arrived',
    'at_destination',
    'waiting_at_destination',
    'reached_destination',
  };

  bool get canShowTaxiSos {
    if (orderType != 'taxi') return false;
    if (_isDelivered()) return false;
    final status = currentStatus.value.trim().toLowerCase();
    if (status == 'cancelled' || status == 'canceled') return false;
    return stageIndex >= 1;
  }

  Future<void> sendSos({String? reason}) async {
    if (!canShowTaxiSos || isSubmittingSos.value) return;
    isSubmittingSos.value = true;
    try {
      await _repository.sendOrderSos(
        token: token,
        orderId: orderId,
        reason: reason,
      );
      sosSubmitted.value = true;
    } on OrdersApiException {
      rethrow;
    } catch (_) {
      throw OrdersApiException('tracking.sosFailed'.tr);
    } finally {
      isSubmittingSos.value = false;
    }
  }

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
    } on OrdersApiException {
      rethrow;
    } catch (_) {
      throw OrdersApiException('tracking.rateFailed'.tr);
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
