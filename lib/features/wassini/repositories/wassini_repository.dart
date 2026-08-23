import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/shipping/errors/shipping_api_exception.dart';

class WassiniRepository {
  WassiniRepository({ApiClient? apiClient})
    : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, ShippingApiException.fromHome);
  }

  Future<Map<String, dynamic>> calculatePrice({
    String? token,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    double? purchaseAmount,
    String? purchaseCurrency,
  }) {
    final body = <String, dynamic>{
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
    };

    if (purchaseAmount != null) {
      body['purchase_amount'] = purchaseAmount;
    }

    final currency = purchaseCurrency?.trim();
    if (currency != null && currency.isNotEmpty) {
      body['purchase_currency'] = currency;
    }

    return _run(
      () => _api.postEnvelopeSafe(
        path: Endpoints.wassiniCalculate,
        token: token,
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> createOrder({
    required String token,
    required String requestDescription,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    double? purchaseAmount,
    String? purchaseCurrency,
    required String senderName,
    required String senderPhone,
    required String receiverName,
    required String receiverPhone,
    String? region,
    String? street,
    String? addressDetails,
    String paymentMethod = 'cash',
  }) {
    final body = <String, dynamic>{
      'request_description': requestDescription.trim(),
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'sender_name': senderName.trim(),
      'sender_phone': senderPhone.trim(),
      'receiver_name': receiverName.trim(),
      'receiver_phone': receiverPhone.trim(),
      'payment_method': paymentMethod,
    };

    if (purchaseAmount != null) {
      body['purchase_amount'] = purchaseAmount;
    }

    final currency = purchaseCurrency?.trim();
    if (currency != null && currency.isNotEmpty) {
      body['purchase_currency'] = currency;
    }

    final normalizedRegion = region?.trim();
    if (normalizedRegion != null && normalizedRegion.isNotEmpty) {
      body['region'] = normalizedRegion;
    }

    final normalizedStreet = street?.trim();
    if (normalizedStreet != null && normalizedStreet.isNotEmpty) {
      body['street'] = normalizedStreet;
    }

    final normalizedDetails = addressDetails?.trim();
    if (normalizedDetails != null && normalizedDetails.isNotEmpty) {
      body['address_details'] = normalizedDetails;
    }

    return _run(
      () => _api.postEnvelope(
        path: Endpoints.wassiniOrders,
        token: token,
        body: body,
      ),
    );
  }
}
