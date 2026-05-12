import 'dart:async';

import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';

/// Holds favorite vendor/product ids and syncs with GET /favorites + POST /favorites/toggle.
class FavoritesController extends GetxController {
  FavoritesController({HomeRepository? repository})
    : _repository = repository ?? HomeRepository();

  final HomeRepository _repository;
  late final AuthStateManager _auth;

  final vendorFavoriteIds = <int>{}.obs;
  final productFavoriteIds = <int>{}.obs;
  final isSyncing = false.obs;
  bool _startupSyncScheduled = false;

  bool isVendorFavorite(int id) => vendorFavoriteIds.contains(id);
  bool isProductFavorite(int id) => productFavoriteIds.contains(id);

  @override
  void onInit() {
    super.onInit();
    _auth = Get.find<AuthStateManager>();
    ever<String?>(_auth.token, (_) => _onAuthChanged());
    _onAuthChanged();
  }

  void _onAuthChanged() {
    if (!_auth.isAuthenticated) {
      _startupSyncScheduled = false;
      vendorFavoriteIds.clear();
      productFavoriteIds.clear();
      vendorFavoriteIds.refresh();
      productFavoriteIds.refresh();
      return;
    }
    if (_startupSyncScheduled) return;
    _startupSyncScheduled = true;
    // Defer initial favorites sync to avoid competing with home bootstrap APIs.
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () async {
        if (!_auth.isAuthenticated) return;
        await syncFavoriteIdsFromServer();
      }),
    );
  }

  /// Loads all pages of favorites into local id sets (for star UI).
  Future<void> syncFavoriteIdsFromServer() async {
    final token = _auth.token.value;
    if (token == null || token.trim().isEmpty) return;
    if (isSyncing.value) return;
    isSyncing.value = true;
    try {
      final vendors = <int>{};
      final products = <int>{};
      var page = 1;
      while (true) {
        final pageResult = await _repository.getFavoritesPage(
          token: token,
          type: 'all',
          page: page,
        );
        for (final item in pageResult.items) {
          if (item.type == 'vendor') vendors.add(item.entityId);
          if (item.type == 'product') products.add(item.entityId);
        }
        if (page >= pageResult.lastPage) break;
        page++;
      }
      vendorFavoriteIds.assignAll(vendors);
      productFavoriteIds.assignAll(products);
      vendorFavoriteIds.refresh();
      productFavoriteIds.refresh();
    } on HomeApiException catch (_) {
      // Keep previous cache; UI still usable.
    } catch (_) {
      // ignore
    } finally {
      isSyncing.value = false;
    }
  }

  Future<void> toggleVendorWithToken(String token, int vendorId) async {
    final result = await _repository.toggleFavorite(
      token: token,
      type: 'vendor',
      id: vendorId,
    );
    if (result.isFavorite) {
      vendorFavoriteIds.add(vendorId);
    } else {
      vendorFavoriteIds.remove(vendorId);
    }
    vendorFavoriteIds.refresh();
  }

  Future<void> toggleProductWithToken(String token, int productId) async {
    final result = await _repository.toggleFavorite(
      token: token,
      type: 'product',
      id: productId,
    );
    if (result.isFavorite) {
      productFavoriteIds.add(productId);
    } else {
      productFavoriteIds.remove(productId);
    }
    productFavoriteIds.refresh();
  }

  void removeVendorFromCache(int vendorId) {
    vendorFavoriteIds.remove(vendorId);
    vendorFavoriteIds.refresh();
  }

  void removeProductFromCache(int productId) {
    productFavoriteIds.remove(productId);
    productFavoriteIds.refresh();
  }
}
