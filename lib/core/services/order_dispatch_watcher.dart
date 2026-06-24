import 'dart:async';

import 'package:najiz_go_express/core/services/order_websocket_service.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';

typedef OrderDispatchUpdateHandler = void Function(
  String status,
  String dispatchStatus,
  Map<String, dynamic> payload,
);

/// Live order dispatch updates via WebSocket with HTTP polling fallback
/// (same channel used by order tracking screens).
class OrderDispatchWatcher {
  OrderDispatchWatcher({
    required this.token,
    required this.orderId,
    required this.onUpdate,
    this.initialStatus = '',
    this.initialDispatchStatus = '',
    OrdersRepository? repository,
    this.pollInterval = const Duration(seconds: 3),
  }) : _repository = repository ?? OrdersRepository();

  final String token;
  final int orderId;
  final String initialStatus;
  final String initialDispatchStatus;
  final OrderDispatchUpdateHandler onUpdate;
  final Duration pollInterval;

  final OrdersRepository _repository;

  OrderWebSocketService? _wsService;
  Timer? _pollTimer;
  bool _disposed = false;
  bool _pollInFlight = false;
  String _latestStatus = '';
  String _latestDispatchStatus = '';

  Future<void> start() async {
    _latestStatus = initialStatus;
    _latestDispatchStatus = initialDispatchStatus;

    _wsService = OrderWebSocketService(token: token);
    try {
      await _wsService!.subscribeToOrder(
        orderId: orderId,
        onOrderUpdated: _handlePayload,
      );
    } catch (_) {
      // Polling remains the fallback when websocket auth/connect fails.
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) => _pollOnce());
    unawaited(_pollOnce());
  }

  void _handlePayload(Map<String, dynamic> payload) {
    if (_disposed) return;
    final status = (payload['status'] ?? _latestStatus).toString();
    final dispatchStatus =
        (payload['dispatch_status'] ?? _latestDispatchStatus).toString();
    _emit(status, dispatchStatus, payload);
  }

  Future<void> _pollOnce() async {
    if (_disposed || _pollInFlight) return;
    _pollInFlight = true;
    try {
      final latest = await _repository.getOrderById(
        token: token,
        orderId: orderId,
      );
      if (_disposed || latest.isEmpty) return;
      final status = (latest['status'] ?? _latestStatus).toString();
      final dispatchStatus =
          (latest['dispatch_status'] ?? _latestDispatchStatus).toString();
      _emit(status, dispatchStatus, latest);
    } catch (_) {
      // Transient polling errors should not break the waiting UI.
    } finally {
      _pollInFlight = false;
    }
  }

  void _emit(
    String status,
    String dispatchStatus,
    Map<String, dynamic> payload,
  ) {
    if (_disposed) return;
    final statusChanged = status != _latestStatus;
    final dispatchChanged = dispatchStatus != _latestDispatchStatus;
    if (!statusChanged && !dispatchChanged && payload.isEmpty) return;

    _latestStatus = status;
    _latestDispatchStatus = dispatchStatus;
    onUpdate(status, dispatchStatus, payload);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    await _wsService?.disconnect();
    _wsService = null;
  }
}
