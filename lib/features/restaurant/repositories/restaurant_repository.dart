import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/models/paginated_page.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/restaurant/errors/restaurant_api_exception.dart';
import 'package:najiz_go_express/features/restaurant/models/classification_model.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_model.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_products_model.dart';

class RestaurantRepository {
  RestaurantRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  static const int defaultPerPage = 20;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, RestaurantApiException.fromHome);
  }

  Map<String, String> _pageQuery({required int page, required int perPage}) {
    return {
      'page': '$page',
      'per_page': '$perPage',
    };
  }

  Future<List<ClassificationModel>> getClassificationsByService({
    String? token,
    required int serviceId,
  }) {
    return _run(() async {
      final all = <ClassificationModel>[];
      var page = 1;
      while (true) {
        final data = await _api.getEnvelope(
          path: Endpoints.serviceClassifications(serviceId),
          token: token,
          queryParameters: _pageQuery(page: page, perPage: 50),
        );
        final result = PaginatedPage.fromEnvelopeData(
          data['data'],
          ClassificationModel.fromJson,
        );
        all.addAll(result.items);
        if (!result.hasMore) break;
        page++;
      }
      return all;
    });
  }

  Future<PaginatedPage<VendorModel>> getVendorsByClassification({
    String? token,
    required int classificationId,
    int page = 1,
    int perPage = defaultPerPage,
    bool forceRefresh = false,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.classificationVendors(classificationId),
        token: token,
        queryParameters: _pageQuery(page: page, perPage: perPage),
        retries: 0,
        forceRefresh: forceRefresh,
      );
      return PaginatedPage.fromEnvelopeData(
        data['data'],
        VendorModel.fromJson,
      );
    });
  }

  Future<PaginatedPage<VendorModel>> getVendorsByService({
    String? token,
    required int serviceId,
    int page = 1,
    int perPage = defaultPerPage,
    int? classificationId,
    bool forceRefresh = false,
  }) {
    return _run(() async {
      final query = _pageQuery(page: page, perPage: perPage);
      if (classificationId != null) {
        query['classification_id'] = '$classificationId';
      }
      final data = await _api.getEnvelope(
        path: Endpoints.serviceVendors(serviceId),
        token: token,
        queryParameters: query,
        retries: 0,
        forceRefresh: forceRefresh,
      );
      return PaginatedPage.fromEnvelopeData(
        data['data'],
        VendorModel.fromJson,
      );
    });
  }

  Future<VendorProductsModel> getVendorProducts({
    String? token,
    required int vendorId,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.vendorProducts(vendorId),
        token: token,
      );
      return VendorProductsModel.fromJson(data);
    });
  }
}
