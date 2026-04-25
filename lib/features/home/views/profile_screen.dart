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
                    const Expanded(
                      child: Center(
                        child: Text(
                          'الملف الشخصي',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.snackbar('الإعدادات', 'قريباً'),
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
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 44,
                            backgroundColor: const Color(0xFFF1F4F9),
                            child: Text(
                              _avatarText(profile?.name, isGuest),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 28,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isGuest ? 'ضيف' : (profile?.name ?? 'مستخدم'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          color: Color(0xFF1F2A37),
                        ),
                      ),
                      if (!isGuest) ...[
                        const SizedBox(height: 2),
                        const Text(
                          'عضو مميز',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        profile?.email ?? 'لا يوجد بريد إلكتروني',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.phone ?? 'لا يوجد رقم هاتف',
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
                                child: const Text('إنشاء حساب'),
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
                                child: const Text('تسجيل الدخول'),
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
                            const Text(
                              'ادعُ صديقاً',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                                color: Color(0xFF1F2A37),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'شارك التطبيق واحصل على خصم في طلبك القادم.',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'رمزك: LUKAS10',
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
                                      'الإحالة',
                                      'تم نسخ كود الإحالة $code',
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('نسخ الرمز'),
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
                const Text(
                  'إعدادات الحساب',
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
                  title: 'عناويني',
                  subtitle: profile?.address ?? 'أضف عنوان التوصيل',
                  onTap: () => _openAddressEditor(
                    context: context,
                    initialAddress: profile?.address,
                    onSave: controller.saveAddress,
                  ),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.credit_card_outlined,
                  title: 'طرق الدفع',
                  subtitle: 'إدارة بطاقات وطرق الدفع',
                  onTap: () => Get.to(() => const WalletScreen()),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.history,
                  title: 'سجل الطلبات',
                  subtitle: 'عرض الطلبات السابقة والحالية',
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
                  title: 'اللغة',
                  subtitle: 'العربية',
                  onTap: () => _openLanguageSheet(context),
                ),
                const SizedBox(height: 10),
                _ActionCard(
                  icon: Icons.help_outline,
                  title: 'المساعدة والدعم',
                  subtitle: 'الأسئلة الشائعة والتواصل مع الدعم',
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
                                  title: const Text('تسجيل الخروج'),
                                  content: const Text(
                                    'هل أنت متأكد من تسجيل الخروج من الحساب؟',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(
                                        dialogContext,
                                      ).pop(false),
                                      child: const Text('إلغاء'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(dialogContext).pop(true),
                                      child: const Text('تأكيد'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true) return;
                              await controller.logout();
                              Get.offAll(() => const HomeScreen());
                              Get.snackbar('تم', 'تم تسجيل الخروج بنجاح');
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
                            ? 'جارٍ تسجيل الخروج...'
                            : 'تسجيل الخروج',
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

String _avatarText(String? name, bool guest) {
  if (guest) return 'G';
  if (name == null || name.trim().isEmpty) return 'U';
  return name.trim().substring(0, 1).toUpperCase();
}

Future<void> _openAddressEditor({
  required BuildContext context,
  required String? initialAddress,
  required Future<void> Function(String) onSave,
}) async {
  final controller = TextEditingController(text: initialAddress ?? '');
  await showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('تعديل العنوان'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'اكتب عنوانك النصي'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final value = controller.text.trim();
              if (value.isEmpty) return;
              await onSave(value);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      );
    },
  );
  controller.dispose();
}

Future<void> _openLanguageSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE3EE),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(Icons.check_circle, color: AppColors.primary),
              title: Text('English (UK)'),
            ),
            const ListTile(
              leading: Icon(Icons.radio_button_unchecked),
              title: Text('العربية'),
            ),
          ],
        ),
      ),
    ),
  );
}
