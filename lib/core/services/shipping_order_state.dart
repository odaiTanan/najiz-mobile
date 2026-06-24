import 'package:najiz_go_express/core/utils/order_dispatch_utils.dart';

/// Shipping lifecycle aligned with backend Order Socket events:
/// accepted → on_the_way_to_pickup → picked_up → on_way → delivered
class ShippingOrderState {
  ShippingOrderState._();

  static const int stepTotal = 5;

  static const Set<String> allowedStatuses = {
    'pending',
    'accepted',
    'on_the_way_to_pickup',
    'picked_up',
    'on_way',
    'delivered',
    'cancelled',
    'canceled',
    'no_driver',
  };

  static const List<String> timelineLabelKeys = [
    'tracking.shippingStepAccepted',
    'tracking.shippingStepHeadingToPickup',
    'tracking.shippingStepPickedUp',
    'tracking.shippingStepOnWayToDelivery',
    'tracking.shippingStepDelivered',
  ];

  static const Map<String, String> _backendMessages = {
    'pending': 'جاري البحث عن سائق',
    'accepted': 'تم القبول',
    'on_the_way_to_pickup': 'في الطريق للاستلام',
    'picked_up': 'تم الاستلام',
    'on_way': 'في الطريق للتوصيل',
    'delivered': 'تم التوصيل',
    'cancelled': 'تم إلغاء الطلب',
  };

  static String normalizeRaw(String? raw) {
    if (raw == null) return '';
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  /// Maps DB / socket variants to canonical shipping statuses.
  static String normalizeStatus(String raw) {
    final s = normalizeRaw(raw);
    if (s.isEmpty) return s;

    switch (s) {
      case 'assigned':
      case 'driver_assigned':
      case 'accepted_by_driver':
        return 'accepted';
      case 'heading_to_pickup':
      case 'driver_heading_to_pickup':
      case 'heading_for_pickup':
      case 'en_route_to_pickup':
        return 'on_the_way_to_pickup';
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
      case 'complete':
      case 'completed':
        return 'delivered';
      case 'canceled':
        return 'cancelled';
      default:
        return s;
    }
  }

  static bool isShippingOrderType(String orderType) {
    return orderType.trim().toLowerCase() == 'shipping';
  }

  /// Resolves the furthest known stage from order [status] and [dispatchStatus].
  static String resolveEffectiveStatus(String? status, String? dispatchStatus) {
    if (OrderDispatchUtils.isDispatchSearching(
      status: status ?? '',
      dispatchStatus: dispatchStatus ?? '',
    )) {
      return 'pending';
    }

    final normalizedStatus = normalizeStatus(status ?? '');
    final normalizedDispatch = normalizeRaw(dispatchStatus);

    final candidates = <String>[];
    if (normalizedStatus.isNotEmpty) candidates.add(normalizedStatus);
    if (normalizedDispatch == 'accepted' || normalizedDispatch == 'assigned') {
      candidates.add('accepted');
    }

    if (candidates.isEmpty) return 'pending';

    var best = candidates.first;
    var bestRank = _stageRank(best);
    for (final candidate in candidates.skip(1)) {
      final rank = _stageRank(candidate);
      if (rank > bestRank) {
        best = candidate;
        bestRank = rank;
      }
    }
    return best;
  }

  static String resolveFromPayload(Map<String, dynamic> data) {
    return resolveEffectiveStatus(
      data['status']?.toString() ?? data['order_status']?.toString(),
      data['dispatch_status']?.toString() ?? data['driver_status']?.toString(),
    );
  }

  /// Timeline index for [TransportOrderTrackingScreen] (-1 while searching).
  static int timelineStageIndex(
    String statusRaw, {
    String dispatchStatusRaw = '',
  }) {
    if (OrderDispatchUtils.isDispatchSearching(
      status: statusRaw,
      dispatchStatus: dispatchStatusRaw,
    )) {
      return -1;
    }
    return mapStageIndex(
      resolveEffectiveStatus(statusRaw, dispatchStatusRaw),
    );
  }

  /// Inclusive stage index (0..4) for the 5 shipping steps.
  static int mapStageIndex(String statusRaw) {
    switch (normalizeStatus(statusRaw)) {
      case 'pending':
      case 'no_driver':
        return -1;
      case 'accepted':
      case 'assigned':
      case 'preparing':
        return 0;
      case 'on_the_way_to_pickup':
      case 'at_pickup':
      case 'waiting_at_pickup':
        return 1;
      case 'picked_up':
        return 2;
      case 'on_way':
      case 'arrived':
      case 'waiting':
      case 'arrived_waiting':
      case 'driver_arrived':
      case 'at_destination':
      case 'waiting_at_destination':
      case 'near_destination':
        return 3;
      case 'delivered':
      case 'completed':
        return 4;
      case 'cancelled':
      case 'canceled':
        return 4;
      default:
        return -1;
    }
  }

  static int _stageRank(String statusRaw) => mapStageIndex(statusRaw);

  static String defaultBackendMessage(String statusRaw) {
    final key = normalizeStatus(statusRaw);
    if (key == 'cancelled') {
      return _backendMessages['cancelled']!;
    }
    return _backendMessages[key] ?? 'تم تحديث حالة طلب الشحن';
  }

  static String titleKeyForStage(int stageIndex) {
    switch (stageIndex) {
      case 4:
        return 'tracking.shippingStepDelivered';
      case 3:
        return 'tracking.shippingStepOnWayToDelivery';
      case 2:
        return 'tracking.shippingStepPickedUp';
      case 1:
        return 'tracking.shippingStepHeadingToPickup';
      case 0:
        return 'tracking.shippingStepAccepted';
      default:
        return 'tracking.pending';
    }
  }

  static bool isDelivered(String statusRaw) {
    final status = normalizeStatus(statusRaw);
    return status == 'delivered' || status == 'completed';
  }

  static bool isOnWayToDelivery(String statusRaw, {String dispatchStatusRaw = ''}) {
    return mapStageIndex(
          resolveEffectiveStatus(statusRaw, dispatchStatusRaw),
        ) >=
        3;
  }

  static bool isPickedUp(String statusRaw, {String dispatchStatusRaw = ''}) {
    return mapStageIndex(
          resolveEffectiveStatus(statusRaw, dispatchStatusRaw),
        ) >=
        2;
  }
}
