import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:najiz_go_express/data/models/offer_model.dart';
import 'package:najiz_go_express/data/models/service_model.dart';
import 'package:najiz_go_express/data/models/vendor_model.dart';
import 'package:najiz_go_express/data/models/vendor_products_model.dart';
import 'package:najiz_go_express/data/models/classification_model.dart';
import 'package:najiz_go_express/data/models/taxi_pricing_model.dart';
import 'package:najiz_go_express/features/home/models/user_order.dart';

class HomeRepository {
  final http.Client _client;
  final String _baseUrl;

  HomeRepository({http.Client? client, String baseUrl = ApiConfig.baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl;

  void _logApiRequest({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
  }) {
    print('[API][REQ] $method $uri');
    if (body != null) {
      print('[API][REQ][BODY] ${jsonEncode(body)}');
    }
  }

  void _logApiResponse({
    required String method,
    required Uri uri,
    required http.Response response,
  }) {
    print('[API][RES] $method $uri -> ${response.statusCode}');
    print('[API][RES][BODY] ${response.body}');
  }

  void _logApiError({
    required String method,
    required Uri uri,
    required Object error,
  }) {
    print('[API][ERR] $method $uri -> $error');
  }

  Future<List<OfferModel>> getOffers({String? token}) async {
    final data = await _get(endpoint: '/offers', token: token);
    return _asList(data['data']).map(OfferModel.fromJson).toList();
  }

  Future<List<ServiceModel>> getServices({String? token}) async {
    final data = await _get(endpoint: '/our-services', token: token);
    return _asList(data['data']).map(ServiceModel.fromJson).toList();
  }

  Future<List<ClassificationModel>> getClassificationsByService({
    String? token,
    required int serviceId,
  }) async {
    final data = await _get(
      endpoint: '/services/$serviceId/classifications',
      token: token,
    );
    return _asList(data['data']).map(ClassificationModel.fromJson).toList();
  }

  Future<List<VendorModel>> getVendorsByClassification({
    String? token,
    required int classificationId,
  }) async {
    final data = await _get(
      endpoint: '/classifications/$classificationId/vendors',
      token: token,
    );
    return _asList(data['data']).map(VendorModel.fromJson).toList();
  }

  Future<List<VendorModel>> getVendorsByService({
    String? token,
    required int serviceId,
  }) async {
    final data = await _get(
      endpoint: '/services/$serviceId/vendors',
      token: token,
    );
    return _asList(data['data']).map(VendorModel.fromJson).toList();
  }

  Future<VendorProductsModel> getVendorProducts({
    String? token,
    required int vendorId,
  }) async {
    final data = await _get(endpoint: '/products/$vendorId', token: token);
    return VendorProductsModel.fromJson(data);
  }

  Future<Map<String, dynamic>> createOrder({
    required String token,
    required int vendorId,
    required String lat,
    required String lng,
    required String customAddressName,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? notes,
    String serviceName = 'food',
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders');
    final payload = {
      'vendor_id': vendorId,
      'lat': lat,
      'lng': lng,
      'custom_address_name': customAddressName,
      'payment_method': paymentMethod,
      'items': items,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'service_name': serviceName,
    };
    _logApiRequest(method: 'POST', uri: uri, body: payload);
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);

    final data = _safeJsonDecode(res.body);
    final status = data['status'];
    final isSuccess =
        (status is bool && status) ||
        (status?.toString().toLowerCase() == 'success');

    if (res.statusCode >= 200 && res.statusCode < 300 && isSuccess) {
      return data;
    }

    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> addUserAddress({
    required String token,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$_baseUrl/user/addresses');
    _logApiRequest(method: 'POST', uri: uri, body: payload);
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);

    final data = _safeJsonDecode(res.body);
    final status = data['status'];
    final isSuccess =
        (status is bool && status) ||
        (status?.toString().toLowerCase() == 'success');

    if (res.statusCode >= 200 && res.statusCode < 300 && isSuccess) {
      return data;
    }

    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> calculateOrder({
    String? token,
    required int vendorId,
    required String lat,
    required String lng,
    required String customAddressName,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? notes,
    String serviceName = 'food',
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders/calculate');
    final payload = {
      'vendor_id': vendorId,
      'lat': lat,
      'lng': lng,
      'custom_address_name': customAddressName,
      'payment_method': paymentMethod,
      'items': items,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'service_name': serviceName,
    };
    _logApiRequest(method: 'POST', uri: uri, body: payload);
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null && token.trim().isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);

    final data = _safeJsonDecode(res.body);
    final status = data['status'];
    final isSuccess =
        (status is bool && status) ||
        (status?.toString().toLowerCase() == 'success');

    if (res.statusCode >= 200 && res.statusCode < 300 && isSuccess) {
      return data;
    }

    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<TaxiPricingModel> calculateTaxiPrice({
    String? token,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders/taxi/calculate-price');
    final payload = {
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
    };
    _logApiRequest(method: 'POST', uri: uri, body: payload);
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            if (token != null && token.trim().isNotEmpty)
              'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);

    final data = _safeJsonDecode(res.body);
    final status = data['status'];
    final isSuccess =
        (status is bool && status) ||
        (status?.toString().toLowerCase() == 'success');

    if (res.statusCode >= 200 && res.statusCode < 300 && isSuccess) {
      return TaxiPricingModel.fromJson(data);
    }

    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> createTaxiOrder({
    required String token,
    required int vehicleCategoryId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    String paymentMethod = 'cash',
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders/taxi');
    final payload = {
      'vehicle_category_id': vehicleCategoryId.toString(),
      'pickup_lat': pickupLat.toString(),
      'pickup_lng': pickupLng.toString(),
      'dropoff_lat': dropoffLat.toString(),
      'dropoff_lng': dropoffLng.toString(),
      'payment_method': paymentMethod,
    };
    _logApiRequest(method: 'POST', uri: uri, body: payload);
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);

    final data = _safeJsonDecode(res.body);
    final status = data['status'];
    final isSuccess =
        (status is bool && status) ||
        (status?.toString().toLowerCase() == 'success');

    if (res.statusCode >= 200 && res.statusCode < 300 && isSuccess) {
      return data;
    }

    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
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
    String paymentMethod = 'cash',
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders/shipping/calculate');
    final payload = {
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
      'payment_method': paymentMethod,
    };
    try {
      _logApiRequest(method: 'POST', uri: uri, body: payload);
      final res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null && token.trim().isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(ApiConfig.timeout);
      _logApiResponse(method: 'POST', uri: uri, response: res);

      final data = _safeJsonDecode(res.body);
      final status = data['status'];
      final isSuccess =
          (status is bool && status) ||
          (status?.toString().toLowerCase() == 'success');

      if (res.statusCode >= 200 && res.statusCode < 300 && isSuccess) {
        return data;
      }

      throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
    } on HomeApiException {
      rethrow;
    } on TimeoutException catch (e) {
      _logApiError(method: 'POST', uri: uri, error: e);
      throw HomeApiException('انتهت مهلة الطلب. حاول مجددا.');
    } on SocketException catch (e) {
      _logApiError(method: 'POST', uri: uri, error: e);
      throw HomeApiException('فشل الاتصال بالانترنت. تحقق من الشبكة.');
    } on http.ClientException catch (e) {
      _logApiError(method: 'POST', uri: uri, error: e);
      throw HomeApiException('تعذر الاتصال بالخادم حاليا.');
    } catch (e) {
      _logApiError(method: 'POST', uri: uri, error: e);
      throw HomeApiException('حدث خطأ غير متوقع أثناء حساب الشحن.');
    }
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
    String paymentMethod = 'cash',
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders/shipping');
    final payload = {
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
      'payment_method': paymentMethod,
    };
    _logApiRequest(method: 'POST', uri: uri, body: payload);
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);

    final data = _safeJsonDecode(res.body);
    final status = data['status'];
    final isSuccess =
        (status is bool && status) ||
        (status?.toString().toLowerCase() == 'success');

    if (res.statusCode >= 200 && res.statusCode < 300 && isSuccess) {
      return data;
    }

    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> rateOrder({
    required String token,
    required int orderId,
    required int vendorRating,
    int? deliveryRating,
    String? comment,
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders/$orderId/rate');
    final payload = {
      'vendor_rating': vendorRating,
      if (deliveryRating != null) 'delivery_rating': deliveryRating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    };
    _logApiRequest(method: 'POST', uri: uri, body: payload);
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);

    final data = _safeJsonDecode(res.body);
    final ok = data['status'] == true ||
        data['status']?.toString().toLowerCase() == 'success';
    if (res.statusCode >= 200 && res.statusCode < 300 && ok) {
      return data;
    }

    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<List<UserOrder>> getMyOrders({required String token}) async {
    final data = await _get(endpoint: '/user/orders/my', token: token);
    return _asList(data['data']).map(UserOrder.fromJson).toList();
  }

  Future<Map<String, dynamic>> getOrderById({
    required String token,
    required int orderId,
  }) async {
    final data = await _get(endpoint: '/user/orders/$orderId', token: token);
    if (data['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data['data'] as Map<String, dynamic>);
    }
    if (data['data'] is Map) {
      final map = data['data'] as Map;
      return map.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getOrderDriverByOrderId({
    required String token,
    required int orderId,
  }) async {
    final data = await _get(endpoint: '/user/orders/$orderId/driver', token: token);
    if (data['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data['data'] as Map<String, dynamic>);
    }
    if (data['data'] is Map) {
      final map = data['data'] as Map;
      return map.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  Future<void> cancelOrder({
    required String token,
    required int orderId,
    String? cancellationReason,
  }) async {
    final uri = Uri.parse('$_baseUrl/user/orders/$orderId/cancel');
    final payload = <String, dynamic>{
      if (cancellationReason != null && cancellationReason.trim().isNotEmpty)
        'cancellation_reason': cancellationReason.trim(),
    };
    _logApiRequest(
      method: 'POST',
      uri: uri,
      body: payload.isEmpty ? null : payload,
    );
    final res = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(ApiConfig.timeout);
    _logApiResponse(method: 'POST', uri: uri, response: res);
    final data = _safeJsonDecode(res.body);
    final ok = data['status'] == true || data['success'] == true;
    if (res.statusCode >= 200 && res.statusCode < 300 && ok) return;
    throw HomeApiException(_extractMessage(data), statusCode: res.statusCode);
  }

  Future<Map<String, dynamic>> _get({
    required String endpoint,
    String? token,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    Object? lastError;
    const retries = 1;

    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        _logApiRequest(method: 'GET', uri: uri);
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };
        if (token != null && token.trim().isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
        final res = await _client
            .get(
              uri,
              headers: headers,
            )
            .timeout(ApiConfig.timeout);
        _logApiResponse(method: 'GET', uri: uri, response: res);

        final data = _safeJsonDecode(res.body);

        if (res.statusCode >= 200 && res.statusCode < 300 && _isSuccess(data)) {
          return data;
        }

        throw HomeApiException(
          _extractMessage(data),
          statusCode: res.statusCode,
        );
      } on TimeoutException catch (e) {
        _logApiError(method: 'GET', uri: uri, error: e);
        lastError = e;
      } on SocketException catch (e) {
        _logApiError(method: 'GET', uri: uri, error: e);
        lastError = e;
      } on http.ClientException catch (e) {
        _logApiError(method: 'GET', uri: uri, error: e);
        lastError = e;
      }

      if (attempt < retries) {
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }

    if (lastError is TimeoutException) {
      throw HomeApiException('Server timeout. Please try again.');
    }
    if (lastError is SocketException || lastError is http.ClientException) {
      throw HomeApiException(
        'Connection failed. Please check your internet and try again.',
      );
    }

    throw HomeApiException('Network request failed');
  }
}

Map<String, dynamic> _safeJsonDecode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
}

bool _isSuccess(Map<String, dynamic> data) {
  final success = data['success'];
  if (success is bool) return success;
  final status = data['status'];
  if (status is bool) return status;
  final statusText = data['status']?.toString().toLowerCase();
  return statusText == 'success';
}

String _extractMessage(Map<String, dynamic> data) {
  final message = data['message'] ?? data['error'];
  if (message != null) return message.toString();
  return 'فشل الطلب';
}

List<Map<String, dynamic>> _asList(dynamic data) {
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
      .toList();
}

class HomeApiException implements Exception {
  final String message;
  final int? statusCode;

  HomeApiException(this.message, {this.statusCode});

  @override
  String toString() => 'HomeApiException($statusCode): $message';
}
