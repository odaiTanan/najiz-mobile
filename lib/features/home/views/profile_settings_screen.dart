import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/views/cms_dynamic_page_screen.dart';
import 'package:najiz_go_express/features/home/views/faq_screen.dart';

/// شاشة الإعدادات: روابط ديناميكية لصفحات المحتوى من الـ API.
class ProfileSettingsScreen extends StatelessWidget {
  const ProfileSettingsScreen({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          'profile.settings'.tr,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: cs.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'profile.settingsMenuSection'.tr,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.quiz_outlined,
            title: 'profile.faqTitle'.tr,
            subtitle: 'profile.faqSubtitle'.tr,
            onTap: () => Get.to(() => FaqScreen(token: token)),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.info_outline_rounded,
            title: 'profile.aboutUsTitle'.tr,
            subtitle: 'profile.aboutUsSubtitle'.tr,
            onTap: () => Get.to(
              () => CmsDynamicPageScreen(
                slug: 'about-us',
                token: token,
                fallbackTitle: 'profile.aboutUsTitle'.tr,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            icon: Icons.privacy_tip_outlined,
            title: 'profile.privacyTitle'.tr,
            subtitle: 'profile.privacySubtitle'.tr,
            onTap: () => Get.to(
              () => CmsDynamicPageScreen(
                slug: 'privacy-policy',
                token: token,
                fallbackTitle: 'profile.privacyTitle'.tr,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
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
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
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
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
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
