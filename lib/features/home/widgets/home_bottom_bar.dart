import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE9EEF5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120B1B34),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BottomItem(
                icon: Icons.home_rounded,
                text: 'nav.home'.tr,
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
                icon: Icons.inventory_2_rounded,
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
                icon: Icons.person_rounded,
                text: 'nav.profile'.tr,
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
    final iconColor = active ? Colors.white : const Color(0xFF71839B);
    final textColor = active ? const Color(0xFF12253A) : const Color(0xFF7F90A8);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 36 : 32,
              height: active ? 36 : 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active
                    ? const LinearGradient(
                        colors: [Color(0xFFFFAE45), Color(0xFFFF8A00)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : null,
                color: active ? null : const Color(0xFFF2F5FA),
                boxShadow: active
                    ? const [
                        BoxShadow(
                          color: Color(0x33FF8A00),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : const [],
              ),
              child: Icon(icon, size: active ? 20 : 18, color: iconColor),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 1),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 14 : 0,
              height: active ? 2 : 0,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A00),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
