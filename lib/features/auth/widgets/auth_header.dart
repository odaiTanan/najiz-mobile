import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_images.dart';
import 'package:najiz_go_express/core/constants/app_strings.dart';
import 'package:najiz_go_express/core/theme/text_styles.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const AuthHeader({
    super.key,
    this.title = AppStrings.welcomeBack,
    this.subtitle = AppStrings.loginSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Image.asset(
              AppImages.logoNajizGo,
              height: 110,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.local_shipping, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(title, style: AppTextStyles.heading1),
        const SizedBox(height: 6),
        Text(subtitle, style: AppTextStyles.subtitle),
      ],
    );
  }
}

