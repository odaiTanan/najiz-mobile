import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/constants/app_images.dart';

class SocialButton extends StatelessWidget {
  final String text;
  final String assetPath;
  final VoidCallback? onPressed;

  const SocialButton({
    super.key,
    required this.text,
    required this.assetPath,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final socialIcon = switch (assetPath) {
      AppImages.logoGoogle => Icons.g_mobiledata_rounded,
      AppImages.logoApple => Icons.apple,
      _ => Icons.login,
    };

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.inputBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(socialIcon, size: 20),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

