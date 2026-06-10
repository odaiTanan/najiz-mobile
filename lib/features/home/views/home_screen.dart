import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/theme/theme_context.dart';
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
      body: SafeArea(
        child: Obx(() {
          final loading = controller.isLoading.value;
          final waitingNet = controller.homeWaitingNetwork.value;
          if (loading) {
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
            onRefresh: controller.loadHomeData,
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
                  return _HeroPromoSlider(
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
                      final orderedServices = _orderedHomeServices(
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
                  Text(
                    'home.noRestaurants'.tr,
                    style: TextStyle(color: context.uiSubtext),
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
                          vendorId: vendor.id,
                          vendorStatus: vendor.vendorStatus,
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
    final cs = Theme.of(context).colorScheme;
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

/// يزيل تسميات قد يرسلها الـ API مع [order_number] فتظهر كـ «رقم الطلب» قبل النص المطلوب.
String _stripDecorativeOrderNumberPrefix(String raw) {
  var s = raw.trim();
  s = s.replaceAll(
    RegExp(r'^(?:رقم\s*الطلب|Order\s*Number)\s*:?\s*', caseSensitive: false),
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
    final labels = [
      'home.orderStep1'.tr,
      'home.orderStep2'.tr,
      'home.orderStep3'.tr,
      'home.orderStep4'.tr,
    ];
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

/// يطابق [_TopGreetingRow]: أيقونة يسار + عمود نص يمين.
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

/// يطابق [_HeroPromoSlider] (ارتفاع 186 + شريط نقاط تقريبي).
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

/// يطابق [_SectionHeader]: عنوان + "عرض الكل".
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

/// يطابق [HomeServiceGrid]: صف أفقي قابل للتمرير، 82×100، فراغ 10.
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

class _HeroPromoSlider extends StatefulWidget {
  const _HeroPromoSlider({required this.offers, required this.onTap});

  final List<OfferModel> offers;
  final ValueChanged<OfferModel> onTap;

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

  OfferModel? _offerAt(int index) {
    if (widget.offers.isEmpty) return null;
    final i = widget.offers.length == 1 ? 0 : index;
    return widget.offers[i];
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
                    onTap: () {
                      final offer = _offerAt(index);
                      if (offer == null) return;
                      widget.onTap(offer);
                    },
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
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.9),
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
    final cs = Theme.of(context).colorScheme;
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
                        cs.scrim.withValues(alpha: 0.82),
                        cs.scrim.withValues(alpha: 0.34),
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
                      Text(
                        'taxi.tagline'.tr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'home.bookNow'.tr,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: cs.onSurface,
                              ),
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
