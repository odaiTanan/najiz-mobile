import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/profile/models/user_profile_model.dart';

class ProfileIdentitySummary extends StatelessWidget {
  const ProfileIdentitySummary({
    super.key,
    required this.profile,
  });

  final UserProfileModel? profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tierLabel = profile?.loyaltyTierLabel;
    final userTypeLabel = profile?.userTypeLabel;
    final points = profile?.loyaltyPoints;

    if ((tierLabel == null || tierLabel.isEmpty) &&
        (userTypeLabel == null || userTypeLabel.isEmpty) &&
        points == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        if (tierLabel != null && tierLabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            tierLabel,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (userTypeLabel != null && userTypeLabel.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'profile.userType'.trParams({'type': userTypeLabel}),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (points != null) ...[
          const SizedBox(height: 4),
          Text(
            'profile.loyaltyPoints'.trParams({'points': '$points'}),
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
