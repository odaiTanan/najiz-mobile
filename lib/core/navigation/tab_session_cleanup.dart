import 'package:get/get.dart';
import 'package:najiz_go_express/features/favorites/controllers/favorites_list_controller.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
import 'package:najiz_go_express/features/orders/controllers/my_orders_controller.dart';
import 'package:najiz_go_express/features/profile/controllers/profile_controller.dart';
import 'package:najiz_go_express/features/search/controllers/search_controller.dart';
import 'package:najiz_go_express/features/search/search_meta_cache.dart';

/// Drops cached tab controllers when auth session changes (logout / new token).
class TabSessionCleanup {
  TabSessionCleanup._();

  static const _profileTag = 'profile-controller';
  static const _ordersTag = 'my-orders';
  static const _searchTag = 'search-screen';
  static const _favoritesTags = ['restaurants', 'meals', 'stores'];

  static void resetAfterAuthChange() {
    SearchMetaCache.invalidate();
    _deleteIfRegistered<HomeController>();
    _deleteIfRegistered<ProfileController>(tag: _profileTag);
    _deleteIfRegistered<MyOrdersController>(tag: _ordersTag);
    _deleteIfRegistered<SearchController>(tag: _searchTag);
    for (final tag in _favoritesTags) {
      _deleteIfRegistered<FavoritesListController>(tag: tag);
    }
  }

  static void _deleteIfRegistered<T>({String? tag}) {
    if (Get.isRegistered<T>(tag: tag)) {
      Get.delete<T>(tag: tag, force: true);
    }
  }
}
