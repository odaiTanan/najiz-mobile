import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

class HomeSectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;

  const HomeSectionTitle({
    super.key,
    required this.title,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (actionText != null)
          Flexible(
            child: Text(
              actionText!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          )
        else
          const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
      ],
    );
  }
}
