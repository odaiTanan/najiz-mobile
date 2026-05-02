import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        title: Text('wallet.title'.tr),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      bottomNavigationBar: HomeBottomBar(
        activeIndex: -1,
        onTap: (index) => MainBottomNav.onTap(
          index: index,
          currentIndex: -1,
          token: token,
        ),
      ),
      body: Center(
        child: Text(
          'wallet.underDevelopment'.tr,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
