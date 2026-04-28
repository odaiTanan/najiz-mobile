import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/data/models/service_model.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
import 'package:najiz_go_express/features/home/models/user_order.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/home_header_section.dart';
import 'package:najiz_go_express/features/home/widgets/home_offer_banner.dart';
import 'package:najiz_go_express/features/home/widgets/home_restaurant_card.dart';
import 'package:najiz_go_express/features/home/widgets/home_section_title.dart';
import 'package:najiz_go_express/features/home/widgets/home_service_card.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatelessWidget {
  final String? token;

  const HomeScreen({super.key, this.token});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController(token: token));
    final authState = Get.find<AuthStateManager>();

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 0,
        onTap: (index) => MainBottomNav.onTap(
          index: index,
          currentIndex: 0,
          token: controller.activeToken,
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const _HomeShimmerSkeleton();
          }

          return RefreshIndicator(
            onRefresh: controller.loadHomeData,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                HomeHeaderSection(
                  displayName: controller.displayName.value,
                  isGuest: authState.isGuest,
                  onProfileTap: () => MainBottomNav.onTap(
                    index: 3,
                    currentIndex: 0,
                    token: controller.activeToken,
                  ),
                  onNotificationsTap: controller.openNotifications,
                  unreadNotifications: controller.unreadNotifications.value,
                ),
                const SizedBox(height: 10),
                Obx(
                  () => authState.isGuest
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'home.guestBrowsing'.tr,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                if (controller.errorMessage.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      controller.errorMessage.value!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                HomeOfferBanner(offers: controller.offers),
                if (controller.primaryActiveOrder != null) ...[
                  const SizedBox(height: 12),
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
                HomeSectionTitle(
                  title: 'home.ourServices'.tr,
                  actionText: 'home.showAll'.tr,
                ),
                const SizedBox(height: 10),
                if (controller.services.isEmpty)
                  Text(
                    'home.noServices'.tr,
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  Builder(
                    builder: (_) {
                      final orderedServices = _orderedHomeServices(
                        controller.services,
                      );
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orderedServices.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.93,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (_, index) {
                          final service = orderedServices[index];
                          return HomeServiceCard(
                            title: service.name,
                            imageUrl: service.icon,
                            selected:
                                controller.selectedServiceId.value == service.id,
                            onTap: () => controller.onServiceTap(service),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 18),
                HomeSectionTitle(title: 'home.mostOrderedRestaurants'.tr),
                const SizedBox(height: 10),
                if (controller.vendors.isEmpty)
                  Text(
                    'home.noRestaurants'.tr,
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  SizedBox(
                    height: 188,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.vendors.length,
                      separatorBuilder: (_, unusedIndex) =>
                          const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final vendor = controller.vendors[index];
                        return HomeRestaurantCard(
                          name: vendor.name,
                          imageUrl: vendor.image ?? vendor.logo,
                          rating: vendor.rating,
                          onTap: () => controller.onRestaurantCardTap(vendor),
                        );
                      },
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
    final steps = _stepsForType(order.type);
    final currentStep = _activeStepIndex(order);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7ECF4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'home.activeOrderNow'.tr,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _orderTitle(order),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(steps.length, (index) {
                final done = index <= currentStep;
                final isCurrent = index == currentStep;
                final isLast = index == steps.length - 1;
                final isFuture = index > currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: isCurrent ? 38 : 32,
                        height: isCurrent ? 38 : 32,
                        decoration: BoxDecoration(
                          gradient: done
                              ? const LinearGradient(
                                  colors: [Color(0xFFFFA238), Color(0xFFFF8A00)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                )
                              : const LinearGradient(
                                  colors: [Color(0xFFF5F7FB), Color(0xFFE9EEF5)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: done ? const Color(0xFFFFC278) : const Color(0xFFD8E0EC),
                            width: isCurrent ? 1.8 : 1.1,
                          ),
                          boxShadow: done
                              ? const [
                                  BoxShadow(
                                    color: Color(0x30FF8A00),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Icon(
                          _iconForStep(order.type, index),
                          size: isCurrent ? 21 : 18,
                          color: done ? Colors.white : const Color(0xFF95A4BA),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            height: 3,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              gradient: isFuture
                                  ? const LinearGradient(
                                      colors: [Color(0xFFE6ECF4), Color(0xFFDDE5EF)],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFFFFAF4A), Color(0xFFFF8A00)],
                                    ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                steps[currentStep.clamp(0, steps.length - 1)].tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
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

  List<String> _stepsForType(String type) {
    final t = type.toLowerCase();
    if (t == 'shipping') {
      return const [
        'home.shippingStepAccepted',
        'home.shippingStepDriverToPickup',
        'home.shippingStepPickedUp',
        'home.shippingStepOnWay',
        'home.shippingStepDelivered',
      ];
    }
    if (t == 'taxi') {
      return const [
        'home.taxiStepAccepted',
        'home.taxiStepDriverToPickup',
        'home.taxiStepStarted',
        'home.taxiStepOnWay',
        'home.taxiStepFinished',
      ];
    }
    return const [
      'home.foodStepConfirmed',
      'home.foodStepPreparing',
      'home.foodStepOnWay',
      'home.foodStepDelivered',
    ];
  }

  int _activeStepIndex(UserOrder order) {
    final type = order.type.toLowerCase();
    final status = order.status.toLowerCase();
    final dispatch = order.dispatchStatus.toLowerCase();

    if (type == 'shipping') {
      if (status == 'on_way') return 3;
      if (status == 'picked_up') return 2;
      if (status == 'on_the_way_to_pickup') return 1;
      if (status == 'accepted' || dispatch == 'accepted' || dispatch == 'assigned') {
        return 0;
      }
      return 0;
    }

    if (type == 'taxi') {
      if (status == 'on_way') return 3;
      if (status == 'picked_up') return 2;
      if (status == 'on_the_way_to_pickup') return 1;
      if (status == 'accepted' || dispatch == 'accepted' || dispatch == 'assigned') {
        return 0;
      }
      return 0;
    }

    // Food/stores generic flow.
    if (status == 'on_way') return 2;
    if (status == 'ready') return 2;
    if (status == 'preparing') return 1;
    if (status == 'accepted' || dispatch == 'accepted' || dispatch == 'assigned') {
      return 0;
    }
    if (status == 'pending') return 0;
    return 0;
  }

  IconData _iconForStep(String type, int index) {
    final t = type.toLowerCase();
    if (t == 'shipping') {
      const icons = [
        Icons.verified_rounded,
        Icons.delivery_dining_rounded,
        Icons.inventory_rounded,
        Icons.local_shipping_rounded,
        Icons.check_circle_rounded,
      ];
      return icons[index.clamp(0, icons.length - 1)];
    }
    if (t == 'taxi') {
      const icons = [
        Icons.verified_rounded,
        Icons.local_taxi_rounded,
        Icons.pin_drop_rounded,
        Icons.route_rounded,
        Icons.check_circle_rounded,
      ];
      return icons[index.clamp(0, icons.length - 1)];
    }
    const icons = [
      Icons.receipt_rounded,
      Icons.restaurant_menu_rounded,
      Icons.two_wheeler_rounded,
      Icons.check_circle_rounded,
    ];
    return icons[index.clamp(0, icons.length - 1)];
  }

  String _orderTitle(UserOrder order) {
    final prefix = switch (order.type.toLowerCase()) {
      'shipping' => 'home.orderShipping'.tr,
      'taxi' => 'home.orderTaxi'.tr,
      'stores' || 'store' => 'home.orderStore'.tr,
      _ => 'home.orderFood'.tr,
    };
    final token = _compactOrderToken(order.orderNumber, order.id);
    return '$prefix ${'home.orderNumberPrefix'.tr} $token';
  }

  String _compactOrderToken(String orderNumber, int fallbackId) {
    final chunks = RegExp(r'[A-Za-z0-9]+').allMatches(orderNumber);
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
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9EDF3),
      highlightColor: const Color(0xFFF7F9FC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: const [
          _ShimmerBox(height: 40, radius: 14),
          SizedBox(height: 14),
          _ShimmerBox(height: 48, radius: 14),
          SizedBox(height: 12),
          _ShimmerBox(height: 138, radius: 16),
          SizedBox(height: 18),
          _ShimmerBox(height: 18, width: 120, radius: 8),
          SizedBox(height: 10),
          _ShimmerServiceGrid(),
          SizedBox(height: 18),
          _ShimmerBox(height: 18, width: 170, radius: 8),
          SizedBox(height: 10),
          _ShimmerRestaurantsRow(),
        ],
      ),
    );
  }
}

class _ShimmerServiceGrid extends StatelessWidget {
  const _ShimmerServiceGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.93,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (_, index) => const _ShimmerBox(radius: 16),
    );
  }
}

List<ServiceModel> _orderedHomeServices(List<ServiceModel> services) {
  final ranked = [...services];
  ranked.sort((a, b) => _serviceSortRank(a).compareTo(_serviceSortRank(b)));
  return ranked;
}

int _serviceSortRank(ServiceModel service) {
  final name = service.name.trim().toLowerCase();
  final id = service.id;

  if (id == 5 || name.contains('taxi') || name.contains('تكسي')) return 0;
  if (id == 1 || name.contains('restaurant') || name.contains('مطعم')) return 1;
  if (id == 3 || name.contains('store') || name.contains('متجر')) return 2;
  if (id == 2 || name.contains('shipping') || name.contains('شحن')) return 3;

  return 100 + id;
}

class _ShimmerRestaurantsRow extends StatelessWidget {
  const _ShimmerRestaurantsRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, index) => const SizedBox(width: 10),
        itemBuilder: (_, index) =>
            const SizedBox(width: 180, child: _ShimmerBox(radius: 14)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
