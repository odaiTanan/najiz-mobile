import 'package:najiz_go_express/core/utils/order_dispatch_utils.dart';
import 'package:najiz_go_express/features/orders/models/user_order.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';

/// Shared order snapshot for cold-start resume (never creates an order).
class TaxiColdStartOrderSnapshot {
  final int orderId;
  final String orderNumber;
  final String status;
  final String dispatchStatus;
  final double lat;
  final double lng;

  const TaxiColdStartOrderSnapshot({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.dispatchStatus,
    required this.lat,
    required this.lng,
  });
}

/// Compatibility alias used by TaxiBookingScreen Finding Driver resume.
typedef TaxiSearchingResumeOrder = TaxiColdStartOrderSnapshot;

enum TaxiColdStartKind { none, searching, assigned, noDriver }

class TaxiColdStartIntent {
  final TaxiColdStartKind kind;
  final TaxiColdStartOrderSnapshot? order;

  const TaxiColdStartIntent._(this.kind, this.order);

  const TaxiColdStartIntent.none() : this._(TaxiColdStartKind.none, null);

  const TaxiColdStartIntent.searching(TaxiColdStartOrderSnapshot order)
      : this._(TaxiColdStartKind.searching, order);

  const TaxiColdStartIntent.assigned(TaxiColdStartOrderSnapshot order)
      : this._(TaxiColdStartKind.assigned, order);

  const TaxiColdStartIntent.noDriver(TaxiColdStartOrderSnapshot order)
      : this._(TaxiColdStartKind.noDriver, order);
}

/// Cold-start only: classify the newest active taxi from the backend.
/// Does not navigate and does not create orders.
class TaxiColdStartRestorer {
  TaxiColdStartRestorer._();

  static bool _handledThisProcess = false;

  /// Resolves resume intent from current backend state.
  /// Guests / errors / terminal orders → [TaxiColdStartIntent.none].
  static Future<TaxiColdStartIntent> resolve({
    required String? token,
    OrdersRepository? repository,
  }) async {
    if (_handledThisProcess) return const TaxiColdStartIntent.none();
    final authToken = token?.trim() ?? '';
    if (authToken.isEmpty) {
      _handledThisProcess = true;
      return const TaxiColdStartIntent.none();
    }

    final ordersRepository = repository ?? OrdersRepository();
    try {
      final page = await ordersRepository.getMyOrdersPage(token: authToken);
      final taxis = page.items
          .where((o) => o.type.trim().toLowerCase() == 'taxi')
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse(a.createdAt);
          final bd = DateTime.tryParse(b.createdAt);
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });

      UserOrder? candidate;
      for (final order in taxis) {
        if (!_isTerminalStatus(order.status)) {
          candidate = order;
          break;
        }
      }

      if (candidate == null) {
        _handledThisProcess = true;
        return const TaxiColdStartIntent.none();
      }

      // Backend wins: refresh current status before choosing UI.
      final latest = await ordersRepository.getOrderById(
        token: authToken,
        orderId: candidate.id,
      );
      final status = (latest['status'] ?? candidate.status).toString();
      final dispatchStatus =
          (latest['dispatch_status'] ?? candidate.dispatchStatus).toString();

      if (_isTerminalStatus(status)) {
        _handledThisProcess = true;
        return const TaxiColdStartIntent.none();
      }

      final snapshot = TaxiColdStartOrderSnapshot(
        orderId: candidate.id,
        orderNumber: candidate.orderNumber.isNotEmpty
            ? candidate.orderNumber
            : (latest['order_number'] ?? 'ORD-${candidate.id}').toString(),
        status: status,
        dispatchStatus: dispatchStatus,
        lat: candidate.lat,
        lng: candidate.lng,
      );

      _handledThisProcess = true;

      if (OrderDispatchUtils.isNoDriver(
        status: status,
        dispatchStatus: dispatchStatus,
      )) {
        return TaxiColdStartIntent.noDriver(snapshot);
      }

      if (OrderDispatchUtils.isDriverAssigned(
        kind: OrderDispatchServiceKind.taxi,
        status: status,
        dispatchStatus: dispatchStatus,
      )) {
        return TaxiColdStartIntent.assigned(snapshot);
      }

      if (OrderDispatchUtils.isSearchingForDriver(
        status: status,
        dispatchStatus: dispatchStatus,
      )) {
        return TaxiColdStartIntent.searching(snapshot);
      }

      return const TaxiColdStartIntent.none();
    } catch (_) {
      _handledThisProcess = true;
      return const TaxiColdStartIntent.none();
    }
  }

  static bool _isTerminalStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'completed' ||
        normalized == 'cancelled' ||
        normalized == 'canceled';
  }
}
