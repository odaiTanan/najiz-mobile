import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/features/restaurant/controllers/restaurant_products_controller.dart';
import 'package:najiz_go_express/core/widgets/delivery_address_picker_sheet.dart';
import 'package:najiz_go_express/core/widgets/delivery_map_picker_flow.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/features/profile/views/profile_address_editor_screen.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/features/orders/views/cart_screen.dart';
import 'package:najiz_go_express/core/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/core/widgets/network_image_with_fallback.dart';
import 'package:najiz_go_express/features/orders/widgets/vendor_order_status.dart';
import 'package:najiz_go_express/core/navigation/home_bottom_bar.dart';
import 'package:najiz_go_express/core/navigation/main_bottom_nav.dart';

class RestaurantProductsScreen extends StatelessWidget {
  final String? token;
  final int serviceId;

  const RestaurantProductsScreen({
    super.key,
    required this.token,
    required this.serviceId,
  });

  @override
  Widget build(BuildContext context) {
    final isStoresService = serviceId == 3;
    final searchHint = isStoresService
        ? 'services.searchStores'.tr
        : 'services.searchRestaurants'.tr;
    final featuredTitle = isStoresService
        ? 'services.featuredStores'.tr
        : 'services.featuredRestaurants'.tr;
    final authHeaders = token == null || token!.trim().isEmpty
        ? <String, String>{}
        : <String, String>{'Authorization': 'Bearer $token'};
    final controller = Get.put(
      RestaurantProductsController(token: token, serviceId: serviceId),
      tag: 'restaurants-$serviceId',
    );
    final pushService = Get.find<PushNotificationService>();
    final cartService = Get.find<AppCartService>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      bottomNavigationBar: HomeBottomBar(
        activeIndex: -1,
        serviceText: isStoresService
            ? 'services.stores'.tr
            : 'services.restaurants'.tr,
        serviceIcon: isStoresService
            ? Icons.storefront_outlined
            : Icons.restaurant_outlined,
        serviceActive: true,
        onServiceTap: () {},
        onTap: (index) =>
            MainBottomNav.onTap(index: index, currentIndex: -1, token: token),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value != null &&
              controller.vendors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  controller.errorMessage.value!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 120) {
                controller.loadMoreVendorsIfNeeded();
              }
              return false;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              children: [
                Obx(
                  () => _MiniTopCard(
                    deliveryAddress: controller.deliveryAddressLabel,
                    hasSavedAddresses: controller.savedAddresses.isNotEmpty,
                    unreadNotifications: pushService.unreadCount.value,
                    onAddressTap: () => _showAddressChooser(
                      context: context,
                      controller: controller,
                    ),
                    onNotificationsTap: AppRoutes.openNotifications,
                    cartCount: cartService.totalCount.value,
                    onCartTap: () async {
                      if (!cartService.hasItems) {
                        await cartService.ensureCartLoaded();
                      }
                      final vendorId = cartService.vendorId.value;
                      if (vendorId == null || !cartService.hasItems) {
                        AppSnackbar.show(
                          'services.cart'.tr,
                          'services.emptyCart'.tr,
                        );
                        return;
                      }
                      Get.to(
                        () => CartScreen(
                          token: token,
                          serviceId: cartService.serviceId.value ?? serviceId,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.inputBorder,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.inputBorder,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Classifications tabs (from /services/{serviceId}/classifications)
                if (controller.classifications.isNotEmpty)
                  SizedBox(
                    height: 101,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.classifications.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, index) {
                        if (index == 0) {
                          final selected =
                              controller.selectedClassificationId.value == null;
                          return _ClassificationIconItem(
                            label: 'services.all'.tr,
                            icon: Icons.grid_view_rounded,
                            selected: selected,
                            onTap: () => controller.selectClassification(null),
                          );
                        }

                        final c = controller.classifications[index - 1];
                        final selected =
                            controller.selectedClassificationId.value == c.id;
                        return _ClassificationIconItem(
                          label: c.name,
                          icon: _classificationIcon(
                            name: c.name,
                            isStoresService: isStoresService,
                          ),
                          imageUrl: c.image,
                          backendIconUrl: c.icon,
                          selected: selected,
                          onTap: () => controller.selectClassification(c.id),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      featuredTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (controller.vendors.isEmpty)
                  Text(
                    isStoresService
                        ? 'services.noStores'.tr
                        : 'services.noRestaurants'.tr,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else
                  ...controller.vendors.map((vendor) {
                    final statusMsg = VendorOrderStatus.blockingBannerMessage(
                      vendor.vendorStatus,
                      isStore: isStoresService,
                      isOpened: vendor.isOpened,
                    );
                    final overlayTop = statusMsg != null ? 46.0 : 10.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => controller.openVendorProducts(vendor),
                        child: Container(
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                                child: SizedBox(
                                  height: 150,
                                  width: double.infinity,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: vendor.isOpened
                                            ? NetworkImageWithFallback(
                                                url:
                                                    vendor.image ?? vendor.logo,
                                                fit: BoxFit.cover,
                                                headers: authHeaders,
                                              )
                                            : ColorFiltered(
                                                colorFilter:
                                                    const ColorFilter.matrix(
                                                      <double>[
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0.2126,
                                                        0.7152,
                                                        0.0722,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        0,
                                                        1,
                                                        0,
                                                      ],
                                                    ),
                                                child: NetworkImageWithFallback(
                                                  url:
                                                      vendor.image ??
                                                      vendor.logo,
                                                  fit: BoxFit.cover,
                                                  headers: authHeaders,
                                                ),
                                              ),
                                      ),
                                      if (statusMsg != null)
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
                                            color: Colors.black.withValues(
                                              alpha: 0.62,
                                            ),
                                            child: Text(
                                              statusMsg,
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
                                      if (vendor.rating != null)
                                        Positioned(
                                          right: 10,
                                          top: overlayTop,
                                          child: _RatingPill(
                                            rating: vendor.rating!,
                                          ),
                                        ),
                                      Positioned(
                                        left: 10,
                                        top: overlayTop,
                                        child: FavoriteHeartButton(
                                          favoriteType: 'vendor',
                                          entityId: vendor.id,
                                          variant:
                                              FavoriteHeartVariant.onDarkImage,
                                          size: 26,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  10,
                                  4,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        vendor.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: cs.onSurface,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    VendorOrderStatusPill(
                                      vendorStatus: vendor.vendorStatus,
                                      isActive: vendor.isActive,
                                      isOpened: vendor.isOpened,
                                      isStore: isStoresService,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  0,
                                  10,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'يفتح ${vendor.openingTime ?? '--'} • يغلق ${vendor.closingTime ?? '--'}',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                Obx(() {
                  if (!controller.isLoadingMore.value) {
                    return const SizedBox.shrink();
                  }
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }),
              ],
            ),
          );
        }),
      ),
    );
  }

  Future<void> _showAddressChooser({
    required BuildContext context,
    required RestaurantProductsController controller,
  }) async {
    final authToken = controller.token?.trim() ?? '';
    if (authToken.isNotEmpty) {
      await controller.loadDeliveryAddress(forceRefresh: true);
    }
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Obx(
        () => DeliveryAddressPickerSheet(
          savedAddresses: controller.savedAddresses.toList(growable: false),
          isLoadingAddresses: false,
          selectedAddressId: controller.selectedAddressId.value,
          mapLocationSelected: controller.isMapPickedLocation.value,
          showLoginHint: authToken.isEmpty,
          onUseCurrentLocation: () async {
            await controller.useCurrentLocationAddress();
            if (sheetContext.mounted) Navigator.of(sheetContext).pop();
          },
          onPickFromMap: () async {
            Navigator.of(sheetContext).pop();
            await Future<void>.delayed(const Duration(milliseconds: 120));
            if (!context.mounted) return;
            final picked = await showRestaurantDeliveryMapPicker(
              context: context,
            );
            if (picked == null || !context.mounted) return;
            final label = await resolveMapPickerLabel(
              point: picked.point,
              pickedLabel: picked.label,
            );
            controller.applyMapPickedLocation(
              lat: picked.point.latitude,
              lng: picked.point.longitude,
              label: label,
            );
          },
          onSelectSaved: (address) {
            controller.selectSavedAddress(address);
            Navigator.of(sheetContext).pop();
          },
          onAddNewAddress: () async {
            Navigator.of(sheetContext).pop();
            await AuthGuardService.runOrRequestLogin(
              onAuthenticated: (_) async {
                if (!context.mounted) return;
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => ProfileAddressEditorScreen(
                      onSave: controller.addAddress,
                    ),
                  ),
                );
              },
              message: 'location.loginForAddress'.tr,
            );
          },
        ),
      ),
    );
  }
}

class _MiniTopCard extends StatelessWidget {
  final String deliveryAddress;
  final bool hasSavedAddresses;
  final VoidCallback onAddressTap;
  final int unreadNotifications;
  final VoidCallback onNotificationsTap;
  final int cartCount;
  final VoidCallback onCartTap;

  const _MiniTopCard({
    required this.deliveryAddress,
    required this.hasSavedAddresses,
    required this.onAddressTap,
    required this.unreadNotifications,
    required this.onNotificationsTap,
    required this.cartCount,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: onAddressTap,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${'services.deliveryTo'.tr} $deliveryAddress',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: hasSavedAddresses
                        ? AppColors.primary
                        : cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onNotificationsTap,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    if (unreadNotifications > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: cs.surface, width: 1),
                          ),
                          child: Text(
                            unreadNotifications > 99
                                ? '99+'
                                : '$unreadNotifications',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCartTap,
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    if (cartCount > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 3,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: cs.surface, width: 1),
                          ),
                          child: Text(
                            cartCount > 99 ? '99+' : '$cartCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassificationIconItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? imageUrl;
  final String? backendIconUrl;
  final bool selected;
  final VoidCallback onTap;

  const _ClassificationIconItem({
    required this.label,
    required this.icon,
    this.imageUrl,
    this.backendIconUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 82,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 76,
              height: 68,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.primary : cs.outlineVariant,
                  width: selected ? 2.2 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasImage
                    ? Image.network(
                        imageUrl!,
                        width: 76,
                        height: 68,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _classificationFallback(context),
                      )
                    : _classificationFallback(context),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: selected ? AppColors.primary : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classificationFallback(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? AppColors.primary : cs.onSurfaceVariant;

    return Container(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: backendIconUrl != null && backendIconUrl!.trim().isNotEmpty
          ? _BackendClassificationIcon(
              iconUrl: backendIconUrl!,
              color: fg,
              fallbackIcon: icon,
            )
          : Icon(icon, size: 30, color: fg),
    );
  }
}

class _BackendClassificationIcon extends StatelessWidget {
  const _BackendClassificationIcon({
    required this.iconUrl,
    required this.color,
    required this.fallbackIcon,
  });

  final String iconUrl;
  final Color color;
  final IconData fallbackIcon;

  bool get _isSvg {
    final lower = iconUrl.toLowerCase();
    return lower.endsWith('.svg') || lower.contains('.svg?');
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvg) {
      return SvgPicture.network(
        iconUrl,
        width: 14,
        height: 14,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        placeholderBuilder: (_) => Icon(fallbackIcon, size: 14, color: color),
      );
    }

    return Image.network(
      iconUrl,
      width: 14,
      height: 14,
      color: color,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (_, __, ___) => Icon(fallbackIcon, size: 14, color: color),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;

  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 12, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _classificationIcon({
  required String name,
  required bool isStoresService,
}) {
  final n = name.toLowerCase();
  if (n.contains('pizza') || n.contains('بيتزا'))
    return Icons.local_pizza_outlined;
  if (n.contains('burger') || n.contains('برغر'))
    return Icons.lunch_dining_outlined;
  if (n.contains('healthy') || n.contains('صحي')) return Icons.eco_outlined;
  if (n.contains('sushi') || n.contains('سوشي')) return Icons.set_meal_outlined;
  if (isStoresService) return Icons.shopping_basket_outlined;
  return Icons.restaurant_menu_outlined;
}
