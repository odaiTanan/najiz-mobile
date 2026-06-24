import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/features/favorites/controllers/favorites_controller.dart';
import 'package:najiz_go_express/features/favorites/errors/favorites_api_exception.dart';
import 'package:najiz_go_express/features/favorites/models/favorite_models.dart';
import 'package:najiz_go_express/features/favorites/repositories/favorites_repository.dart';
import 'package:najiz_go_express/features/favorites/services/favorites_dependencies.dart';

enum FavoriteSection { restaurants, meals, stores }

class FavoritesListController extends GetxController {
  FavoritesListController({
    required this.section,
    FavoritesRepository? repository,
  }) : _repository = repository ?? resolveFavoritesRepository();

  final FavoriteSection section;
  final FavoritesRepository _repository;

  final items = <FavoriteListItem>[].obs;
  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final errorMessage = RxnString();
  final currentPage = 1.obs;
  final lastPage = 1.obs;

  String? get token => Get.find<AuthStateManager>().token.value;

  bool get supportsPagination => section == FavoriteSection.meals;

  @override
  void onInit() {
    super.onInit();
    if (items.isEmpty) {
      load(reset: true);
    }
  }

  bool _vendorEntityIsStore(Map<String, dynamic> entity) {
    final t = (entity['type'] ?? '').toString().toLowerCase();
    return t.contains('متجر') || t.contains('store') || t.contains('stores');
  }

  bool _matchesSection(FavoriteListItem item) {
    if (section == FavoriteSection.meals) {
      return item.type == 'product';
    }
    if (item.type != 'vendor') return false;
    final isStore = _vendorEntityIsStore(item.entity);
    if (section == FavoriteSection.restaurants) return !isStore;
    return isStore;
  }

  Future<void> load({required bool reset}) async {
    final authToken = token;
    if (authToken == null || authToken.trim().isEmpty) {
      isLoading.value = false;
      errorMessage.value = 'favorites.loginRequired'.tr;
      return;
    }

    if (section == FavoriteSection.meals) {
      await _loadProductsPaginated(token: authToken, reset: reset);
      return;
    }

    await _loadVendorsAllPagesFiltered(token: authToken, reset: reset);
  }

  Future<void> loadMoreIfNeeded() {
    return load(reset: false);
  }

  Future<void> _loadProductsPaginated({
    required String token,
    required bool reset,
  }) async {
    if (reset) {
      isLoading.value = true;
      errorMessage.value = null;
      items.clear();
      currentPage.value = 1;
      lastPage.value = 1;
    } else {
      if (isLoadingMore.value || currentPage.value >= lastPage.value) return;
      isLoadingMore.value = true;
    }

    final page = reset ? 1 : currentPage.value + 1;

    try {
      final result = await _repository.getFavoritesPage(
        token: token,
        type: 'product',
        page: page,
      );
      if (reset) {
        items.assignAll(result.items);
      } else {
        items.addAll(result.items);
      }
      currentPage.value = result.currentPage;
      lastPage.value = result.lastPage;
      errorMessage.value = null;
    } on FavoritesApiException catch (e) {
      if (reset) {
        errorMessage.value = e.message;
      }
    } catch (_) {
      if (reset) {
        errorMessage.value = 'favorites.loadFailed'.tr;
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> _loadVendorsAllPagesFiltered({
    required String token,
    required bool reset,
  }) async {
    if (!reset) return;

    isLoading.value = true;
    errorMessage.value = null;
    items.clear();
    currentPage.value = 1;
    lastPage.value = 1;

    try {
      final out = <FavoriteListItem>[];
      var page = 1;
      var last = 1;
      const maxPages = 80;
      while (page <= maxPages) {
        final result = await _repository.getFavoritesPage(
          token: token,
          type: 'vendor',
          page: page,
        );
        last = result.lastPage;
        for (final item in result.items) {
          if (_matchesSection(item)) out.add(item);
        }
        if (page >= result.lastPage) break;
        page++;
      }
      items.assignAll(out);
      lastPage.value = last;
      errorMessage.value = null;
    } on FavoritesApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value = 'favorites.loadFailed'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeItem(FavoriteListItem item) async {
    final authToken = token;
    if (authToken == null || authToken.trim().isEmpty) return;
    try {
      await _repository.deleteFavorite(
        token: authToken,
        type: item.type,
        id: item.entityId,
      );
      final fav = Get.find<FavoritesController>();
      if (item.type == 'vendor') {
        fav.removeVendorFromCache(item.entityId);
      } else {
        fav.removeProductFromCache(item.entityId);
      }
      items.removeWhere((e) => e.favoriteId == item.favoriteId);
      AppSnackbar.show('common.done'.tr, 'favorites.removed'.tr);
    } on FavoritesApiException catch (e) {
      AppSnackbar.show('common.error'.tr, e.message);
    } catch (_) {
      AppSnackbar.show('common.error'.tr, 'favorites.toggleFailed'.tr);
    }
  }
}

int serviceIdFromFavoriteVendorEntity(Map<String, dynamic> entity) {
  final sid = entity['service_id'];
  if (sid is int && sid > 0) return sid;
  final parsed = int.tryParse(sid?.toString() ?? '');
  if (parsed != null && parsed > 0) return parsed;
  final t = (entity['type'] ?? '').toString().toLowerCase();
  if (t.contains('متجر') || t.contains('store')) return 3;
  return 1;
}
