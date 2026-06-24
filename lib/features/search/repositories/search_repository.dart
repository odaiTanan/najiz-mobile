import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/search/errors/search_api_exception.dart';
import 'package:najiz_go_express/features/search/models/search_models.dart';

class SearchRepository {
  SearchRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, SearchApiException.fromHome);
  }

  Future<SearchResultModel> search({
    String? token,
    required String query,
    String? type,
    int limit = 10,
  }) {
    return _run(() async {
      final response = await _api.request(
        method: 'GET',
        path: Endpoints.search,
        token: token,
        queryParameters: {
          'query': query,
          if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
          'limit': limit.toString(),
        },
        retries: 0,
      );
      final data = ApiResponse.safeDecodeMap(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          ApiResponse.isSuccess(data)) {
        return SearchResultModel.fromJson(data);
      }
      throw SearchApiException.fromServer(
        ApiResponse.extractMessage(data),
        response.statusCode,
      );
    });
  }

  Future<List<String>> searchSuggestions({
    required String query,
    int limit = 6,
  }) {
    return _run(() async {
      final response = await _api.request(
        method: 'GET',
        path: Endpoints.searchSuggestions,
        queryParameters: {
          'query': query,
          'limit': limit.toString(),
        },
        retries: 0,
      );
      final data = ApiResponse.safeDecodeMap(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          ApiResponse.isSuccess(data)) {
        final raw = (data['suggestions'] is List)
            ? data['suggestions'] as List
            : const [];
        return raw
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();
      }
      throw SearchApiException.fromServer(
        ApiResponse.extractMessage(data),
        response.statusCode,
      );
    });
  }

  Future<List<SearchTrendingItem>> getTrendingSearches({
    int limit = 10,
    int days = 7,
  }) {
    return _run(() async {
      final response = await _api.request(
        method: 'GET',
        path: Endpoints.searchTrending,
        queryParameters: {
          'limit': limit.toString(),
          'days': days.toString(),
        },
        retries: 0,
      );
      final data = ApiResponse.safeDecodeMap(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          ApiResponse.isSuccess(data)) {
        return ApiResponse.asMapList(data['data'])
            .map(SearchTrendingItem.fromJson)
            .toList();
      }
      throw SearchApiException.fromServer(
        ApiResponse.extractMessage(data),
        response.statusCode,
      );
    });
  }

  Future<List<SearchHistoryItem>> getSearchHistory({
    required String token,
    int limit = 20,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.searchHistory,
        token: token,
        queryParameters: {'limit': limit.toString()},
        retries: 0,
      );
      return ApiResponse.asMapList(data['data'])
          .map(SearchHistoryItem.fromJson)
          .toList();
    });
  }

  Future<void> clearSearchHistory({required String token}) {
    return _run(
      () => _api.deleteEnvelope(
        path: Endpoints.searchHistory,
        token: token,
      ),
    );
  }
}
