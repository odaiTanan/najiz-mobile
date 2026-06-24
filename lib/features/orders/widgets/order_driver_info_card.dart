import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/features/orders/models/order_driver_info.dart';
import 'package:najiz_go_express/features/orders/widgets/order_driver_avatar.dart';

class OrderDriverInfoCard extends StatelessWidget {
  const OrderDriverInfoCard({
    super.key,
    required this.driver,
    this.token,
    this.showSupportAction = true,
  });

  final OrderDriverInfo? driver;
  final String? token;
  final bool showSupportAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = driver;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tracking.driverInfo'.tr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (info == null || !info.hasDisplayableData)
            Text(
              'tracking.driverDataUpdating'.tr,
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OrderDriverAvatar(avatarUrl: info.avatarUrl, radius: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.name ?? 'tracking.notAvailable'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          fontSize: 15,
                        ),
                      ),
                      if ((info.phone ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          info.phone!,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if ((info.rating ?? '').isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: cs.tertiaryContainer.withValues(alpha: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, size: 15, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          info.rating!,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _driverRow(
              cs,
              'tracking.vehicleTypeLabel'.tr,
              info.vehicleType ?? 'tracking.notAvailable'.tr,
            ),
            _driverRow(
              cs,
              'tracking.plateNumberLabel'.tr,
              info.plate ?? 'tracking.notAvailable'.tr,
            ),
          ],
          if (showSupportAction && (token ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => AppRoutes.openSupportChat(token: token!.trim()),
                icon: const Icon(Icons.support_agent),
                label: Text('tracking.contactSupport'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _driverRow(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderDriverSummaryTile extends StatelessWidget {
  const OrderDriverSummaryTile({
    super.key,
    required this.driver,
    this.avatarRadius = 22,
    this.nameStyle,
    this.subtitleStyle,
    this.showRating = true,
  });

  final OrderDriverInfo? driver;
  final double avatarRadius;
  final TextStyle? nameStyle;
  final TextStyle? subtitleStyle;
  final bool showRating;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final info = driver;
    final name = info?.name ?? 'tracking.driverLabel'.tr;
    final vehicle = info?.vehicleType ?? 'tracking.vehicleUnknown'.tr;
    final plate = info?.plate ?? '---';
    final rating = info?.rating ?? '--';

    return Row(
      children: [
        OrderDriverAvatar(avatarUrl: info?.avatarUrl, radius: avatarRadius),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: nameStyle ??
                    TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                      fontSize: 12,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                '$vehicle - $plate',
                style: subtitleStyle ??
                    TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
              ),
              if ((info?.phone ?? '').isNotEmpty)
                Text(
                  info!.phone!,
                  style: subtitleStyle ??
                      TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                ),
            ],
          ),
        ),
        if (showRating)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFF59E0B), size: 16),
                const SizedBox(width: 4),
                Text(
                  rating,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
