import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      child: Container(
        height: 74,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEFF2F6))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BottomItem(
              icon: Icons.home_rounded,
              text: 'nav.home'.tr,
              active: !serviceActive && activeIndex == 0,
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
              icon: Icons.assignment_outlined,
              text: 'nav.orders'.tr,
              active: activeIndex == 1,
              onTap: () => onTap?.call(1),
            ),
            _BottomItem(
              icon: Icons.search_rounded,
              text: 'بحث',
              active: activeIndex == 2,
              onTap: () => onTap?.call(2),
            ),
            _BottomItem(
              icon: Icons.person_outline_rounded,
              text: 'nav.profile'.tr,
              active: activeIndex == 3,
              onTap: () => onTap?.call(3),
            ),
          ],
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
    const activeColor = Color(0xFFC87422);
    final iconColor = active ? activeColor : const Color(0xFF1F2937);
    final textColor = active ? activeColor : const Color(0xFF6B7280);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: active ? 22 : 21, color: iconColor),
            const SizedBox(height: 3),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 18 : 0,
              height: active ? 2.5 : 0,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
