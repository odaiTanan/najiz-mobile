import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/models/paginated_page.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/orders/errors/orders_api_exception.dart';
import 'package:najiz_go_express/features/orders/models/order_driver_info.dart';
import 'package:najiz_go_express/features/orders/models/unavailability_option.dart';
import 'package:najiz_go_express/features/orders/models/user_order.dart';

class OrdersRepository {
  OrdersRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  static const int defaultPerPage = 20;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, OrdersApiException.fromHome);
  }

  Future<Map<String, dynamic>> createOrder({
    required String token,
    required int vendorId,
    required String lat,
    required String lng,
    required String customAddressName,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? couponCode,
    String? unavailabilityAction,
    String? notes,
    String serviceName = 'food',
  }) {
    return _run(
      () => _api.postEnvelope(
        path: Endpoints.userOrders,
        token: token,
        body: {
          'vendor_id': vendorId,
          'lat': lat,
          'lng': lng,
          'custom_address_name': customAddressName,
          'payment_method': paymentMethod,
          'items': items,
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'coupon_code': couponCode.trim(),
          if (unavailabilityAction != null &&
              unavailabilityAction.trim().isNotEmpty)
            'unavailability_action': unavailabilityAction.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          'service_name': serviceName,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> calculateOrder({
    String? token,
    required int vendorId,
    required String lat,
    required String lng,
    required String customAddressName,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? couponCode,
    String? unavailabilityAction,
    String? notes,
    String serviceName = 'food',
  }) {
    return _run(
      () => _api.postEnvelope(
        path: Endpoints.userOrdersCalculate,
        token: token,
        body: {
          'vendor_id': vendorId,
          'lat': lat,
          'lng': lng,
          'custom_address_name': customAddressName,
          'payment_method': paymentMethod,
          'items': items,
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'coupon_code': couponCode.trim(),
          if (unavailabilityAction != null &&
              unavailabilityAction.trim().isNotEmpty)
            'unavailability_action': unavailabilityAction.trim(),
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
          'service_name': serviceName,
        },
      ),
    );
  }

  Future<List<UnavailabilityOption>> getOrderUnavailabilityOptions({
    required String token,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.userOrdersUnavailabilityOptions,
        token: token,
      );
      return ApiResponse.asMapList(data['data'])
          .map(UnavailabilityOption.fromJson)
          .where((option) => option.value.isNotEmpty)
          .toList(growable: false);
    });
  }

  Future<Map<String, dynamic>> rateOrder({
    required String token,
    required int orderId,
    required int vendorRating,
    int? deliveryRating,
    String? comment,
  }) {
    return _run(() async {
      final response = await _api.request(
        method: 'POST',
        path: Endpoints.userOrderRate(orderId),
        token: token,
        body: {
          'vendor_rating': vendorRating,
          if (deliveryRating != null) 'delivery_rating': deliveryRating,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );
      final data = ApiResponse.safeDecodeMap(response.body);
      final ok = data['status'] == true ||
          data['status']?.toString().toLowerCase() == 'success';
      if (response.statusCode >= 200 && response.statusCode < 300 && ok) {
        return data;
      }
      throw OrdersApiException.fromServer(
        ApiResponse.extractMessage(data),
        response.statusCode,
      );
    });
  }

  Map<String, String> _pageQuery({required int page, required int perPage}) {
    return {
      'page': '$page',
      'per_page': '$perPage',
    };
  }

  Future<PaginatedPage<UserOrder>> getMyOrdersPage({
    required String token,
    int page = 1,
    int perPage = defaultPerPage,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.userOrdersMy,
        token: token,
        queryParameters: _pageQuery(page: page, perPage: perPage),
      );
      return PaginatedPage.fromEnvelopeData(
        data['data'],
        UserOrder.fromJson,
      );
    });
  }

  Future<Map<String, dynamic>> getOrderById({
    required String token,
    required int orderId,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.userOrder(orderId),
        token: token,
      );
      if (data['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(data['data'] as Map<String, dynamic>);
      }
      if (data['data'] is Map) {
        final map = data['data'] as Map;
        return map.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    });
  }

  Future<OrderDriverInfo> getOrderDriverByOrderId({
    required String token,
    required int orderId,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.userOrderDriver(orderId),
        token: token,
      );
      if (data['data'] is Map<String, dynamic>) {
        return OrderDriverInfo.fromPayload(
          Map<String, dynamic>.from(data['data'] as Map<String, dynamic>),
        );
      }
      if (data['data'] is Map) {
        final map = data['data'] as Map;
        return OrderDriverInfo.fromPayload(
          map.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return const OrderDriverInfo(rawPayload: {});
    });
  }

  Future<void> cancelOrder({
    required String token,
    required int orderId,
    String? cancellationReason,
  }) {
    return _run(() async {
      final payload = <String, dynamic>{
        if (cancellationReason != null && cancellationReason.trim().isNotEmpty)
          'cancellation_reason': cancellationReason.trim(),
      };
      final response = await _api.request(
        method: 'POST',
        path: Endpoints.userOrderCancel(orderId),
        token: token,
        body: payload,
      );
      final data = ApiResponse.safeDecodeMap(response.body);
      final ok = data['status'] == true || data['success'] == true;
      if (response.statusCode >= 200 && response.statusCode < 300 && ok) {
        return;
      }
      throw OrdersApiException.fromServer(
        ApiResponse.extractMessage(data),
        response.statusCode,
      );
    });
  }

  Future<void> sendOrderSos({
    required String token,
    required int orderId,
    String? reason,
  }) {
    return _run(() async {
      final payload = <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      };
      final response = await _api.request(
        method: 'POST',
        path: Endpoints.userOrderSos(orderId),
        token: token,
        body: payload,
      );
      final data = ApiResponse.safeDecodeMap(response.body);
      final ok = data['status'] == true ||
          data['status']?.toString().toLowerCase() == 'success' ||
          data['success'] == true;
      if (response.statusCode >= 200 && response.statusCode < 300 && ok) {
        return;
      }
      throw OrdersApiException.fromServer(
        ApiResponse.extractMessage(data),
        response.statusCode,
      );
    });
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String token,
    required String code,
    required double orderAmount,
    int? vendorId,
  }) {
    return _run(
      () => _api.postEnvelope(
        path: Endpoints.couponsValidate,
        token: token,
        body: {
          'code': code.trim(),
          'order_amount': orderAmount,
          if (vendorId != null) 'vendor_id': vendorId,
        },
      ),
    );
  }
}
