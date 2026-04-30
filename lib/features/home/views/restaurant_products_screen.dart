import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/data/models/vendor_model.dart';
import 'package:najiz_go_express/features/home/controllers/restaurant_products_controller.dart';
import 'package:najiz_go_express/features/home/models/user_address.dart';
import 'package:najiz_go_express/features/home/views/profile_address_editor_screen.dart';
import 'package:najiz_go_express/features/home/views/notifications_screen.dart';
import 'package:najiz_go_express/features/home/views/order_checkout_screen.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 0,
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

          return ListView(
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
                  onNotificationsTap: () =>
                      Get.to(() => const NotificationsScreen()),
                  cartCount: cartService.totalCount.value,
                  onCartTap: () {
                    final vendorId = cartService.vendorId.value;
                    final items = cartService.items;
                    if (vendorId == null || items.isEmpty) {
                      Get.snackbar(
                        'services.cart'.tr,
                        'services.emptyCart'.tr,
                      );
                      return;
                    }
                    Get.to(
                      () => OrderCheckoutScreen(
                        token: token,
                        vendorId: vendorId,
                        items: List.of(items),
                        serviceId: serviceId,
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
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Classifications tabs (from /services/{serviceId}/classifications)
              if (controller.classifications.isNotEmpty)
                SizedBox(
                  height: 58,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.classifications.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      if (index == 0) {
                        final selected =
                            controller.selectedClassificationId.value == null;
                        return _ClassificationIconItem(
                          label: 'services.all'.tr,
                          icon: Icons.clear_rounded,
                          selected: selected,
                          onTap: () => controller.selectClassification(null),
                        );
                      }

                      final c = controller.classifications[index - 1];
                      final selected =
                          controller.selectedClassificationId.value == c.id;
                      return _ClassificationIconItem(
                        label: c.name,
                        icon: _classificationIcon(name: c.name),
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
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
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
                  style: const TextStyle(color: AppColors.textSecondary),
                )
              else
                ...controller.vendors.map(
                  (vendor) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => controller.openVendorProducts(vendor.id),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFEDEDED)),
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
                                      child: NetworkImageWithFallback(
                                        url: vendor.image ?? vendor.logo,
                                        fit: BoxFit.cover,
                                        headers: authHeaders,
                                      ),
                                    ),
                                    if (vendor.rating != null)
                                      Positioned(
                                        right: 10,
                                        top: 10,
                                        child: _RatingPill(
                                          rating: vendor.rating!,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      vendor.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _VendorStatusBadge(vendor: vendor),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 2),
                              child: Row(
                                children: [
                                  _StatusText(
                                    text: vendor.isActive
                                        ? 'services.active'.tr
                                        : 'services.inactive'.tr,
                                    isPositive: vendor.isActive,
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusText(
                                    text: vendor.isOpened
                                        ? 'services.open'.tr
                                        : 'services.closed'.tr,
                                    isPositive: vendor.isOpened,
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '20-30 ${'services.minutesDelivery'.tr}',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    '1.2 km',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
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
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _showAddressChooser({
    required BuildContext context,
    required RestaurantProductsController controller,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: Obx(
              () => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE3EE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'عنوان التوصيل',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AddressOptionTile(
                    title: 'الموقع الحالي',
                    subtitle: controller.currentDeliveryAddress.value,
                    icon: Icons.near_me_outlined,
                    selected: controller.selectedAddressId.value == null,
                    onTap: () async {
                      await controller.useCurrentLocationAddress();
                      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                    },
                  ),
                  const SizedBox(height: 8),
                  ...controller.savedAddresses.map(
                    (address) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _AddressOptionTile(
                        title: address.title,
                        subtitle: address.details,
                        icon: Icons.location_on_outlined,
                        selected: controller.selectedAddressId.value == address.id,
                        onTap: () {
                          controller.selectSavedAddress(address);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.of(sheetContext).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileAddressEditorScreen(
                              onSave: controller.addAddress,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text(
                        'إضافة عنوان جديد',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: hasSavedAddresses
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onNotificationsTap,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    right: -7,
                    top: -7,
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
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        unreadNotifications > 99 ? '99+' : '$unreadNotifications',
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
          const SizedBox(width: 6),
          InkWell(
            onTap: onCartTap,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.shopping_cart_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                if (cartCount > 0)
                  Positioned(
                    right: -7,
                    top: -7,
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
                        border: Border.all(color: Colors.white, width: 1),
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
        ],
      ),
    );
  }
}

class _AddressOptionTile extends StatelessWidget {
  const _AddressOptionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE4E9F1),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _VendorStatusBadge extends StatelessWidget {
  final VendorModel vendor;

  const _VendorStatusBadge({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final isReady = vendor.isActive && vendor.isOpened;
    final bgColor = isReady ? const Color(0xFFE8F7EE) : const Color(0xFFFFF1F1);
    final fgColor = isReady ? const Color(0xFF1B8E4B) : const Color(0xFFC43D3D);
    final label = isReady ? 'services.available'.tr : 'services.unavailable'.tr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final String text;
  final bool isPositive;

  const _StatusText({required this.text, required this.isPositive});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: isPositive ? const Color(0xFF1B8E4B) : AppColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ClassificationIconItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? backendIconUrl;
  final bool selected;
  final VoidCallback onTap;

  const _ClassificationIconItem({
    required this.label,
    required this.icon,
    this.backendIconUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.primary : Colors.white;
    final fg = selected ? Colors.white : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEDEDED)),
              ),
              child: (backendIconUrl != null && backendIconUrl!.trim().isNotEmpty)
                  ? Image.network(
                      backendIconUrl!,
                      width: 14,
                      height: 14,
                      color: fg,
                      colorBlendMode: BlendMode.srcIn,
                      errorBuilder: (_, __, ___) =>
                          Icon(icon, size: 14, color: fg),
                    )
                  : Icon(icon, size: 14, color: fg),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;

  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 12, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _classificationIcon({required String name}) {
  final n = name.toLowerCase();
  if (n.contains('pizza') || n.contains('بيتزا'))
    return Icons.local_pizza_outlined;
  if (n.contains('burger') || n.contains('برغر'))
    return Icons.lunch_dining_outlined;
  if (n.contains('healthy') || n.contains('صحي')) return Icons.eco_outlined;
  if (n.contains('sushi') || n.contains('سوشي')) return Icons.set_meal_outlined;
  return Icons.restaurant_menu_outlined;
}

