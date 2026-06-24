import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/navigation/home_bottom_bar.dart';
import 'package:najiz_go_express/core/navigation/main_bottom_nav.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key, this.token});

  final String? token;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('wallet.title'.tr),
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
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
