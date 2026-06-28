import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/save_cart_dialog.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_products_model.dart';
import 'package:najiz_go_express/features/restaurant/controllers/restaurant_vendor_products_controller.dart';
import 'package:najiz_go_express/features/orders/models/checkout_cart_item.dart';
import 'package:najiz_go_express/features/orders/views/cart_screen.dart';
import 'package:najiz_go_express/features/orders/views/order_checkout_screen.dart';
import 'package:najiz_go_express/core/widgets/slide_to_confirm_bar.dart';
import 'package:najiz_go_express/core/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/core/widgets/network_image_with_fallback.dart';
import 'package:najiz_go_express/features/orders/widgets/vendor_order_status.dart';
import 'package:najiz_go_express/core/utils/currency_utils.dart';

class RestaurantVendorProductsScreen extends StatefulWidget {
  final String? token;
  final int vendorId;
  final int? serviceId;
  final double? customerLat;
  final double? customerLng;
  final double? vendorLatHint;
  final double? vendorLngHint;

  const RestaurantVendorProductsScreen({
    super.key,
    required this.token,
    required this.vendorId,
    this.serviceId,
    this.customerLat,
    this.customerLng,
    this.vendorLatHint,
    this.vendorLngHint,
  });

  @override
  State<RestaurantVendorProductsScreen> createState() =>
      _RestaurantVendorProductsScreenState();
}

class _RestaurantVendorProductsScreenState
    extends State<RestaurantVendorProductsScreen> {
  final Map<int, CheckoutCartItem> _cartItemsByProductId =
      <int, CheckoutCartItem>{};
  List<VendorProductItem> _latestProducts = const [];
  bool _latestVendorIsOpened = true;
  String? _latestVendorOrderStatus;
  late final AppCartService _cartService;
  late final Worker _cartItemsWorker;
  late final Worker _cartVendorWorker;
  bool _hydratedFromSharedCart = false;
  bool _vendorCartBootstrapDone = false;

  bool _hasCartForThisVendor() {
    if (_cartItemsByProductId.isNotEmpty) return true;
    return _cartService.vendorId.value == widget.vendorId &&
        _cartService.items.isNotEmpty;
  }

  Future<bool> _confirmLeaveCartIfNeeded() async {
    _syncSharedCart();
    if (!_hasCartForThisVendor()) return true;

    final shouldSave = await showSaveCartDialog(context);
    if (shouldSave == null) return false;

    if (shouldSave) {
      _syncSharedCart();
      await _cartService.persistCurrentCart();
      // Keep in-memory cart synced so both vendor and service-level cart
      // badges update immediately after leaving this screen.
    } else {
      await _cartService.clearSavedCart();
    }

    return true;
  }

  Future<bool> _onWillPop() async {
    return _confirmLeaveCartIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    _cartService = Get.find<AppCartService>();
    _cartItemsWorker = ever<List<CheckoutCartItem>>(
      _cartService.items,
      (_) {
        if (!mounted) return;
        setState(_applyServiceItemsToLocalMap);
      },
    );
    _cartVendorWorker = ever<int?>(
      _cartService.vendorId,
      (_) {
        if (!mounted) return;
        setState(_applyServiceItemsToLocalMap);
      },
    );
    if (_cartService.vendorId.value == widget.vendorId &&
        _cartService.items.isNotEmpty) {
      _vendorCartBootstrapDone = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreSavedCartOnEnter();
      });
    }
  }

  @override
  void dispose() {
    _cartItemsWorker.dispose();
    _cartVendorWorker.dispose();
    super.dispose();
  }

  Future<void> _restoreSavedCartOnEnter() async {
    try {
      final hasInMemoryForThisVendor =
          _cartService.vendorId.value == widget.vendorId &&
              _cartService.items.isNotEmpty;
      if (!hasInMemoryForThisVendor) {
        await _cartService.restoreSavedCartIfAny(
          forVendorId: widget.vendorId,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _vendorCartBootstrapDone = true);
      }
    }
  }

  double _cartTotal(List<VendorProductItem> allProducts) {
    final items = _buildCheckoutItems(allProducts);
    return items.fold<double>(0, (sum, item) => sum + item.lineTotal);
  }

  List<CheckoutCartItem> _buildCheckoutItems(
    List<VendorProductItem> allProducts,
  ) {
    if (_cartItemsByProductId.isEmpty) return const [];
    return _cartItemsByProductId.values.toList(growable: false);
  }

  void _hydrateFromSharedCartIfNeeded(List<VendorProductItem> allProducts) {
    if (!_vendorCartBootstrapDone) return;
    if (_hydratedFromSharedCart) return;

    if (_cartService.vendorId.value != widget.vendorId ||
        _cartService.items.isEmpty) {
      _hydratedFromSharedCart = true;
      return;
    }

    for (final item in _cartService.items) {
      _cartItemsByProductId[item.productId] = item;
    }
    _hydratedFromSharedCart = true;
  }

  void _syncSharedCart() {
    final items = _buildCheckoutItems(_latestProducts);
    if (items.isEmpty) {
      _cartService.clear();
      return;
    }
    _cartService.setCart(
      vendorId: widget.vendorId,
      items: items,
      serviceId: widget.serviceId,
    );
  }

  void _tryOpenProductCustomization(
    VendorProductItem product,
    bool canAcceptOrders,
    String? vendorOrderStatus,
    bool vendorIsOpened,
  ) {
    if (!canAcceptOrders) {
      AppSnackbar.show(
        'restaurant.warning'.tr,
        VendorOrderStatus.cannotAddToCartMessage(
          vendorOrderStatus,
          isStore: widget.serviceId == 3,
          isOpened: vendorIsOpened,
        ),
      );
      return;
    }
    _openProductCustomizationSheet(product);
  }

  Future<void> _openProductCustomizationSheet(VendorProductItem product) async {
    final selected = await showModalBottomSheet<_SelectedProductPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductCustomizationSheet(product: product),
    );
    if (selected == null) return;

    setState(() {
      _cartItemsByProductId[product.id] = CheckoutCartItem(
        productId: product.id,
        name: product.name,
        image: product.image,
        description: product.description,
        unitPrice: product.price,
        quantity: selected.productQuantity,
        note: selected.note,
        extras: selected.extras
            .map(
              (extra) => CheckoutCartExtraItem(
                extraId: extra.id,
                name: extra.name,
                price: extra.price,
                quantity: 1,
              ),
            )
            .toList(growable: false),
      );
    });
    _syncSharedCart();
    AppSnackbar.show('restaurant.addedToCart'.tr, 'restaurant.addedToCartMsg'.trParams({'name': product.name}));
  }

  void _applyServiceItemsToLocalMap() {
    _cartItemsByProductId.clear();
    if (_cartService.vendorId.value == widget.vendorId) {
      for (final item in _cartService.items) {
        _cartItemsByProductId[item.productId] = item;
      }
    }
  }

  Future<void> _openCheckoutScreen() async {
    if (!VendorOrderStatus.acceptsOrders(
      _latestVendorOrderStatus,
      isOpened: _latestVendorIsOpened,
    )) {
      AppSnackbar.show(
        'restaurant.warning'.tr,
        VendorOrderStatus.cannotAddToCartMessage(
          _latestVendorOrderStatus,
          isStore: widget.serviceId == 3,
          isOpened: _latestVendorIsOpened,
        ),
      );
      return;
    }

    _syncSharedCart();
    if (!_cartService.hasItems ||
        _cartService.vendorId.value != widget.vendorId) {
      AppSnackbar.show(
        'services.cart'.tr,
        'services.emptyCart'.tr,
      );
      return;
    }

    await Get.to(
      () => OrderCheckoutScreen(
        token: widget.token,
        vendorId: widget.vendorId,
        items: _cartService.items.toList(growable: false),
        serviceId: widget.serviceId ?? _cartService.serviceId.value,
      ),
    );
    if (!mounted) return;
    setState(_applyServiceItemsToLocalMap);
  }

  Future<void> _openCartScreen() async {
    if (!VendorOrderStatus.acceptsOrders(
      _latestVendorOrderStatus,
      isOpened: _latestVendorIsOpened,
    )) {
      AppSnackbar.show(
        'restaurant.warning'.tr,
        VendorOrderStatus.cannotAddToCartMessage(
          _latestVendorOrderStatus,
          isStore: widget.serviceId == 3,
          isOpened: _latestVendorIsOpened,
        ),
      );
      return;
    }

    _syncSharedCart();
    if (!_cartService.hasItems ||
        _cartService.vendorId.value != widget.vendorId) {
      AppSnackbar.show(
        'services.cart'.tr,
        'services.emptyCart'.tr,
      );
      return;
    }
    await Get.to(
      () => CartScreen(
        token: widget.token,
        serviceId: widget.serviceId ?? _cartService.serviceId.value,
      ),
    );
    if (!mounted) return;
    setState(_applyServiceItemsToLocalMap);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final authHeaders = widget.token == null || widget.token!.trim().isEmpty
        ? <String, String>{}
        : <String, String>{'Authorization': 'Bearer ${widget.token}'};

    final controller = Get.put(
      RestaurantVendorProductsController(
        token: widget.token,
        vendorId: widget.vendorId,
        serviceId: widget.serviceId,
        customerLat: widget.customerLat,
        customerLng: widget.customerLng,
        vendorLatHint: widget.vendorLatHint,
        vendorLngHint: widget.vendorLngHint,
      ),
      tag: 'vendor-menu-${widget.vendorId}',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop) Get.back();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: SafeArea(
          child: Obx(() {
          if (controller.isLoading.value &&
              controller.vendorProducts.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value != null &&
              controller.vendorProducts.value == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  controller.errorMessage.value!,
                  style: TextStyle(color: cs.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = controller.vendorProducts.value;
          if (data == null) {
            return Center(child: Text('services.noMenu'.tr));
          }

          final regularProducts = controller.filteredRegularProducts;
          final offerProducts = controller.offerProducts;
          final regularGroups = _regularGroupsForDisplay(
            categories: controller.regularCategories,
            selectedCategoryId: controller.selectedCategoryId.value,
            regularProducts: regularProducts,
          );
          _latestProducts = data.products;
          final total = _cartTotal(data.products);
          _hydrateFromSharedCartIfNeeded(data.products);

          final isStore = widget.serviceId == 3;
          final vendorOrderStatus = data.vendor.vendorStatus;
          final vendorIsOpened = data.vendor.isOpened;
          _latestVendorOrderStatus = vendorOrderStatus;
          _latestVendorIsOpened = vendorIsOpened;
          final canAcceptOrders =
              VendorOrderStatus.acceptsOrders(
            vendorOrderStatus,
            isOpened: vendorIsOpened,
          );
          final heroBlockingBanner = VendorOrderStatus.blockingBannerMessage(
            vendorOrderStatus,
            isStore: isStore,
            isOpened: vendorIsOpened,
          );

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 180),
                  children: [
                    _TopBarTitle(
                      title: data.vendor.name,
                      onBack: () async {
                        final shouldPop = await _onWillPop();
                        if (shouldPop) Get.back();
                      },
                      onCartTap: _openCartScreen,
                    ),
                    const SizedBox(height: 12),
                    _HeroImageCard(
                      imageUrl: data.vendor.image ?? data.vendor.logo,
                      headers: authHeaders,
                      title: data.vendor.name,
                      subtitle: data.vendor.description ?? '',
                      vendorId: widget.vendorId,
                      blockingOverlayMessage: heroBlockingBanner,
                    ),
                    if (VendorOrderStatus.normalized(vendorOrderStatus) !=
                            null ||
                        !vendorIsOpened) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: VendorOrderStatusPill(
                          vendorStatus: vendorOrderStatus,
                          isActive: true,
                          isOpened: vendorIsOpened,
                          isStore: isStore,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoStatCard(
                            icon: Icons.star_rounded,
                            iconColor: AppColors.primary,
                            value: (data.vendor.rating ?? 0).toStringAsFixed(1),
                            label: 'services.rating'.tr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoStatCard(
                            icon: Icons.access_time_rounded,
                            iconColor: AppColors.primary,
                            value: controller.etaMinutesText(
                              fallbackText:
                                  data.vendor.estimatedDeliveryMinutesText,
                            ),
                            label: 'services.minutesDelivery'.tr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _CategoryUnderlineTabs(
                      categories: controller.regularCategories,
                      selectedCategoryId: controller.selectedCategoryId.value,
                      onSelectCategory: controller.selectCategory,
                    ),
                    const SizedBox(height: 14),
                    if (offerProducts.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'restaurant.offersTab'.tr,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...offerProducts.map(
                        (p) => _OfferProductCard(
                          product: p,
                          orderingEnabled: canAcceptOrders,
                          onTap: () => _tryOpenProductCustomization(
                            p,
                            canAcceptOrders,
                            vendorOrderStatus,
                            vendorIsOpened,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (regularGroups.isEmpty)
                      Text(
                        'services.noProducts'.tr,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      )
                    else
                      ...regularGroups.expand(
                        (group) => [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              group.name,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                                height: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...group.products.map(
                            (p) => _MenuProductTile(
                              product: p,
                              orderingEnabled: canAcceptOrders,
                              onTap: () => _tryOpenProductCustomization(
                                p,
                                canAcceptOrders,
                                vendorOrderStatus,
                                vendorIsOpened,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                  ],
                ),
              ),
              if (_cartItemsByProductId.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: widget.serviceId == 3
                      ? _CartBar(
                          total: total,
                          onTap: _openCartScreen,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SlideToConfirmBar(
                              label: 'restaurant.slideToPay'.tr,
                              totalLabel: formatSypAmount(total),
                              onConfirmed: _openCheckoutScreen,
                            ),
                            const SizedBox(height: 10),
                            _CartBar(
                              total: total,
                              onTap: _openCartScreen,
                            ),
                          ],
                        ),
                ),
            ],
          );
        }),
        ),
      ),
    );
  }
}

class _TopBarTitle extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onCartTap;

  const _TopBarTitle({
    required this.title,
    required this.onBack,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 18, color: cs.onSurface),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onCartTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(Icons.shopping_cart_outlined, size: 20, color: cs.onSurface),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroImageCard extends StatelessWidget {
  final String? imageUrl;
  final Map<String, String> headers;
  final String title;
  final String subtitle;
  final int vendorId;
  final String? blockingOverlayMessage;

  const _HeroImageCard({
    required this.imageUrl,
    required this.headers,
    required this.title,
    required this.subtitle,
    required this.vendorId,
    this.blockingOverlayMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: NetworkImageWithFallback(
              url: imageUrl,
              fit: BoxFit.cover,
              headers: headers,
            ),
          ),
          Container(
            height: 210,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB20D253C), Color(0x220D253C)],
              ),
            ),
          ),
          if (blockingOverlayMessage != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                color: Colors.black.withValues(alpha: 0.62),
                child: Text(
                  blockingOverlayMessage!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 10,
            top: 10,
            child: FavoriteHeartButton(
              favoriteType: 'vendor',
              entityId: vendorId,
              variant: FavoriteHeartVariant.onDarkImage,
              size: 28,
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFEDEDED),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _InfoStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal category strip: active tab uses primary color + bottom bar.
class _CategoryUnderlineTabs extends StatelessWidget {
  final List<VendorProductsCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelectCategory;

  const _CategoryUnderlineTabs({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: categories.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, index) {
          final isAll = index == 0;
          final label = isAll ? 'restaurant.allTab'.tr : categories[index - 1].name;
          final id = isAll ? null : categories[index - 1].id;
          final selected = selectedCategoryId == id;
          return InkWell(
            onTap: () => onSelectCategory(id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    height: 3,
                    width: selected ? 36 : 0,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuProductTile extends StatelessWidget {
  final VendorProductItem product;
  final VoidCallback onTap;
  final bool orderingEnabled;

  const _MenuProductTile({
    required this.product,
    required this.onTap,
    this.orderingEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D253C),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 82,
                      height: 82,
                      child: NetworkImageWithFallback(
                        url: product.image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: cs.onSurface,
                            height: 1.15,
                          ),
                        ),
                        if (product.description != null &&
                            product.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            product.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11.5,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        if (product.originalPrice != null &&
                            product.price != null &&
                            product.originalPrice! > product.price!) ...[
                          Text(
                            formatSypAmount(product.originalPrice!),
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          product.price == null ? '-' : formatSypAmount(product.price!),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  FavoriteHeartButton(
                    favoriteType: 'product',
                    entityId: product.id,
                    variant: FavoriteHeartVariant.onLightCard,
                    size: 24,
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (orderingEnabled) return content;
    return Opacity(opacity: 0.48, child: content);
  }
}

class _OfferProductCard extends StatelessWidget {
  const _OfferProductCard({
    required this.product,
    required this.onTap,
    this.orderingEnabled = true,
  });

  final VendorProductItem product;
  final VoidCallback onTap;
  final bool orderingEnabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
            height: 118,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120D253C),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 150,
                      height: double.infinity,
                      child: NetworkImageWithFallback(
                        url: product.image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 27 / 2,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          (product.description ?? '').trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'restaurant.orderNow'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Material(
                  color: cs.surface.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  child: FavoriteHeartButton(
                    favoriteType: 'product',
                    entityId: product.id,
                    variant: FavoriteHeartVariant.onLightCard,
                    size: 22,
                    padding: const EdgeInsets.all(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (orderingEnabled) return content;
    return Opacity(opacity: 0.48, child: content);
  }
}

class _CartBar extends StatelessWidget {
  final double total;
  final VoidCallback onTap;

  const _CartBar({
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Flexible(
              child: Text(
                'restaurant.trackOrder'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatSypAmount(total),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedProductPayload {
  final int productQuantity;
  final List<VendorProductExtra> extras;
  final String? note;

  const _SelectedProductPayload({
    required this.productQuantity,
    required this.extras,
    this.note,
  });
}

class _ProductCustomizationSheet extends StatefulWidget {
  final VendorProductItem product;

  const _ProductCustomizationSheet({required this.product});

  @override
  State<_ProductCustomizationSheet> createState() => _ProductCustomizationSheetState();
}

class _ProductCustomizationSheetState extends State<_ProductCustomizationSheet> {
  int _quantity = 1;
  final Set<int> _selectedExtraIds = <int>{};
  late final List<VendorProductExtra> _extras;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extras = [...widget.product.activeExtras]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final extra in _extras.where((e) => e.isRequired)) {
      _selectedExtraIds.add(extra.id);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double get _basePrice => widget.product.price ?? 0;
  double get _extrasPrice => _extras
      .where((e) => _selectedExtraIds.contains(e.id))
      .fold<double>(0, (sum, e) => sum + e.price);
  double get _total => (_basePrice * _quantity) + _extrasPrice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 210,
                    child: NetworkImageWithFallback(
                      url: widget.product.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.product.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    height: 1.1,
                  ),
                ),
                if ((widget.product.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.product.description!,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatSypAmount(_total),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            icon: const Icon(Icons.remove, color: AppColors.primary),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_quantity',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => setState(() => _quantity++),
                            icon: const Icon(Icons.add, color: AppColors.primary),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_extras.isNotEmpty) ...[
                Text(
                  'restaurant.addonsTitle'.tr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._extras.map((extra) {
                    final selected = _selectedExtraIds.contains(extra.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.55)
                              : cs.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: extra.isRequired
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedExtraIds.add(extra.id);
                                      } else {
                                        _selectedExtraIds.remove(extra.id);
                                      }
                                    });
                                  },
                          ),
                          Expanded(
                            child: Text(
                              extra.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            formatSypAmount(extra.price),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                Text(
                  'restaurant.extraNotes'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLength: 100,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'restaurant.notesHint'.tr,
                    counterText: '',
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final selectedExtras = _extras
                            .where((e) => _selectedExtraIds.contains(e.id))
                            .toList(growable: false);
                        Navigator.of(context).pop(
                          _SelectedProductPayload(
                            productQuantity: _quantity,
                            extras: selectedExtras,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.96, end: 1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'restaurant.addToCartPrice'.trParams({'price': formatSypAmount(_total)}),
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryProductsGroup {
  final String name;
  final List<VendorProductItem> products;

  const _CategoryProductsGroup({
    required this.name,
    required this.products,
  });
}

List<_CategoryProductsGroup> _regularGroupsForDisplay({
  required List<VendorProductsCategory> categories,
  required int? selectedCategoryId,
  required List<VendorProductItem> regularProducts,
}) {
  if (categories.isEmpty || regularProducts.isEmpty) return const [];

  final byCategoryId = <int, List<VendorProductItem>>{};
  for (final product in regularProducts) {
    final categoryId = product.categoryId;
    if (categoryId == null) continue;
    byCategoryId.putIfAbsent(categoryId, () => <VendorProductItem>[]).add(product);
  }

  if (selectedCategoryId != null) {
    final selected = categories.firstWhereOrNull((c) => c.id == selectedCategoryId);
    if (selected == null) return const [];
    final selectedProducts = byCategoryId[selected.id] ?? const <VendorProductItem>[];
    if (selectedProducts.isEmpty) return const [];
    return <_CategoryProductsGroup>[
      _CategoryProductsGroup(
        name: selected.name,
        products: selectedProducts,
      ),
    ];
  }

  final groups = <_CategoryProductsGroup>[];
  for (final category in categories) {
    final products = byCategoryId[category.id] ?? const <VendorProductItem>[];
    if (products.isEmpty) continue;
    groups.add(
      _CategoryProductsGroup(
        name: category.name,
        products: products,
      ),
    );
  }
  return groups;
}
