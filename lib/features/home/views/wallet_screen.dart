import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('المحفظة'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 2,
        onTap: (index) => MainBottomNav.onTap(
          index: index,
          currentIndex: 2,
          token: token,
        ),
      ),
      body: const Center(
        child: Text(
          'المحفظة قيد التطوير',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
