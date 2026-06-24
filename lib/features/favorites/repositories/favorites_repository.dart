import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/favorites/errors/favorites_api_exception.dart';
import 'package:najiz_go_express/features/favorites/models/favorite_models.dart';

class FavoritesRepository {
  FavoritesRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, FavoritesApiException.fromHome);
  }

  Future<FavoritesPageResult> getFavoritesPage({
    required String token,
    String type = 'all',
    int page = 1,
  }) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.favorites,
        token: token,
        queryParameters: {
          'type': type,
          'page': page.toString(),
        },
      );
      return FavoritesPageResult.fromJson(data);
    });
  }

  Future<FavoriteToggleResult> toggleFavorite({
    required String token,
    required String type,
    required int id,
  }) {
    return _run(() async {
      final data = await _api.postEnvelope(
        path: Endpoints.favoritesToggle,
        token: token,
        body: {'type': type, 'id': id},
      );
      return FavoriteToggleResult.fromJson(data);
    });
  }

  Future<void> deleteFavorite({
    required String token,
    required String type,
    required int id,
  }) {
    return _run(
      () => _api.deleteEnvelope(
        path: Endpoints.favoriteItem(type, id),
        token: token,
      ),
    );
  }
}
