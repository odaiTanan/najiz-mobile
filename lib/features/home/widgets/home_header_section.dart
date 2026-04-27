import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

class HomeHeaderSection extends StatelessWidget {
  final String? displayName;
  final bool isGuest;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final int unreadNotifications;

  const HomeHeaderSection({
    super.key,
    required this.displayName,
    required this.isGuest,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.unreadNotifications,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedName = displayName?.trim() ?? '';
    final fallbackName = 'عميلنا';
    final shownName = normalizedName.isEmpty ? fallbackName : normalizedName;
    final subtitle = isGuest
        ? 'أهلاً بك في ناجز غو اكسبرس'
        : 'مرحباً، $shownName';

    return Row(
      children: [
        InkWell(
          onTap: onProfileTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF5E5D6)),
            ),
            child: const Icon(Icons.person, color: AppColors.primary, size: 18),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isGuest ? 'مرحباً بك' : 'أهلاً بعودتك',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .8,
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: onNotificationsTap,
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEDEDED)),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: AppColors.textPrimary,
                  size: 19,
                ),
              ),
              if (unreadNotifications > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.2),
                    ),
                    child: Text(
                      unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
