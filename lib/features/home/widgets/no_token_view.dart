import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/auth/views/login_screen.dart';

class NoTokenView extends StatelessWidget {
  final String? error;

  const NoTokenView({super.key, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (error != null)
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            const SizedBox(height: 16),
            const Text(
              'You need to login to load protected APIs.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => Get.offAll(() => const LoginScreen()),
              child: const Text('Back to login'),
            ),
          ],
        ),
      ),
    );
  }
}
