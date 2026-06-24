import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/utils/delivery_eta_helper.dart';

class EstimatedDeliveryEtaCard extends StatelessWidget {
  const EstimatedDeliveryEtaCard({
    super.key,
    required this.eta,
    this.compact = false,
  });

  final DeliveryEta? eta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final minutes = eta?.minutes;
    final distanceKm = eta?.distanceKm;
    final deliveryTime = eta?.deliveryTime;

    if (minutes == null && distanceKm == null && deliveryTime == null) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              minutes != null
                  ? 'tracking.etaMinutes'.trParams({'minutes': minutes.toString()})
                  : deliveryTime ?? '--',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            if (distanceKm != null) ...[
              const SizedBox(height: 2),
              Text(
                'tracking.etaDistanceKm'.trParams({
                  'distance': distanceKm.toStringAsFixed(1),
                }),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'tracking.estimatedDeliveryTime'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                if (minutes != null)
                  Text(
                    'tracking.etaMinutes'.trParams({'minutes': minutes.toString()}),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                if (deliveryTime != null)
                  Text(
                    'tracking.estimatedDeliveryAt'.trParams({'time': deliveryTime}),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                if (distanceKm != null)
                  Text(
                    'tracking.etaDistanceKm'.trParams({
                      'distance': distanceKm.toStringAsFixed(1),
                    }),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
