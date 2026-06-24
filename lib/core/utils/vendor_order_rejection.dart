import 'package:najiz_go_express/core/services/order_progress_notification_mapper.dart';

/// Detects vendor-side rejection for restaurant / store delivery orders.
class VendorOrderRejectionUtils {
  VendorOrderRejectionUtils._();

  static const Set<String> _vendorCancelledByValues = {
    'vendor',
    'restaurant',
    'store',
    'merchant',
    'shop',
    'seller',
  };

  static const Set<String> _vendorReasonHints = {
    'vendor',
    'restaurant',
    'store',
    'merchant',
    'reject',
    'rejected',
    'refused',
    'declined',
    'رفض',
    'مرفوض',
    'المطعم',
    'المتجر',
  };

  static const Set<String> _idleDispatchStatuses = {
    '',
    'pending',
    'dispatching',
    'searching',
  };

  static const Set<String> _preAcceptanceStatuses = {
    '',
    'pending',
    'no_driver',
  };

  static String _normalize(String raw) {
    return OrderProgressNotificationMapper.canonicalStatus(raw);
  }

  static bool isVendorRejection({
    required String status,
    required String dispatchStatus,
    Map<String, dynamic>? payload,
    String? lastNonCancelledStatus,
  }) {
    final normalizedStatus = _normalize(status);
    if (!_isCancelledOrRejected(normalizedStatus)) return false;

    if (normalizedStatus == 'rejected') return true;

    if (payload != null && _payloadIndicatesVendorRejection(payload)) {
      return true;
    }

    return _isEarlyVendorCancellation(
      dispatchStatus: dispatchStatus,
      lastNonCancelledStatus: lastNonCancelledStatus,
    );
  }

  static bool _isCancelledOrRejected(String status) {
    return status == 'cancelled' || status == 'canceled' || status == 'rejected';
  }

  static bool _payloadIndicatesVendorRejection(Map<String, dynamic> payload) {
    for (final key in const [
      'cancelled_by',
      'canceled_by',
      'cancelled_by_type',
      'canceled_by_type',
      'cancel_source',
      'cancellation_source',
    ]) {
      final value = _normalize(payload[key]?.toString() ?? '');
      if (_vendorCancelledByValues.contains(value)) return true;
    }

    for (final key in const [
      'cancellation_reason',
      'cancel_reason',
      'reason',
      'status_reason',
      'status_label',
      'body',
      'message',
    ]) {
      final text = payload[key]?.toString().trim().toLowerCase() ?? '';
      if (text.isEmpty) continue;
      if (_vendorReasonHints.any(text.contains)) return true;
    }

    final event = _normalize(
      payload['event']?.toString() ?? payload['notification_type']?.toString() ?? '',
    );
    if (event.contains('vendor_reject') ||
        event.contains('restaurant_reject') ||
        event.contains('store_reject') ||
        event.contains('order_rejected')) {
      return true;
    }

    return false;
  }

  /// Cancelled while still awaiting vendor acceptance / before dispatch moved.
  static bool _isEarlyVendorCancellation({
    required String dispatchStatus,
    String? lastNonCancelledStatus,
  }) {
    final dispatch = _normalize(dispatchStatus);
    if (!_idleDispatchStatuses.contains(dispatch)) return false;

    final lastActive = _normalize(lastNonCancelledStatus ?? '');
    return _preAcceptanceStatuses.contains(lastActive);
  }
}
