import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/data/models/offer_model.dart';
import 'package:najiz_go_express/data/models/service_model.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
import 'package:najiz_go_express/features/home/models/user_order.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/home_restaurant_card.dart';
import 'package:najiz_go_express/features/home/widgets/home_service_grid.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';
import 'package:najiz_go_express/features/home/views/all_services_screen.dart';
import 'package:najiz_go_express/features/home/views/restaurant_products_screen.dart';
import 'package:shimmer/shimmer.dart';

void _openAllServicesPage(HomeController controller) {
  final orderedServices = _orderedHomeServices(controller.services);
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
    final controller = Get.put(HomeController(token: token));
    final authState = Get.find<AuthStateManager>();

    return Scaffold(
      backgroundColor: Colors.white,
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
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                _TopGreetingRow(
                  displayName: controller.displayName.value,
                  onProfileTap: () => MainBottomNav.onTap(
                    index: 3,
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
                const SizedBox(height: 12),
                if (controller.errorMessage.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      controller.errorMessage.value!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                Obx(() {
                  final offers = controller.offers.toList(growable: false);
                  return _HeroPromoSlider(
                    offers: offers,
                    onTap: () {
                      final orderedServices = _orderedHomeServices(
                        controller.services,
                      );
                      if (orderedServices.isNotEmpty) {
                        controller.onServiceTap(orderedServices.first);
                      }
                    },
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
                  title: 'الخدمات',
                  actionText: 'عرض الكل',
                  onActionTap: () => _openAllServicesPage(controller),
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
                      return HomeServiceGrid(
                        services: orderedServices.take(4).toList(growable: false),
                        onTap: (_) => _openAllServicesPage(controller),
                      );
                    },
                  ),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'المطاعم الأكثر طلباً',
                  actionText: 'عرض الكل',
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
                  Text(
                    'home.noRestaurants'.tr,
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  SizedBox(
                    height: 188,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.filteredVendors.length,
                      separatorBuilder: (_, unusedIndex) =>
                          const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final vendor = controller.filteredVendors[index];
                        return HomeRestaurantCard(
                          name: vendor.name,
                          imageUrl: vendor.image ?? vendor.logo,
                          rating: vendor.rating,
                          subtitle: vendor.description,
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
    final n = labels.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(n, (index) {
          final isActive = index == currentStep;
          final isDone = index < currentStep;
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
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFFE5E7EB),
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
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFF1F3F5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone || isActive
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Icon(
                          icons[index],
                          size: 15,
                          color: isActive
                              ? Colors.white
                              : const Color(0xFF9CA3AF),
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
                          ? const Color(0xFF111827)
                          : const Color(0xFF9CA3AF),
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

/// Left-to-right mark before Latin/digits so RTL UI shows: «طلب تكسي رقم CEC7E1»
/// instead of the bidirectional jump «CEC7E1 … رقم …».
String _orderTitleRtlWithLatinToken({
  required String prefix,
  required String numberPrefix,
  required String token,
}) {
  const lrm = '\u200e';
  return '$prefix $numberPrefix $lrm$token';
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
    final currentStep = _activeStepIndex(order);
    const labels = ['تم الطلب', 'في الطريق', 'قريباً', 'تم الوصول'];
    const icons = [
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
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDEFF3)),
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
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.directions_car_outlined,
                      size: 16,
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
                              Text(
                                _orderTitle(order),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                labels[currentStep.clamp(
                                  0,
                                  labels.length - 1,
                                )],
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
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
                            color: const Color(0xFFEDEFF2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF6B7280),
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
      'home.foodStepDriverAssigned',
      'home.foodStepOnWay',
      'home.foodStepDelivered',
    ];
  }

  int _activeStepIndex(UserOrder order) {
    final status = order.status.toLowerCase();
    final dispatch = order.dispatchStatus.toLowerCase();
    if (status == 'delivered' || status == 'completed') return 3;
    if (status == 'on_way' || status == 'picked_up') return 1;
    if (status == 'on_the_way_to_pickup' || status == 'near_destination') return 2;
    if (status == 'accepted' || dispatch == 'accepted' || dispatch == 'assigned') return 0;
    return 0;
  }

  String _orderTitle(UserOrder order) {
    final prefix = switch (order.type.toLowerCase()) {
      'shipping' => 'home.orderShipping'.tr,
      'taxi' => 'home.orderTaxi'.tr,
      'stores' || 'store' => 'home.orderStore'.tr,
      _ => 'home.orderFood'.tr,
    };
    final token = _compactOrderToken(order.orderNumber, order.id);
    return _orderTitleRtlWithLatinToken(
      prefix: prefix,
      numberPrefix: 'home.orderNumberPrefix'.tr,
      token: token,
    );
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
    final name = displayName.trim().isEmpty ? 'عميلنا' : displayName.trim();
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
                    color: const Color(0xFFF2F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
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
                  'مرحباً، $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ماذا تريد طلبه اليوم؟',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Color(0xFF6B7280),
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

class _HeroPromoSlider extends StatefulWidget {
  const _HeroPromoSlider({required this.offers, required this.onTap});

  final List<OfferModel> offers;
  final VoidCallback onTap;

  @override
  State<_HeroPromoSlider> createState() => _HeroPromoSliderState();
}

class _HeroPromoSliderState extends State<_HeroPromoSlider> {
  static const _autoAdvanceInterval = Duration(seconds: 3);

  late final PageController _pageController;
  int _pageIndex = 0;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restartAutoPlay());
  }

  @override
  void didUpdateWidget(covariant _HeroPromoSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_effectivePageCount(oldWidget.offers) !=
            _effectivePageCount(widget.offers) ||
        oldWidget.offers.length != widget.offers.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restartAutoPlay());
    }
  }

  int _effectivePageCount(List<OfferModel> offers) {
    if (offers.isEmpty) return 1;
    if (offers.length == 1) return 3;
    return offers.length;
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _restartAutoPlay() {
    _autoTimer?.cancel();
    if (_pageCount < 2) return;
    _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) => _advanceOnePage());
  }

  void _advanceOnePage() {
    if (!mounted || !_pageController.hasClients || _pageCount < 2) return;
    final next = (_pageIndex + 1) % _pageCount;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeInOutCubic,
    );
  }

  /// PageView length: duplicate a single real offer so the carousel can auto-advance.
  int get _pageCount {
    if (widget.offers.isEmpty) return 1;
    if (widget.offers.length == 1) return 3;
    return widget.offers.length;
  }

  bool get _showPageDots => widget.offers.length > 1;

  String? _imageAt(int index) {
    if (widget.offers.isEmpty) return null;
    final i = widget.offers.length == 1 ? 0 : index;
    final url = widget.offers[i].image?.toString().trim();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 186,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pageCount,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _HeroPromoSlide(
                    imageUrl: _imageAt(index),
                    onTap: widget.onTap,
                  ),
                );
              },
            ),
          ),
        ),
        if (_showPageDots) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.offers.length, (i) {
              final active = i == _pageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : const Color(0xFFCBD5E1).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _HeroPromoSlide extends StatelessWidget {
  const _HeroPromoSlide({
    required this.onTap,
    this.imageUrl,
  });

  final VoidCallback onTap;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final bgUrl = imageUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 186,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bgUrl != null && bgUrl.isNotEmpty)
                  Image.network(bgUrl, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF111319).withValues(alpha: 0.88),
                        const Color(0xFF111319).withValues(alpha: 0.36),
                      ],
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Spacer(),
                      const Text(
                        'رحلتك القادمة\nتبدأ براحة تامة',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'خدمة تكسي رقمية آمنة وسريعة',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'احجز الآن',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.chevron_right_rounded, size: 18),
                            ],
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
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const Spacer(),
        if (actionText != null && onActionTap != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionText!,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
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
