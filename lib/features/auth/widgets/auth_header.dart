import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/theme/text_styles.dart';

class AuthHeader extends StatelessWidget {
  final String? title;
  final String? subtitle;

  const AuthHeader({
    super.key,
    this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset =
        isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Image.asset(
              logoAsset,
              height: 132,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const Center(
                child: Icon(Icons.local_shipping, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(title ?? 'login.title'.tr, style: AppTextStyles.heading1),
        const SizedBox(height: 6),
        Text(subtitle ?? 'login.subtitle'.tr, style: AppTextStyles.subtitle),
      ],
    );
  }
}
