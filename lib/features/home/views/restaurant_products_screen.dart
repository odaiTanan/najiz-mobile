import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/features/home/controllers/restaurant_products_controller.dart';
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
        ? 'ابحث عن المتاجر أو المنتجات'
        : 'ابحث عن المطاعم أو الأطباق';
    final featuredTitle = isStoresService ? 'متاجر مميزة' : 'مطاعم مميزة';
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
        serviceText: isStoresService ? 'متاجر' : 'مطاعم',
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
                  unreadNotifications: pushService.unreadCount.value,
                  onNotificationsTap: () =>
                      Get.to(() => const NotificationsScreen()),
                  cartCount: cartService.totalCount.value,
                  onCartTap: () {
                    final vendorId = cartService.vendorId.value;
                    final items = cartService.items;
                    if (vendorId == null || items.isEmpty) {
                      Get.snackbar('السلة', 'السلة فارغة حالياً');
                      return;
                    }
                    Get.to(
                      () => OrderCheckoutScreen(
                        token: token,
                        vendorId: vendorId,
                        items: List.of(items),
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
                          label: 'الكل',
                          icon: Icons.restaurant_menu,
                          imageUrl: null,
                          headers: authHeaders,
                          selected: selected,
                          onTap: () => controller.selectClassification(null),
                        );
                      }

                      final c = controller.classifications[index - 1];
                      final selected =
                          controller.selectedClassificationId.value == c.id;
                      return _ClassificationIconItem(
                        label: c.name,
                        icon: _classificationIcon(c.name),
                        imageUrl: c.image,
                        headers: authHeaders,
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
                  const Spacer(),
                  const Text(
                    'عرض الكل',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (controller.vendors.isEmpty)
                Text(
                  isStoresService ? 'لا توجد متاجر' : 'لا توجد مطاعم',
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
                                  const Text(
                                    '20-30 min',
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
}

class _MiniTopCard extends StatelessWidget {
  final int unreadNotifications;
  final VoidCallback onNotificationsTap;
  final int cartCount;
  final VoidCallback onCartTap;

  const _MiniTopCard({
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
          const Expanded(
            child: Text(
              'التوصيل إلى: 123 دمشق، سوريا',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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

class _ClassificationIconItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;
  final Map<String, String>? headers;

  const _ClassificationIconItem({
    required this.label,
    required this.icon,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
    this.headers,
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
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: NetworkImageWithFallback(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        headers: headers,
                      ),
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

IconData _classificationIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('pizza') || n.contains('بيتزا'))
    return Icons.local_pizza_outlined;
  if (n.contains('burger') || n.contains('برغر'))
    return Icons.lunch_dining_outlined;
  if (n.contains('healthy') || n.contains('صحي')) return Icons.eco_outlined;
  if (n.contains('sushi') || n.contains('سوشي')) return Icons.set_meal_outlined;
  return Icons.restaurant_menu_outlined;
}
