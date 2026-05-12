import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/theme_controller.dart';
import 'package:najiz_go_express/features/auth/views/login_screen.dart';
import 'package:najiz_go_express/features/auth/views/signup_screen.dart';
import 'package:najiz_go_express/features/home/controllers/profile_controller.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';
import 'package:najiz_go_express/features/home/views/my_orders_screen.dart';
import 'package:najiz_go_express/features/home/views/profile_address_editor_screen.dart';
import 'package:najiz_go_express/features/home/views/favorites_screen.dart';
import 'package:najiz_go_express/features/home/views/referral_coupon_screen.dart';
import 'package:najiz_go_express/features/home/views/profile_settings_screen.dart';
import 'package:najiz_go_express/features/home/views/search_screen.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';
import 'package:najiz_go_express/features/support/views/support_chat_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profileLogoAsset = isDark
        ? 'assets/logo_dark.png'
        : 'assets/logo_light.png';
    final auth = Get.find<AuthStateManager>();
    final controller = Get.put(ProfileController(), tag: 'profile-controller');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 4,
        onTap: (index) =>
            MainBottomNav.onTap(index: index, currentIndex: 4, token: token),
      ),
      body: SafeArea(
        child: Obx(() {
          final profile = controller.profile.value;
          final isGuest = auth.isGuest;
          return RefreshIndicator(
            onRefresh: controller.loadProfile,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'profile.title'.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        final currentToken = auth.token.value;
                        Get.to(
                          () => ProfileSettingsScreen(
                            token: (currentToken != null &&
                                    currentToken.trim().isNotEmpty)
                                ? currentToken
                                : null,
                          ),
                        );
                      },
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 152,
                        height: 152,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: ClipOval(
                          child: Image.asset(
                            profileLogoAsset,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isGuest
                            ? 'profile.guest'.tr
                            : (profile?.name ?? 'profile.user'.tr),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          color: cs.onSurface,
                        ),
                      ),
                      if (!isGuest) ...[
                        const SizedBox(height: 2),
                        Text(
                          'profile.premiumMember'.tr,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        profile?.email ?? 'profile.noEmail'.tr,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.phone ?? 'profile.noPhone'.tr,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (isGuest)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Get.to(() => const SignupScreen()),
                                child: Text('profile.createAccount'.tr),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Get.to(() => const LoginScreen()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text('profile.login'.tr),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cs.surfaceContainerHigh,
                              cs.surfaceContainerLow,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.group,
                            size: 72,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'profile.inviteFriend'.tr,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'profile.inviteSubtitle'.tr,
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _ProfileReferralCodeBlock(
                              controller: controller,
                              isGuest: isGuest,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'profile.accountSettings'.tr,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 10),
                _DarkModeProfileCard(),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.location_on_outlined,
                  title: 'profile.addresses'.tr,
                  subtitle: profile?.address ?? 'profile.addAddress'.tr,
                  onTap: () => Get.to(
                    () => ProfileAddressEditorScreen(
                      initialAddress: profile?.address,
                      onSave: controller.saveAddress,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.search_rounded,
                  title: 'البحث',
                  subtitle: 'ابحث عن المطاعم والمتاجر والمنتجات',
                  onTap: () => Get.to(() => SearchScreen(token: token)),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.favorite_rounded,
                  title: 'favorites.title'.tr,
                  subtitle: 'favorites.subtitle'.tr,
                  onTap: () {
                    if (auth.isGuest) {
                      Get.to(() => const LoginScreen());
                      return;
                    }
                    Get.to(() => const FavoritesScreen());
                  },
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.card_giftcard_rounded,
                  title: 'الإحالة والكوبونات',
                  subtitle: 'شارك كودك واطلع على كوبوناتك',
                  onTap: () {
                    final currentToken = auth.token.value;
                    if (currentToken == null || currentToken.trim().isEmpty) {
                      Get.to(() => const LoginScreen());
                      return;
                    }
                    Get.to(() => ReferralCouponScreen(token: currentToken));
                  },
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.history,
                  title: 'profile.orderHistory'.tr,
                  subtitle: 'profile.showOrders'.tr,
                  onTap: () {
                    if (auth.isGuest) {
                      Get.to(() => const LoginScreen());
                      return;
                    }
                    final currentToken = auth.token.value;
                    if (currentToken == null || currentToken.trim().isEmpty) {
                      return;
                    }
                    Get.to(() => MyOrdersScreen(token: currentToken));
                  },
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.help_outline,
                  title: 'profile.support'.tr,
                  subtitle: 'profile.supportSubtitle'.tr,
                  onTap: () {
                    if (auth.isGuest) {
                      Get.to(() => const LoginScreen());
                      return;
                    }
                    final currentToken = auth.token.value;
                    if (currentToken == null || currentToken.trim().isEmpty) {
                      return;
                    }
                    Get.to(() => SupportChatScreen(token: currentToken));
                  },
                ),
                const SizedBox(height: 18),
                if (!isGuest)
                  Obx(
                    () => OutlinedButton.icon(
                      onPressed: controller.isLoggingOut.value
                          ? null
                          : () async {
                              final confirmed = await AppPopupDialog.show<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  backgroundColor:
                                      Theme.of(dialogContext).colorScheme.surface,
                                  surfaceTintColor: Colors.transparent,
                                  title: Text('profile.logoutTitle'.tr),
                                  content: Text('profile.logoutConfirmMessage'.tr),
                                  actions: [
                                    OutlinedButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                      child: Text('common.cancel'.tr),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: Text('common.confirm'.tr),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              await controller.logout();
                              Get.offAll(() => const HomeScreen());
                              AppSnackbar.show(
                                'common.done'.tr,
                                'profile.logoutSuccess'.tr,
                              );
                            },
                      icon: controller.isLoggingOut.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout),
                      label: Text(
                        controller.isLoggingOut.value
                            ? 'profile.loggingOut'.tr
                            : 'profile.logout'.tr,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC2410C),
                        side: const BorderSide(color: Color(0xFFF2C6A4)),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
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

class _ProfileReferralCodeBlock extends StatelessWidget {
  const _ProfileReferralCodeBlock({
    required this.controller,
    required this.isGuest,
  });

  final ProfileController controller;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Guest path must stay outside [Obx]: an [Obx] with no `.obs` reads throws at runtime
    // and shows the global [ErrorWidget] (black box + displayError).
    if (isGuest) {
      return Text(
        'profile.referralGuestHint'.tr,
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      );
    }

    return Obx(() {
      if (controller.isLoading.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }

      final info = controller.referralInfo.value;
      final code = (info?.referralCode ?? '').trim();
      final count = info?.referralsCount ?? 0;

      if (code.isEmpty) {
        return Text(
          'profile.referralLoadError'.tr,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${'profile.referralCodeLabel'.tr} ',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: code,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'profile.referralsCount'.trParams({'count': '$count'}),
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              AppSnackbar.show(
                'profile.inviteFriend'.tr,
                'profile.copiedReferralCode'.trParams({'code': code}),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('profile.copyCode'.tr),
          ),
        ],
      );
    });
  }
}

class _DarkModeProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tc = Get.find<ThemeController>();
    return Obx(
      () {
        final dark = tc.isDark.value;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  dark ? Icons.dark_mode_rounded : Icons.light_mode_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'profile.darkMode'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'profile.darkModeSubtitle'.tr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.62),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: dark,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.45),
                thumbColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? AppColors.primary
                      : null,
                ),
                onChanged: (v) => tc.setDark(v),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              Theme.of(context).cardTheme.color ?? cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.62),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
