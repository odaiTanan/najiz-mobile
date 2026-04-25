import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

class HomeBottomBar extends StatelessWidget {
  const HomeBottomBar({
    super.key,
    this.activeIndex = 0,
    this.onTap,
    this.serviceText,
    this.serviceIcon,
    this.serviceActive = false,
    this.onServiceTap,
  });

  final int activeIndex;
  final ValueChanged<int>? onTap;
  final String? serviceText;
  final IconData? serviceIcon;
  final bool serviceActive;
  final VoidCallback? onServiceTap;

  @override
  Widget build(BuildContext context) {
    final hasServiceItem =
        serviceText != null &&
        serviceText!.trim().isNotEmpty &&
        serviceIcon != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDEDED)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomItem(
                icon: Icons.home_outlined,
                text: 'الرئيسية',
                active: activeIndex == 0,
                onTap: () => onTap?.call(0),
              ),
              if (hasServiceItem)
                _BottomItem(
                  icon: serviceIcon!,
                  text: serviceText!,
                  active: serviceActive,
                  onTap: onServiceTap,
                ),
              _BottomItem(
                icon: Icons.receipt_long_outlined,
                text: 'الطلبات',
                active: activeIndex == 1,
                onTap: () => onTap?.call(1),
              ),
              _BottomItem(
                icon: Icons.account_balance_wallet_outlined,
                text: 'المحفظة',
                active: activeIndex == 2,
                onTap: () => onTap?.call(2),
              ),
              _BottomItem(
                icon: Icons.person_outline,
                text: 'الملف الشخصي',
                active: activeIndex == 3,
                onTap: () => onTap?.call(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;
  final VoidCallback? onTap;

  const _BottomItem({
    required this.icon,
    required this.text,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 1),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
