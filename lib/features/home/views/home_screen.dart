import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/theme/theme_context.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/home/widgets/home_offer_slider.dart';
import 'package:najiz_go_express/features/home/services/service_catalog_service.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
import 'package:najiz_go_express/core/services/order_progress_notification_mapper.dart';
import 'package:najiz_go_express/core/services/shipping_order_state.dart';
import 'package:najiz_go_express/features/orders/models/user_order.dart';
import 'package:najiz_go_express/core/navigation/home_bottom_bar.dart';
import 'package:najiz_go_express/features/restaurant/widgets/restaurant_card.dart';
import 'package:najiz_go_express/features/home/widgets/home_service_grid.dart';
import 'package:najiz_go_express/core/navigation/main_bottom_nav.dart';
import 'package:najiz_go_express/features/home/views/all_services_screen.dart';
import 'package:najiz_go_express/features/restaurant/views/restaurant_products_screen.dart';
import 'package:najiz_go_express/features/support/widgets/support_chat_floating_bubble.dart';
import 'package:shimmer/shimmer.dart';

const _serviceCatalog = ServiceCatalogService();

void _openAllServicesPage(HomeController controller) {
  final orderedServices = _serviceCatalog.sortForHome(controller.services);
  Get.to(
    () => AllServicesScreen(
      services: orderedServices,
      onServiceTap: (service) {
        Get.back();
        controller.onServiceTap(service);
      },
    ),
  );
}

class HomeScreen extends StatelessWidget {
  final String? token;

  const HomeScreen({super.key, this.token});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<HomeController>()
        ? Get.find<HomeController>()
        : Get.put(HomeController(token: token), permanent: true);
    final authState = Get.find<AuthStateManager>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 0,
        onTap: (index) => MainBottomNav.onTap(
          index: index,
          currentIndex: 0,
          token: controller.activeToken,
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SafeArea(
            child: Obx(() {
          final loading = controller.isLoading.value;
          final waitingNet = controller.homeWaitingNetwork.value;
          final showBootstrapShimmer =
              loading && controller.services.isEmpty;
          if (showBootstrapShimmer) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const _HomeShimmerSkeleton(),
                if (waitingNet)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 8,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.wifi_off_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'home.waitingForNetworkHint'.tr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  height: 1.35,
                                  color: context.uiText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: controller.refreshHomeData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                _TopGreetingRow(
                  displayName: controller.displayName.value,
                  onProfileTap: () => MainBottomNav.onTap(
                    index: 4,
                    currentIndex: 0,
                    token: controller.activeToken,
                  ),
                  onNotificationsTap: controller.openNotifications,
                  unreadNotifications: controller.unreadNotifications.value,
                ),
                const SizedBox(height: 14),
                Obx(
                  () => authState.isGuest
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'home.guestBrowsing'.tr,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),
                if (controller.errorMessage.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      controller.errorMessage.value!,
                      style: TextStyle(color: cs.error),
                    ),
                  ),
                Obx(() {
                  final offers = controller.offers.toList(growable: false);
                  return HomeOfferSlider(
                    offers: offers,
                    onTap: controller.onOfferTap,
                  );
                }),
                if (controller.primaryActiveOrder != null) ...[
                  const SizedBox(height: 14),
                  _ActiveOrderHomeCard(
                    order: controller.primaryActiveOrder!,
                    onTap: controller.openPrimaryActiveOrder,
                    hasMore: controller.hasMoreActiveOrders,
                    onMoreTap: () => MainBottomNav.onTap(
                      index: 1,
                      currentIndex: 0,
                      token: controller.activeToken,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'home.services'.tr,
                  actionText: 'home.showAll'.tr,
                  onActionTap: () => _openAllServicesPage(controller),
                ),
                const SizedBox(height: 10),
                if (controller.services.isEmpty)
                  Text(
                    'home.noServices'.tr,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  )
                else
                  Builder(
                    builder: (_) {
                      final orderedServices = _serviceCatalog.sortForHome(
                        controller.services,
                      );
                      return HomeServiceGrid(
                        services: orderedServices,
                        onTap: controller.onServiceTap,
                      );
                    },
                  ),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'home.mostOrderedRestaurants'.tr,
                  actionText: 'home.showAll'.tr,
                  onActionTap: () {
                    final serviceId =
                        controller.restaurantServiceId.value ??
                            controller.selectedServiceId.value ??
                            3;
                    Get.to(
                      () => RestaurantProductsScreen(
                        token: controller.activeToken,
                        serviceId: serviceId,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                if (controller.filteredVendors.isEmpty)
                  Obx(() {
                    if (controller.isVendorsLoading.value) {
                      return const _ShimmerRestaurantsRow();
                    }
                    return Text(
                      'home.noRestaurants'.tr,
                      style: TextStyle(color: context.uiSubtext),
                    );
                  })
                else
                  SizedBox(
                    height: 188,
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.pixels >=
                            notification.metrics.maxScrollExtent - 80) {
                          controller.loadMoreVendorsIfNeeded();
                        }
                        return false;
                      },
                      child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.filteredVendors.length +
                          (controller.isLoadingMoreVendors.value ? 1 : 0),
                      separatorBuilder: (_, unusedIndex) =>
                          const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        if (index >= controller.filteredVendors.length) {
                          return const SizedBox(
                            width: 48,
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }
                        final vendor = controller.filteredVendors[index];
                        return HomeRestaurantCard(
                          name: vendor.name,
                          imageUrl: vendor.image ?? vendor.logo,
                          rating: vendor.rating,
                          subtitle: vendor.description,
                          vendorId: vendor.id,
                          vendorStatus: vendor.vendorStatus,
                          isOpened: vendor.isOpened,
                          isStore: (vendor.serviceId ?? controller.selectedServiceId.value) == 3,
                          etaMinutesText: vendor.estimatedDeliveryMinutesText,
                          onTap: () => controller.onRestaurantCardTap(vendor),
                        );
                      },
                    ),
                    ),
                  ),
              ],
            ),
          );
        }),
          ),
          const SupportChatFloatingBubble(),
        ],
      ),
    );
  }
}

/// Progress row: each step keeps its dot and label in one column so labels stay
/// centered under the icons; connectors are drawn in the shared stack layer.
class _OrderTrackingStepsRow extends StatelessWidget {
  const _OrderTrackingStepsRow({
    required this.labels,
    required this.icons,
    required this.currentStep,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = labels.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(n, (index) {
          final isActive = currentStep >= 0 && index == currentStep;
          final isDone = currentStep >= 0 && index < currentStep;
          return Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 28,
                  width: double.infinity,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (index < n - 1)
                        Positioned(
                          left: 0,
                          right: 14,
                          top: 13,
                          child: Container(
                            height: 1.2,
                            color: currentStep > index
                                ? cs.outline
                                : cs.outlineVariant,
                          ),
                        ),
                      if (index > 0)
                        Positioned(
                          left: 14,
                          right: 0,
                          top: 13,
                          child: Container(
                            height: 1.2,
                            color: currentStep > index - 1
                                ? cs.outline
                                : cs.outlineVariant,
                          ),
                        ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : cs.surfaceContainerHighest,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone || isActive
                                ? cs.outline
                                : cs.outlineVariant,
                          ),
                        ),
                        child: Icon(
                          icons[index],
                          size: 15,
                          color: isActive
                              ? Colors.white
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: index == currentStep
                          ? FontWeight.w700
                          : FontWeight.w500,
                      height: 1.15,
                      color: index == currentStep
                          ? cs.onSurface
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// ظٹط²ظٹظ„ طھط³ظ…ظٹط§طھ ظ‚ط¯ ظٹط±ط³ظ„ظ‡ط§ ط§ظ„ظ€ API ظ…ط¹ [order_number] ظپطھط¸ظ‡ط± ظƒظ€ آ«ط±ظ‚ظ… ط§ظ„ط·ظ„ط¨آ» ظ‚ط¨ظ„ ط§ظ„ظ†طµ ط§ظ„ظ…ط·ظ„ظˆط¨.
String _stripDecorativeOrderNumberPrefix(String raw) {
  var s = raw.trim();
  s = s.replaceAll(
    RegExp(r'^(?:ط±ظ‚ظ…\s*ط§ظ„ط·ظ„ط¨|Order\s*Number)\s*:?\s*', caseSensitive: false),
    '',
  );
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _ActiveOrderHomeCard extends StatelessWidget {
  const _ActiveOrderHomeCard({
    required this.order,
    required this.onTap,
    required this.hasMore,
    required this.onMoreTap,
  });

  final UserOrder order;
  final VoidCallback onTap;
  final bool hasMore;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentStep = _activeStepIndex(order);
    final isShipping = order.type.trim().toLowerCase() == 'shipping';
    final labels = isShipping
        ? ShippingOrderState.timelineLabelKeys.map((key) => key.tr).toList()
        : [
            'home.orderStep1'.tr,
            'home.orderStep2'.tr,
            'home.orderStep3'.tr,
            'home.orderStep4'.tr,
          ];
    final icons = isShipping
        ? const [
            Icons.task_alt_outlined,
            Icons.local_shipping_outlined,
            Icons.inventory_2_outlined,
            Icons.route_outlined,
            Icons.home_outlined,
          ]
        : const [
            Icons.check_rounded,
            Icons.directions_car_filled_rounded,
            Icons.location_on_outlined,
            Icons.outlined_flag_rounded,
          ];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.directions_car_outlined,
                      size: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Directionality(
                                textDirection: TextDirection.rtl,
                                child: Text(
                                  _orderTitle(order),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                labels[currentStep.clamp(
                                  0,
                                  labels.length - 1,
                                )],
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _OrderTrackingStepsRow(
              labels: labels,
              icons: icons,
              currentStep: currentStep,
            ),
            if (hasMore) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: onMoreTap,
                child: Text(
                  'home.hasMoreActiveOrders'.tr,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _activeStepIndex(UserOrder order) {
    final type = order.type.trim().toLowerCase();
    if (type == 'shipping') {
      return OrderProgressNotificationMapper.shippingTimelineStageIndex(
        order.status,
        dispatchStatusRaw: order.dispatchStatus,
      );
    }

    final status = order.status.toLowerCase();
    final dispatch = order.dispatchStatus.toLowerCase();
    if (status == 'delivered' || status == 'completed') return 3;
    if (status == 'on_way' || status == 'picked_up') return 1;
    if (status == 'on_the_way_to_pickup' || status == 'near_destination') return 2;
    if (dispatch == 'accepted' || dispatch == 'assigned') return 0;
    if (status == 'accepted') return 0;
    return -1;
  }

  String _orderTitle(UserOrder order) {
    final prefix = switch (order.type.toLowerCase()) {
      'shipping' => 'home.orderShipping'.tr,
      'taxi' => 'home.orderTaxi'.tr,
      'stores' || 'store' => 'home.orderStore'.tr,
      _ => 'home.orderFood'.tr,
    };
    final numberWord = 'home.orderNumberPrefix'.tr;
    final token = _compactOrderToken(order.orderNumber, order.id);
    const lrm = '\u200e';
    return '$prefix $numberWord $lrm$token';
  }

  String _compactOrderToken(String orderNumber, int fallbackId) {
    final cleaned = _stripDecorativeOrderNumberPrefix(orderNumber);
    final chunks = RegExp(r'[A-Za-z0-9]+').allMatches(cleaned);
    if (chunks.isNotEmpty) {
      final raw = chunks.last.group(0) ?? '';
      if (raw.isNotEmpty) {
        final upper = raw.toUpperCase();
        if (upper.length > 8) return upper.substring(upper.length - 8);
        return upper;
      }
    }
    return fallbackId.toString();
  }
}

class _HomeShimmerSkeleton extends StatelessWidget {
  const _HomeShimmerSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: Color.alphaBlend(
        cs.onSurface.withValues(alpha: 0.06),
        cs.surfaceContainerHigh,
      ),
      period: const Duration(milliseconds: 1300),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          const _ShimmerTopGreetingRow(),
          const SizedBox(height: 14),
          const _ShimmerHeroBlock(),
          const SizedBox(height: 18),
          const _ShimmerSectionHeaderRow(shortTitle: true),
          const SizedBox(height: 10),
          _ShimmerServiceGridFourCol(),
          const SizedBox(height: 18),
          const _ShimmerSectionHeaderRow(shortTitle: false),
          const SizedBox(height: 10),
          const _ShimmerRestaurantsRow(),
        ],
      ),
    );
  }
}

/// ظٹط·ط§ط¨ظ‚ [_TopGreetingRow]: ط£ظٹظ‚ظˆظ†ط© ظٹط³ط§ط± + ط¹ظ…ظˆط¯ ظ†طµ ظٹظ…ظٹظ†.
class _ShimmerTopGreetingRow extends StatelessWidget {
  const _ShimmerTopGreetingRow();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ShimmerBox(height: 42, width: 42, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.58,
                    alignment: Alignment.centerRight,
                    child: const _ShimmerBox(height: 26, radius: 10),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: _ShimmerBox(height: 15, width: 200, radius: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ظٹط·ط§ط¨ظ‚ [_HeroPromoSlider] (ط§ط±طھظپط§ط¹ 186 + ط´ط±ظٹط· ظ†ظ‚ط§ط· طھظ‚ط±ظٹط¨ظٹ).
class _ShimmerHeroBlock extends StatelessWidget {
  const _ShimmerHeroBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ShimmerBox(height: 186, radius: 20),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: _ShimmerBox(height: 7, width: 7, radius: 99),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: _ShimmerBox(height: 7, width: 7, radius: 99),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: _ShimmerBox(height: 7, width: 7, radius: 99),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: _ShimmerBox(height: 7, width: 7, radius: 99),
            ),
          ],
        ),
      ],
    );
  }
}

/// ظٹط·ط§ط¨ظ‚ [_SectionHeader]: ط¹ظ†ظˆط§ظ† + "ط¹ط±ط¶ ط§ظ„ظƒظ„".
class _ShimmerSectionHeaderRow extends StatelessWidget {
  const _ShimmerSectionHeaderRow({required this.shortTitle});

  final bool shortTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ShimmerBox(
          height: 22,
          width: shortTitle ? 72 : 160,
          radius: 8,
        ),
        const Spacer(),
        const _ShimmerBox(height: 16, width: 56, radius: 6),
      ],
    );
  }
}

/// ظٹط·ط§ط¨ظ‚ [HomeServiceGrid]: طµظپ ط£ظپظ‚ظٹ ظ‚ط§ط¨ظ„ ظ„ظ„طھظ…ط±ظٹط±طŒ 82أ—100طŒ ظپط±ط§ط؛ 10.
class _ShimmerServiceGridFourCol extends StatelessWidget {
  const _ShimmerServiceGridFourCol();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeServiceGrid.tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (_, __) =>
            const SizedBox(width: HomeServiceGrid.tileSpacing),
        itemBuilder: (_, __) => const _ShimmerBox(
          height: HomeServiceGrid.tileHeight,
          width: HomeServiceGrid.tileWidth,
          radius: 14,
        ),
      ),
    );
  }
}

class _TopGreetingRow extends StatelessWidget {
  const _TopGreetingRow({
    required this.displayName,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.unreadNotifications,
  });

  final String displayName;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final int unreadNotifications;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = displayName.trim().isEmpty ? 'home.greetingDefault'.tr : displayName.trim();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          GestureDetector(
            onTap: onNotificationsTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: cs.onSurface,
                  ),
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'home.greeting'.trParams({'name': name}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'home.whatToOrder'.tr,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
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


class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionText,
    this.onActionTap,
  });

  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        if (actionText != null && onActionTap != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ShimmerRestaurantsRow extends StatelessWidget {
  const _ShimmerRestaurantsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => const SizedBox(
          width: 132,
          child: _ShimmerBox(radius: 12),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const _ShimmerBox({this.height = 100, this.width, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
