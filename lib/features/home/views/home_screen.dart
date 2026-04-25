import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
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
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              children: [
                HomeHeaderSection(
                  displayName: controller.displayName.value,
                  isGuest: authState.isGuest,
                  onNotificationsTap: controller.openNotifications,
                  unreadNotifications: controller.unreadNotifications.value,
                ),
                const SizedBox(height: 8),
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
                          child: const Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'أنت تتصفح كضيف',
                                style: TextStyle(
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
                InkWell(
                  onTap: controller.openSupportChat,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8ECF2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.support_agent, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تواصل مع الدعم الفني',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
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
                const SizedBox(height: 16),
                const HomeSectionTitle(
                  title: 'خدماتنا',
                  actionText: 'عرض الكل',
                ),
                const SizedBox(height: 8),
                if (controller.services.isEmpty)
                  const Text(
                    'لا توجد خدمات',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.services.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemBuilder: (_, index) {
                      final service = controller.services[index];
                      return HomeServiceCard(
                        title: service.name,
                        imageUrl: service.icon,
                        selected:
                            controller.selectedServiceId.value == service.id,
                        onTap: () => controller.onServiceTap(service),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                const HomeSectionTitle(title: 'المطاعم الأكثر طلباً'),
                const SizedBox(height: 8),
                if (controller.vendors.isEmpty)
                  const Text(
                    'لا توجد مطاعم متاحة حالياً',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  SizedBox(
                    height: 188,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.vendors.length,
                      separatorBuilder: (_, unusedIndex) =>
                          const SizedBox(width: 10),
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

class _HomeShimmerSkeleton extends StatelessWidget {
  const _HomeShimmerSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9EDF3),
      highlightColor: const Color(0xFFF7F9FC),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        children: const [
          _ShimmerBox(height: 40, radius: 14),
          SizedBox(height: 12),
          _ShimmerBox(height: 48, radius: 14),
          SizedBox(height: 12),
          _ShimmerBox(height: 138, radius: 16),
          SizedBox(height: 16),
          _ShimmerBox(height: 18, width: 120, radius: 8),
          SizedBox(height: 8),
          _ShimmerServiceGrid(),
          SizedBox(height: 16),
          _ShimmerBox(height: 18, width: 170, radius: 8),
          SizedBox(height: 8),
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
        childAspectRatio: 1,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, index) => const _ShimmerBox(radius: 16),
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
