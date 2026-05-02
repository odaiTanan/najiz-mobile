import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/favorites_controller.dart';
import 'package:najiz_go_express/data/models/favorite_models.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/auth/views/login_screen.dart';
import 'package:najiz_go_express/features/home/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/features/home/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

enum _FavoriteSection { restaurants, meals, stores }

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthStateManager>();
    final token = auth.token.value;

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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Get.to(() => const LoginScreen()),
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
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: Text('favorites.title'.tr),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
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
            _FavoritesListTab(section: _FavoriteSection.restaurants),
            _FavoritesListTab(section: _FavoriteSection.meals),
            _FavoritesListTab(section: _FavoriteSection.stores),
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

class _FavoritesListTab extends StatefulWidget {
  const _FavoritesListTab({required this.section});

  final _FavoriteSection section;

  @override
  State<_FavoritesListTab> createState() => _FavoritesListTabState();
}

class _FavoritesListTabState extends State<_FavoritesListTab> {
  final HomeRepository _repository = HomeRepository();

  final List<FavoriteListItem> _items = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  String? get _token => Get.find<AuthStateManager>().token.value;

  bool _vendorEntityIsStore(Map<String, dynamic> entity) {
    final t = (entity['type'] ?? '').toString().toLowerCase();
    return t.contains('متجر') || t.contains('store') || t.contains('stores');
  }

  bool _matchesSection(FavoriteListItem it) {
    if (widget.section == _FavoriteSection.meals) {
      return it.type == 'product';
    }
    if (it.type != 'vendor') return false;
    final isStore = _vendorEntityIsStore(it.entity);
    if (widget.section == _FavoriteSection.restaurants) return !isStore;
    return isStore;
  }

  Future<void> _load({required bool reset}) async {
    final token = _token;
    if (token == null || token.trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'favorites.loginRequired'.tr;
      });
      return;
    }

    if (widget.section == _FavoriteSection.meals) {
      await _loadProductsPaginated(token: token, reset: reset);
      return;
    }

    await _loadVendorsAllPagesFiltered(token: token, reset: reset);
  }

  Future<void> _loadProductsPaginated({
    required String token,
    required bool reset,
  }) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _items.clear();
        _currentPage = 1;
        _lastPage = 1;
      });
    } else {
      if (_loadingMore || _currentPage >= _lastPage) return;
      setState(() => _loadingMore = true);
    }

    final page = reset ? 1 : _currentPage + 1;

    try {
      final result = await _repository.getFavoritesPage(
        token: token,
        type: 'product',
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(result.items);
        } else {
          _items.addAll(result.items);
        }
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (reset) {
          _error = 'favorites.loadFailed'.tr;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadVendorsAllPagesFiltered({
    required String token,
    required bool reset,
  }) async {
    if (!reset) return;

    setState(() {
      _loading = true;
      _error = null;
      _items.clear();
      _currentPage = 1;
      _lastPage = 1;
    });

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
        for (final it in result.items) {
          if (_matchesSection(it)) out.add(it);
        }
        if (page >= result.lastPage) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(out);
        _lastPage = last;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'favorites.loadFailed'.tr;
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _removeItem(FavoriteListItem item) async {
    final token = _token;
    if (token == null || token.trim().isEmpty) return;
    try {
      await _repository.deleteFavorite(
        token: token,
        type: item.type,
        id: item.entityId,
      );
      final fav = Get.find<FavoritesController>();
      if (item.type == 'vendor') {
        fav.removeVendorFromCache(item.entityId);
      } else {
        fav.removeProductFromCache(item.entityId);
      }
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => e.favoriteId == item.favoriteId));
      Get.snackbar('common.done'.tr, 'favorites.removed'.tr);
    } catch (_) {
      Get.snackbar('common.error'.tr, 'favorites.toggleFailed'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _load(reset: true),
                child: Text('favorites.retry'.tr),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          'favorites.empty'.tr,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final isMeals = widget.section == _FavoriteSection.meals;

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (isMeals &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - 120) {
            _load(reset: false);
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _items.length + (isMeals && _loadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (isMeals && index >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final item = _items[index];
            return _FavoriteListTile(
              item: item,
              token: _token,
              onDelete: () => _removeItem(item),
              onOpen: () {
                if (item.type == 'vendor') {
                  Get.to(
                    () => RestaurantVendorProductsScreen(
                      token: _token,
                      vendorId: item.entityId,
                      serviceId: _serviceIdFromVendorEntity(item.entity),
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
                      token: _token,
                      vendorId: vendorId,
                      serviceId: _serviceIdFromVendorEntity(vMap),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}

int _serviceIdFromVendorEntity(Map<String, dynamic> entity) {
  final sid = entity['service_id'];
  if (sid is int && sid > 0) return sid;
  final parsed = int.tryParse(sid?.toString() ?? '');
  if (parsed != null && parsed > 0) return parsed;
  final t = (entity['type'] ?? '').toString().toLowerCase();
  if (t.contains('متجر') || t.contains('store')) return 3;
  return 1;
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
        if (price != null) '$price ل.س',
      ];
      if (dp != null &&
          dp.toString().trim().isNotEmpty &&
          dp.toString() != price?.toString()) {
        parts.add('→ $dp ل.س');
      }
      subtitle = parts.join(' · ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('favorites.title'.tr),
                        content: Text('favorites.removeConfirm'.tr),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('common.cancel'.tr),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('common.delete'.tr),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await onDelete();
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: const Color(0xFF94A3B8),
                ),
                FavoriteHeartButton(
                  favoriteType: item.type,
                  entityId: item.entityId,
                  variant: FavoriteHeartVariant.onLightCard,
                  size: 26,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_left, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
