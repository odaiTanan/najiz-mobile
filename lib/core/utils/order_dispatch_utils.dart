import 'package:najiz_go_express/core/services/order_progress_notification_mapper.dart';
import 'package:najiz_go_express/core/services/taxi_order_state.dart';

enum OrderDispatchServiceKind { taxi, delivery }

class OrderDispatchUtils {
  OrderDispatchUtils._();

  static String normalize(String raw) {
    return OrderProgressNotificationMapper.canonicalStatus(raw);
  }

  static String normalizeRaw(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  /// True while the backend is still looking for a driver (not yet assigned).
  static bool isDispatchSearching({
    required String status,
    required String dispatchStatus,
  }) {
    if (isNoDriver(status: status, dispatchStatus: dispatchStatus)) {
      return false;
    }
    if (isDriverAssigned(
      kind: OrderDispatchServiceKind.delivery,
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      return false;
    }

    final orderStatus = normalizeRaw(status);
    const terminalStatuses = {
      'cancelled',
      'canceled',
      'delivered',
      'completed',
      'rejected',
    };
    return !terminalStatuses.contains(orderStatus);
  }

  static bool isNoDriver({
    required String status,
    required String dispatchStatus,
  }) {
    final s = normalize(status);
    final d = normalize(dispatchStatus);
    return s == 'no_driver' || d == 'no_driver';
  }

  static bool isDriverAssigned({
    required OrderDispatchServiceKind kind,
    required String status,
    required String dispatchStatus,
  }) {
    switch (kind) {
      case OrderDispatchServiceKind.taxi:
        return _isTaxiDriverAssigned(status: status, dispatchStatus: dispatchStatus);
      case OrderDispatchServiceKind.delivery:
        return _isDeliveryDriverAssigned(
          status: status,
          dispatchStatus: dispatchStatus,
        );
    }
  }

  static bool _isTaxiDriverAssigned({
    required String status,
    required String dispatchStatus,
  }) {
    final normalized = TaxiOrderState.normalizeStatus(status);
    if (!TaxiOrderState.isAllowed(normalized)) {
      final dispatch = normalize(dispatchStatus);
      return dispatch == 'accepted' || dispatch == 'assigned';
    }
    return normalized != 'pending' &&
        normalized != 'cancelled' &&
        normalized != 'canceled' &&
        normalized != 'no_driver';
  }

  static bool _isDeliveryDriverAssigned({
    required String status,
    required String dispatchStatus,
  }) {
    if (isNoDriver(status: status, dispatchStatus: dispatchStatus)) {
      return false;
    }

    final orderStatus = normalizeRaw(status);
    const driverActiveStatuses = {
      'on_the_way_to_pickup',
      'heading_to_pickup',
      'driver_heading_to_pickup',
      'picked_up',
      'on_way',
      'delivered',
      'completed',
      'arrived',
      'waiting',
      'arrived_waiting',
      'driver_arrived',
      'at_destination',
      'at_pickup',
      'waiting_at_destination',
      'waiting_at_pickup',
      'food_driver_assigned',
      'driver_assigned',
    };
    if (driverActiveStatuses.contains(orderStatus)) return true;

    final dispatch = normalizeRaw(dispatchStatus);
    return dispatch == 'accepted' || dispatch == 'assigned';
  }

  static bool isSearchingForDriver({
    required String status,
    required String dispatchStatus,
  }) {
    if (isNoDriver(status: status, dispatchStatus: dispatchStatus)) {
      return false;
    }
    if (isDriverAssigned(
      kind: OrderDispatchServiceKind.taxi,
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      return false;
    }
    if (isDriverAssigned(
      kind: OrderDispatchServiceKind.delivery,
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      return false;
    }

    return isDispatchSearching(status: status, dispatchStatus: dispatchStatus);
  }
}

/// Ignores [no_driver] on the first snapshot (create-order payload) and only
/// fires after the backend transitions into [no_driver] while dispatch is live.
class OrderDispatchTransitionTracker {
  bool _initialized = false;
  String _lastStatus = '';
  String _lastDispatch = '';

  bool shouldHandleNoDriver({
    required String status,
    required String dispatchStatus,
  }) {
    final isNoDriver = OrderDispatchUtils.isNoDriver(
      status: status,
      dispatchStatus: dispatchStatus,
    );

    if (!isNoDriver) {
      _initialized = true;
      _lastStatus = status;
      _lastDispatch = dispatchStatus;
      return false;
    }

    if (!_initialized) {
      _initialized = true;
      _lastStatus = status;
      _lastDispatch = dispatchStatus;
      return false;
    }

    final wasAlreadyNoDriver = OrderDispatchUtils.isNoDriver(
      status: _lastStatus,
      dispatchStatus: _lastDispatch,
    );
    _lastStatus = status;
    _lastDispatch = dispatchStatus;
    return !wasAlreadyNoDriver;
  }
}
