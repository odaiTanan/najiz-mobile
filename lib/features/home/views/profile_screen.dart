import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/auth/views/login_screen.dart';
import 'package:najiz_go_express/features/auth/views/signup_screen.dart';
import 'package:najiz_go_express/features/home/controllers/profile_controller.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';
import 'package:najiz_go_express/features/home/views/my_orders_screen.dart';
import 'package:najiz_go_express/features/home/views/profile_address_editor_screen.dart';
import 'package:najiz_go_express/features/home/views/wallet_screen.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';
import 'package:najiz_go_express/features/support/views/support_chat_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthStateManager>();
    final controller = Get.put(ProfileController(), tag: 'profile-controller');
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 3,
        onTap: (index) =>
            MainBottomNav.onTap(index: index, currentIndex: 3, token: token),
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
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          Get.snackbar('profile.settings'.tr, 'common.soon'.tr),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8ECF2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F9),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE3EAF3)),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/najiz_go_express_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isGuest
                            ? 'profile.guest'.tr
                            : (profile?.name ?? 'profile.user'.tr),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          color: Color(0xFF1F2A37),
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.phone ?? 'profile.noPhone'.tr,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8ECF2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        height: 140,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFEEF2F7), Color(0xFFDCE4EF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.group,
                            size: 72,
                            color: Color(0xFF8FA3BF),
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
                                color: Color(0xFF1F2A37),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'profile.inviteSubtitle'.tr,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'profile.yourCode'.tr,
                                    style: TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    const code = 'LUKAS10';
                                    await Clipboard.setData(
                                      const ClipboardData(text: code),
                                    );
                                    Get.snackbar(
                                      'profile.inviteFriend'.tr,
                                      'profile.copiedReferralCode'.tr,
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text('profile.copyCode'.tr),
                                ),
                              ],
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
                    color: Color(0xFFA1ACC0),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
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
                  icon: Icons.credit_card_outlined,
                  title: 'profile.paymentMethods'.tr,
                  subtitle: 'profile.managePaymentMethods'.tr,
                  onTap: () => Get.to(() => const WalletScreen()),
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
                  icon: Icons.language,
                  title: 'profile.language'.tr,
                  subtitle: Get.locale?.languageCode == 'en'
                      ? 'profile.english'.tr
                      : 'profile.arabic'.tr,
                  onTap: () => _openLanguageSheet(context),
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
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: Text('profile.logoutTitle'.tr),
                                  content: Text('profile.logoutConfirmMessage'.tr),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                      child: Text('common.cancel'.tr),
                                    ),
                                    ElevatedButton(
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
                              Get.snackbar(
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8ECF2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

Future<void> _openLanguageSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
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
            Text(
              'profile.language'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'اختر اللغة المناسبة للتطبيق',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            _LanguageOptionTile(
              label: 'profile.english'.tr,
              selected: Get.locale?.languageCode == 'en',
              onTap: () async {
                await Get.updateLocale(const Locale('en', 'US'));
                await ProfileController.persistLocale('en');
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 10),
            _LanguageOptionTile(
              label: 'profile.arabic'.tr,
              selected: Get.locale?.languageCode == 'ar',
              onTap: () async {
                await Get.updateLocale(const Locale('ar', 'SA'));
                await ProfileController.persistLocale('ar');
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
            color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
