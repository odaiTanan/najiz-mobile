import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/favorites/controllers/favorites_list_controller.dart';
import 'package:najiz_go_express/features/favorites/models/favorite_models.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/features/restaurant/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/core/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/core/navigation/home_bottom_bar.dart';
import 'package:najiz_go_express/core/navigation/main_bottom_nav.dart';
import 'package:najiz_go_express/core/widgets/network_image_with_fallback.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthStateManager>();
    final token = auth.token.value;
    final cs = Theme.of(context).colorScheme;

    if (auth.isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text('favorites.title'.tr)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'favorites.loginRequired'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: AppRoutes.openLogin,
                  child: Text('profile.login'.tr),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          title: Text('favorites.title'.tr),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: 'favorites.tabRestaurants'.tr),
              Tab(text: 'favorites.tabMeals'.tr),
              Tab(text: 'favorites.tabStores'.tr),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FavoritesListTab(section: FavoriteSection.restaurants),
            FavoritesListTab(section: FavoriteSection.meals),
            FavoritesListTab(section: FavoriteSection.stores),
          ],
        ),
        bottomNavigationBar: HomeBottomBar(
          activeIndex: 2,
          onTap: (index) => MainBottomNav.onTap(
            index: index,
            currentIndex: 2,
            token: token,
          ),
        ),
      ),
    );
  }
}

class FavoritesListTab extends StatefulWidget {
  const FavoritesListTab({super.key, required this.section});

  final FavoriteSection section;

  @override
  State<FavoritesListTab> createState() => _FavoritesListTabState();
}

class _FavoritesListTabState extends State<FavoritesListTab> {
  late final String _tag;

  @override
  void initState() {
    super.initState();
    _tag = widget.section.name;
    Get.put(
      FavoritesListController(section: widget.section),
      tag: _tag,
      permanent: true,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  FavoritesListController get _controller =>
      Get.find<FavoritesListController>(tag: _tag);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = _controller;

    return Obx(() {
      if (controller.isLoading.value && controller.items.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      final error = controller.errorMessage.value;
      if (error != null && controller.items.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => controller.load(reset: true),
                  child: Text('favorites.retry'.tr),
                ),
              ],
            ),
          ),
        );
      }

      if (controller.items.isEmpty) {
        return Center(
          child: Text(
            'favorites.empty'.tr,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }

      final isMeals = controller.supportsPagination;
      final token = controller.token;

      return RefreshIndicator(
        onRefresh: () => controller.load(reset: true),
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (isMeals &&
                n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
              controller.loadMoreIfNeeded();
            }
            return false;
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: controller.items.length +
                (isMeals && controller.isLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (isMeals && index >= controller.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final item = controller.items[index];
              return _FavoriteListTile(
                item: item,
                token: token,
                onDelete: () => controller.removeItem(item),
                onOpen: () {
                  if (item.type == 'vendor') {
                    Get.to(
                      () => RestaurantVendorProductsScreen(
                        token: token,
                        vendorId: item.entityId,
                        serviceId: serviceIdFromFavoriteVendorEntity(item.entity),
                      ),
                    );
                  } else {
                    final vendorRaw = item.entity['vendor'];
                    if (vendorRaw is! Map) return;
                    final vMap = Map<String, dynamic>.from(vendorRaw);
                    final vendorId =
                        int.tryParse(vMap['id']?.toString() ?? '') ?? 0;
                    if (vendorId == 0) return;
                    Get.to(
                      () => RestaurantVendorProductsScreen(
                        token: token,
                        vendorId: vendorId,
                        serviceId: serviceIdFromFavoriteVendorEntity(vMap),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      );
    });
  }
}

class _FavoriteListTile extends StatelessWidget {
  const _FavoriteListTile({
    required this.item,
    required this.token,
    required this.onDelete,
    required this.onOpen,
  });

  final FavoriteListItem item;
  final String? token;
  final Future<void> Function() onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final e = item.entity;
    final name = (e['name'] ?? '').toString();
    final image = e['image']?.toString();
    final headers = (token != null && token!.trim().isNotEmpty)
        ? <String, String>{'Authorization': 'Bearer $token'}
        : null;

    String subtitle;
    if (item.type == 'vendor') {
      subtitle = (e['address'] ?? e['type'] ?? '').toString();
    } else {
      final vendor = e['vendor'];
      final vn = vendor is Map ? (vendor['name'] ?? '').toString() : '';
      final price = e['price'];
      final dp = e['discount_price'];
      final parts = <String>[
        if (vn.isNotEmpty) vn,
        if (price != null)
          'search.priceLabel'.trParams({'price': price.toString()}),
      ];
      if (dp != null &&
          dp.toString().trim().isNotEmpty &&
          dp.toString() != price?.toString()) {
        parts.add('search.pricePrimeLabel'.trParams({'price': dp.toString()}));
      }
      subtitle = parts.join(' · ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: NetworkImageWithFallback(
                      url: image,
                      fit: BoxFit.cover,
                      headers: headers,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final ok = await AppPopupDialog.show<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(ctx).colorScheme.surface,
                        surfaceTintColor: Colors.transparent,
                        title: Text('favorites.title'.tr),
                        content: Text('favorites.removeConfirm'.tr),
                        actions: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('common.cancel'.tr),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('common.delete'.tr),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await onDelete();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: cs.onSurfaceVariant,
                ),
                FavoriteHeartButton(
                  favoriteType: item.type,
                  entityId: item.entityId,
                  variant: FavoriteHeartVariant.onLightCard,
                  size: 26,
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_left, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
