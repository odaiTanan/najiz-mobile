import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/models/paginated_page.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/home/errors/home_api_exception.dart';
import 'package:najiz_go_express/features/home/models/offer_model.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';
import 'package:najiz_go_express/features/home/services/home_dependencies.dart';
import 'package:najiz_go_express/features/home/services/service_catalog_service.dart';

class HomeRepository {
  HomeRepository({
    ApiClient? apiClient,
    ServiceCatalogService? serviceCatalogService,
  })  : _api = apiClient ?? resolveApiClient(),
        _serviceCatalogService =
            serviceCatalogService ?? resolveServiceCatalogService();

  final ApiClient _api;
  final ServiceCatalogService _serviceCatalogService;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, HomeFeatureApiException.fromHome);
  }

  Future<List<OfferModel>> getOffers({
    String? token,
    bool forceRefresh = false,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.offers,
        token: token,
        retries: 0,
        forceRefresh: forceRefresh,
      );
      return ApiResponse.asMapList(data['data'])
          .map(OfferModel.fromJson)
          .where((offer) => offer.isActive)
          .toList(growable: false);
    });
  }

  Future<List<ServiceModel>> getServices({
    String? token,
    bool forceRefresh = false,
  }) {
    return _run(() async {
      final all = <ServiceModel>[];
      var page = 1;
      while (true) {
        final data = await _api.getEnvelope(
          path: Endpoints.services,
          token: token,
          queryParameters: {
            'page': '$page',
            'per_page': '50',
          },
          retries: 0,
          forceRefresh: forceRefresh,
        );
        final result = PaginatedPage.fromEnvelopeData(
          data['data'],
          ServiceModel.fromJson,
        );
        all.addAll(result.items);
        if (!result.hasMore) break;
        page++;
      }
      return _serviceCatalogService.applyAll(all);
    });
  }
}
