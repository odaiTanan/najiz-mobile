import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/order_notification_stepper.dart';
import 'package:najiz_go_express/core/services/shipping_order_state.dart';
import 'package:najiz_go_express/core/services/taxi_order_state.dart';

class OrderProgressSnapshot {
  const OrderProgressSnapshot({
    required this.orderId,
    required this.orderKey,
    required this.groupKey,
    required this.notificationId,
    required this.orderType,
    required this.serviceName,
    required this.effectiveStatus,
    required this.stepIndex,
    required this.stepTotal,
    required this.title,
    required this.body,
    required this.isFinished,
    required this.labels,
  });

  final int orderId;
  final String orderKey;
  final String groupKey;
  final int notificationId;
  final String orderType;
  final String serviceName;
  final String effectiveStatus;
  final int stepIndex;
  final int stepTotal;
  final String title;
  final String body;
  final bool isFinished;
  final List<String> labels;

  bool get isStore => OrderProgressNotificationMapper.isStoreService(serviceName);
}

class OrderProgressNotificationMapper {
  static bool isStoreService(String? serviceName) {
    final normalized = serviceName?.trim().toLowerCase() ?? '';
    return normalized == 'store' || normalized == 'stores';
  }

  static const Set<String> _arrivalProgressStatuses = {
    'arrived',
    'waiting',
    'arrived_waiting',
    'driver_arrived',
    'at_destination',
    'at_pickup',
    'waiting_at_destination',
    'waiting_at_pickup',
  };

  static OrderProgressSnapshot fromPayload(
    Map<String, dynamic> data, {
    required String defaultAppTitle,
    String? titleOverride,
    String? bodyOverride,
    int Function(String key)? stableInt,
  }) {
    final orderId = _asInt(data['order_id']) ?? 0;
    final orderIdText = orderId > 0 ? orderId.toString() : '';
    final collapseId = data['collapse_id']?.toString().trim();
    final orderKey = collapseId != null && collapseId.isNotEmpty
        ? collapseId
        : data['notification_key']?.toString().trim().isNotEmpty == true
            ? data['notification_key']!.toString().trim()
            : 'order_$orderIdText';
    final androidGroup = data['android_group']?.toString().trim();
    final groupKey = androidGroup != null && androidGroup.isNotEmpty
        ? androidGroup
        : 'order_updates';
    final explicitNotificationId =
        _asInt(data['android_notification_id']) ?? orderId;
    final notificationId = _safeAndroidNotifyId(
      explicitNotificationId > 0
          ? explicitNotificationId
          : (stableInt?.call(orderKey) ?? orderId),
    );

    final orderType = (data['order_type'] ?? data['service_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final serviceName =
        data['service_name']?.toString().trim().toLowerCase() ?? '';

    final isStore = isStoreService(serviceName);
    final resolvedStepTotal = TaxiOrderState.isTaxiOrderType(orderType)
        ? TaxiOrderState.stepTotal
        : (_asInt(data['step_total']) ??
            defaultStepTotalForOrderType(orderType, isStore: isStore));
    final effectiveStatus = effectiveStatusForProgress(
      data,
      orderType: orderType,
      bodyOverride: bodyOverride,
    );
    final resolvedStepIndex = TaxiOrderState.isTaxiOrderType(orderType)
        ? TaxiOrderState.stepIndexForPayload(
            data,
            bodyOverride: bodyOverride,
          )
        : (_asInt(data['step_index']) ??
            statusToStepIndex(
              effectiveStatus,
              resolvedStepTotal,
              orderType: orderType,
              serviceName: serviceName,
            ));

    final clampedTotal = resolvedStepTotal <= 0
        ? defaultStepTotalForOrderType(orderType, isStore: isStore)
        : resolvedStepTotal;
    final clampedStep = resolvedStepIndex.clamp(0, clampedTotal).toInt();
    final title = resolveDisplayTitle(
      data,
      titleOverride: titleOverride,
      defaultAppTitle: defaultAppTitle,
    );
    final body = resolveDisplayBody(
      data,
      bodyOverride: bodyOverride,
      orderType: orderType,
    );
    final isFinished = isTerminalOrderStatus(effectiveStatus);
    final labels = stepperLabelsForOrderType(orderType, isStore: isStore);

    return OrderProgressSnapshot(
      orderId: orderId,
      orderKey: orderKey,
      groupKey: groupKey,
      notificationId: notificationId,
      orderType: orderType,
      serviceName: serviceName,
      effectiveStatus: effectiveStatus,
      stepIndex: clampedStep,
      stepTotal: clampedTotal,
      title: title,
      body: body,
      isFinished: isFinished,
      labels: labels,
    );
  }

  static String effectiveStatusForProgress(
    Map<String, dynamic> data, {
    String? orderType,
    String? bodyOverride,
  }) {
    final type = (orderType ??
            data['order_type'] ??
            data['service_type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    final rawStatus =
        data['status']?.toString() ?? data['order_status']?.toString() ?? '';
    final rawDispatch = data['dispatch_status']?.toString() ??
        data['driver_status']?.toString() ??
        '';
    if (type == 'shipping') {
      return ShippingOrderState.resolveEffectiveStatus(rawStatus, rawDispatch);
    }
    final main = canonicalStatus(rawStatus);

    if (TaxiOrderState.isTaxiOrderType(type)) {
      return TaxiOrderState.resolveNotificationStatus(
        data,
        bodyOverride: bodyOverride,
      );
    }

    final dispatch = canonicalStatus(
      data['dispatch_status']?.toString() ??
          data['driver_status']?.toString() ??
          '',
    );
    if (_arrivalProgressStatuses.contains(main)) return main;
    if (_arrivalProgressStatuses.contains(dispatch)) return dispatch;
    if (main.isNotEmpty) return main;
    return dispatch;
  }

  static String resolveDisplayTitle(
    Map<String, dynamic> data, {
    String? titleOverride,
    required String defaultAppTitle,
  }) {
    final fromOverride = titleOverride?.trim();
    if (fromOverride != null && fromOverride.isNotEmpty) return fromOverride;

    final fromPayload = data['title']?.toString().trim();
    if (fromPayload != null && fromPayload.isNotEmpty) return fromPayload;

    return defaultAppTitle;
  }

  static String resolveDisplayBody(
    Map<String, dynamic> data, {
    String? bodyOverride,
    String? orderType,
  }) {
    final fromOverride = bodyOverride?.trim();
    if (fromOverride != null && fromOverride.isNotEmpty) return fromOverride;

    final fromPayload = data['body']?.toString().trim();
    if (fromPayload != null && fromPayload.isNotEmpty) return fromPayload;

    final type = (orderType ??
            data['order_type'] ??
            data['service_type'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (TaxiOrderState.isTaxiOrderType(type)) {
      return TaxiOrderState.defaultBackendMessage(
        TaxiOrderState.resolveNotificationStatus(
          data,
          bodyOverride: bodyOverride,
        ),
      );
    }

    final serviceName =
        data['service_name']?.toString().trim().toLowerCase() ?? '';
    return defaultStatusLabel(
      effectiveStatusForProgress(data, orderType: type, bodyOverride: bodyOverride),
      isStore: isStoreService(serviceName),
    );
  }

  /// 5-step shipping timeline in [TransportOrderTrackingScreen].
  static int shippingTimelineStageIndex(
    String statusRaw, {
    String dispatchStatusRaw = '',
  }) {
    return ShippingOrderState.timelineStageIndex(
      statusRaw,
      dispatchStatusRaw: dispatchStatusRaw,
    );
  }

  static int statusToStepIndex(
    String status,
    int stepTotal, {
    String orderType = '',
    String? serviceName,
  }) {
    final normalizedStatus = canonicalStatus(status);
    final max = stepTotal <= 0 ? 5 : stepTotal;
    final isStore = isStoreService(serviceName);
    final type = orderType == 'shipping'
        ? 'shipping'
        : orderType == 'taxi'
            ? 'taxi'
            : 'food';

    int mapFood(String s) {
      if (isStore) {
        switch (s) {
          case 'pending':
          case 'no_driver':
            return 0;
          case 'accepted':
          case 'preparing':
          case 'ready':
            return 1;
          case 'assigned':
          case 'on_the_way_to_pickup':
          case 'picked_up':
            return 2;
          case 'on_way':
          case 'arrived':
          case 'waiting':
          case 'arrived_waiting':
          case 'driver_arrived':
          case 'at_destination':
          case 'at_pickup':
          case 'waiting_at_destination':
          case 'waiting_at_pickup':
            return 3;
          case 'delivered':
          case 'completed':
          case 'cancelled':
          case 'canceled':
            return max;
          default:
            return 1;
        }
      }

      switch (s) {
        case 'pending':
        case 'no_driver':
          return 0;
        case 'accepted':
          return 1;
        case 'preparing':
        case 'ready':
          return 2;
        case 'assigned':
        case 'on_the_way_to_pickup':
        case 'picked_up':
          return 3;
        case 'on_way':
          return max > 4 ? 4 : (max - 1).clamp(1, max);
        case 'arrived':
        case 'waiting':
        case 'arrived_waiting':
        case 'driver_arrived':
        case 'at_destination':
        case 'at_pickup':
        case 'waiting_at_destination':
        case 'waiting_at_pickup':
          return max > 4 ? 4 : (max - 1).clamp(1, max);
        case 'delivered':
        case 'completed':
        case 'cancelled':
        case 'canceled':
          return max;
        default:
          return 1;
      }
    }

    int mapShipping(String s) {
      final stage = ShippingOrderState.mapStageIndex(s);
      if (stage < 0) return 0;
      if (stage >= max) return max;
      return stage;
    }

    int mapTaxi(String s) => TaxiOrderState.mapTaxi(s);

    switch (type) {
      case 'shipping':
        return mapShipping(normalizedStatus).clamp(0, max);
      case 'taxi':
        return mapTaxi(normalizedStatus).clamp(0, max);
      default:
        return mapFood(normalizedStatus).clamp(0, max);
    }
  }

  static String defaultStatusLabel(
    String statusRaw, {
    bool isStore = false,
  }) {
    final status = canonicalStatus(statusRaw);
    switch (status) {
      case 'pending':
        return 'notifications.statusPending'.tr;
      case 'accepted':
        return 'notifications.statusAccepted'.tr;
      case 'on_the_way_to_pickup':
        return 'notifications.statusOnWayToPickup'.tr;
      case 'picked_up':
        return 'notifications.statusPickedUp'.tr;
      case 'on_way':
        return 'notifications.statusOnWay'.tr;
      case 'preparing':
        if (isStore) return 'notifications.statusAccepted'.tr;
        return 'notifications.statusPreparing'.tr;
      case 'ready':
        return 'notifications.statusReady'.tr;
      case 'arrived':
      case 'waiting':
      case 'arrived_waiting':
      case 'driver_arrived':
      case 'at_destination':
      case 'at_pickup':
      case 'waiting_at_destination':
      case 'waiting_at_pickup':
        return 'notifications.statusDriverWaiting'.tr;
      case 'no_driver':
        return 'notifications.statusNoDriver'.tr;
      case 'delivered':
      case 'completed':
        return 'notifications.statusDelivered'.tr;
      case 'cancelled':
      case 'canceled':
        return 'notifications.statusCancelled'.tr;
      default:
        return 'notifications.statusGenericUpdate'.tr;
    }
  }

  static bool isTerminalOrderStatus(String statusRaw) {
    final status = canonicalStatus(statusRaw);
    return status == 'delivered' ||
        status == 'completed' ||
        status == 'cancelled' ||
        status == 'canceled';
  }

  static String canonicalStatus(String raw) {
    var s = _normalizeStatus(raw);
    if (s.isEmpty) return s;

    if (s.startsWith('food_')) s = s.substring(5);
    if (s.startsWith('order_')) s = s.substring(6);

    switch (s) {
      case 'driver_assigned':
      case 'accepted_by_driver':
        return 'assigned';
      // "dispatching" means the backend is still searching — not that a driver
      // has been assigned. Keep it distinct from assigned/accepted.
      case 'dispatching':
      case 'searching':
      case 'searching_for_driver':
      case 'looking_for_driver':
        return 'pending';
      case 'preparing_food':
      case 'being_prepared':
        return 'preparing';
      case 'pickup':
      case 'pickedup':
        return 'picked_up';
      case 'on_the_way':
      case 'on_the_way_to_customer':
      case 'on_the_way_to_dropoff':
      case 'out_for_delivery':
      case 'in_transit':
      case 'heading_to_customer':
        return 'on_way';
      case 'delivered_to_customer':
        return 'delivered';
      case 'complete':
        return 'completed';
      default:
        return s;
    }
  }

  static String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  static int _safeAndroidNotifyId(int id) {
    if (id == 0) return 1;
    return id & 0x7fffffff;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
