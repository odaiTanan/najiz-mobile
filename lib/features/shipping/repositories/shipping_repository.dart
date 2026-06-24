import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/shipping/errors/shipping_api_exception.dart';

class ShippingRepository {
  ShippingRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, ShippingApiException.fromHome);
  }

  Future<Map<String, dynamic>> calculateShippingPrice({
    String? token,
    required double weight,
    required double length,
    required double width,
    required double height,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    String? packageType,
    bool? isBreakable,
    String? couponCode,
    String paymentMethod = 'cash',
  }) {
    return _run(
      () => _api.postEnvelopeSafe(
        path: Endpoints.shippingCalculate,
        token: token,
        body: {
          'weight': weight,
          'length': length,
          'width': width,
          'height': height,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dest_lat': destLat,
          'dest_lng': destLng,
          if (packageType != null && packageType.trim().isNotEmpty)
            'package_type': packageType.trim(),
          if (isBreakable != null) 'is_breakable': isBreakable,
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'coupon_code': couponCode.trim(),
          'payment_method': paymentMethod,
        },
      ),
    );
  }

  Future<Map<String, dynamic>> createShippingOrder({
    required String token,
    required double weight,
    required double length,
    required double width,
    required double height,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    required String packageType,
    required bool isBreakable,
    required String senderName,
    required String senderPhone,
    required String receiverName,
    required String receiverPhone,
    String? region,
    String? street,
    String? addressDetails,
    String? couponCode,
    String paymentMethod = 'cash',
  }) {
    return _run(
      () => _api.postEnvelope(
        path: Endpoints.shippingOrders,
        token: token,
        body: {
          'weight': weight,
          'length': length,
          'width': width,
          'height': height,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dest_lat': destLat,
          'dest_lng': destLng,
          'package_type': packageType,
          'is_breakable': isBreakable,
          'sender_name': senderName,
          'sender_phone': senderPhone,
          'receiver_name': receiverName,
          'receiver_phone': receiverPhone,
          if (region != null && region.trim().isNotEmpty) 'region': region.trim(),
          if (street != null && street.trim().isNotEmpty) 'street': street.trim(),
          if (addressDetails != null && addressDetails.trim().isNotEmpty)
            'address_details': addressDetails.trim(),
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'coupon_code': couponCode.trim(),
          'payment_method': paymentMethod,
        },
      ),
    );
  }
}
