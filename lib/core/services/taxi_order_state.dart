/// Taxi lifecycle aligned with backend [SendOrderStatusOneSignalNotification].

class TaxiOrderState {

  TaxiOrderState._();



  /// Mirrors PHP `TAXI_ALLOWED_STATES`.

  static const Set<String> notificationAllowedStatuses = {

    'pending',

    'accepted',

    'on_the_way_to_pickup',

    'on_way',

    'delivered',

    'cancelled',

  };



  static const Set<String> allowedStatuses = {

    ...notificationAllowedStatuses,

    'canceled',

  };



  static const int stepTotal = 5;



  static const Map<String, String> _backendTaxiMessages = {

    'pending': 'تم استلام طلبك وهو قيد المراجعة',

    'accepted': 'تم قبول الطلب',

    'on_the_way_to_pickup': 'تم قبول الطلب والسائق متجه إليك',

    'on_way': 'بدأت الرحلة',

    'delivered': 'تم التوصيل',

    'cancelled': 'تم إلغاء الطلب',

  };



  static const Set<String> _arrivalHints = {

    'arrived',

    'waiting',

    'arrived_waiting',

    'driver_arrived',

    'at_destination',

    'at_pickup',

    'waiting_at_destination',

    'waiting_at_pickup',

    'picked_up',

    'preparing',

  };



  /// UI / tracking normalization (maps DB variants to canonical steps).

  static String normalizeStatus(String raw) {

    final s = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

    if (s.isEmpty) return s;



    switch (s) {

      case 'assigned':

      case 'driver_assigned':

      case 'accepted_by_driver':

      case 'dispatching':

        return 'accepted';

      case 'heading_to_pickup':

      case 'driver_heading_to_pickup':

      case 'heading_for_pickup':

      case 'en_route_to_pickup':

        return 'on_the_way_to_pickup';

      case 'on_the_way':

      case 'on_the_way_to_customer':

      case 'on_the_way_to_dropoff':

      case 'picked_up':

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



  /// Mirrors PHP `normalizeStatus()` — lowercase + underscores only.

  static String? normalizeRaw(String? raw) {

    if (raw == null) return null;

    final normalized = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

    if (normalized.isEmpty) return null;

    return normalized;

  }



  /// Mirrors PHP `resolveStatusForMessage()`.

  static String resolveStatusForMessage(String? status, String? dispatchStatus) {

    final normalizedStatus = normalizeRaw(status);

    final normalizedDispatch = normalizeRaw(dispatchStatus);



    if (normalizedStatus != null && _arrivalHints.contains(normalizedStatus)) {

      return normalizedStatus;

    }

    if (normalizedDispatch != null && _arrivalHints.contains(normalizedDispatch)) {

      return normalizedDispatch;

    }

    return normalizedStatus ?? normalizedDispatch ?? '';

  }



  /// Backend builds OneSignal `contents` from [resolveStatusForMessage], but `data`

  /// carries raw DB fields — infer the effective taxi state from the push body.

  static String? inferStatusFromBackendMessage(String? body) {

    final text = body?.trim();

    if (text == null || text.isEmpty) return null;

    for (final entry in _backendTaxiMessages.entries) {

      if (entry.value == text) return entry.key;

    }

    for (final entry in _legacyTaxiMessageToStatus.entries) {

      if (entry.key == text) return entry.value;

    }

    return null;

  }



  static const Map<String, String> _legacyTaxiMessageToStatus = {

    'السائق في الطريق إليك': 'on_the_way_to_pickup',

    'السائق متجه للاستلام': 'on_the_way_to_pickup',

  };



  static String resolveNotificationStatus(

    Map<String, dynamic> data, {

    String? bodyOverride,

  }) {

    final fromBody = inferStatusFromBackendMessage(

      bodyOverride ?? data['body']?.toString(),

    );

    if (fromBody != null && isNotificationAllowed(fromBody)) {

      return fromBody;

    }



    return resolveStatusForMessage(

      data['status']?.toString() ?? data['order_status']?.toString(),

      data['dispatch_status']?.toString() ?? data['driver_status']?.toString(),

    );

  }



  static bool isNotificationAllowed(String status) {

    final normalized = normalizeRaw(status) ?? '';

    if (normalized.isEmpty) return false;

    if (notificationAllowedStatuses.contains(normalized)) return true;

    return normalized == 'canceled';

  }



  static bool isAllowed(String status) {

    final normalized = normalizeStatus(status);

    if (normalized.isEmpty) return false;

    return allowedStatuses.contains(normalized);

  }



  static bool isTaxiOrderType(String orderType) {

    return orderType.trim().toLowerCase() == 'taxi';

  }



  static bool shouldIgnorePayload(

    Map<String, dynamic> data, {

    String? bodyOverride,

  }) {

    final orderType =

        (data['order_type'] ?? data['service_type'] ?? '').toString();

    if (!isTaxiOrderType(orderType)) return false;

    final status = resolveNotificationStatus(data, bodyOverride: bodyOverride);

    return !isNotificationAllowed(status);

  }



  static String effectiveStatus(String rawStatus) {

    return normalizeStatus(rawStatus);

  }



  static int stepIndexFor(String rawStatus) {

    return mapTaxi(rawStatus);

  }



  static int stepIndexForPayload(

    Map<String, dynamic> data, {

    String? bodyOverride,

  }) {

    return mapTaxi(

      resolveNotificationStatus(data, bodyOverride: bodyOverride),

    );

  }



  static String defaultBackendMessage(String statusRaw) {

    final key = normalizeRaw(statusRaw) ?? '';

    if (key == 'canceled') {

      return _backendTaxiMessages['cancelled']!;

    }

    return _backendTaxiMessages[key] ?? 'تم تحديث حالة طلبك';

  }



  /// Inclusive stepper index: `on_the_way_to_pickup` → 2 activates steps 0..2
  /// (placed + accepted + heading) because orders may skip a lone `accepted` push.
  static int mapTaxi(String status) {

    switch (normalizeRaw(status) ?? normalizeStatus(status)) {

      case 'pending':

        return 0;

      case 'accepted':

        return 1;

      case 'on_the_way_to_pickup':

        return 2;

      case 'on_way':

        return 3;

      case 'delivered':

        return 4;

      case 'cancelled':

      case 'canceled':

        return 4;

      default:

        return 1;

    }

  }

}


