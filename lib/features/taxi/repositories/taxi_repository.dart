import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/taxi/errors/taxi_api_exception.dart';
import 'package:najiz_go_express/features/taxi/models/taxi_pricing_model.dart';

class TaxiRepository {
  TaxiRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, TaxiApiException.fromHome);
  }

  Future<TaxiPricingModel> calculateTaxiPrice({
    String? token,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    return _run(() async {
      final data = await _api.postEnvelope(
        path: Endpoints.taxiCalculatePrice,
        token: token,
        body: {
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
        },
      );
      return TaxiPricingModel.fromJson(data);
    });
  }

  Future<Map<String, dynamic>> createTaxiOrder({
    required String token,
    required int vehicleCategoryId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String? couponCode,
    String paymentMethod = 'cash',
  }) {
    return _run(
      () => _api.postEnvelope(
        path: Endpoints.taxiOrders,
        token: token,
        body: {
          'vehicle_category_id': vehicleCategoryId.toString(),
          'pickup_lat': pickupLat.toString(),
          'pickup_lng': pickupLng.toString(),
          'dropoff_lat': dropoffLat.toString(),
          'dropoff_lng': dropoffLng.toString(),
          if (couponCode != null && couponCode.trim().isNotEmpty)
            'coupon_code': couponCode.trim(),
          'payment_method': paymentMethod,
        },
      ),
    );
  }
}
