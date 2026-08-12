import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/core/widgets/network_image_with_fallback.dart';
import 'package:najiz_go_express/features/orders/widgets/vendor_order_status.dart';

class HomeRestaurantCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double? rating;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? vendorId;
  final String? vendorStatus;
  final bool isOpened;
  final bool isStore;
  final String? etaMinutesText;

  const HomeRestaurantCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.rating,
    this.subtitle,
    this.onTap,
    this.vendorId,
    this.vendorStatus,
    required this.isOpened,
    required this.isStore,
    this.etaMinutesText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: SizedBox(
                  height: 76,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: isOpened
                            ? NetworkImageWithFallback(
                                url: imageUrl,
                                fit: BoxFit.cover,
                                cacheWidth: 280,
                                cacheHeight: 160,
                              )
                            : ColorFiltered(
                                colorFilter: const ColorFilter.matrix(<double>[
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0.2126, 0.7152, 0.0722, 0, 0,
                                  0, 0, 0, 1, 0,
                                ]),
                                child: NetworkImageWithFallback(
                                  url: imageUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 280,
                                  cacheHeight: 160,
                                ),
                              ),
                      ),
                      if (vendorId != null)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: FavoriteHeartButton(
                            favoriteType: 'vendor',
                            entityId: vendorId!,
                            variant: FavoriteHeartVariant.onDarkImage,
                            size: 20,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      Positioned(
                        left: 8,
                        bottom: 7,
                        child: _EtaBadge(etaMinutesText: etaMinutesText),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 7, 8, 2),
                child: Text(
                  name,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                child: Text(
                  (subtitle == null || subtitle!.trim().isEmpty)
                      ? 'services.restaurantLabel'.tr
                      : subtitle!.trim(),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
              if (!isOpened || VendorOrderStatus.normalized(vendorStatus) != null)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 0),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: VendorOrderStatus.statusDotColor(
                            vendorStatus,
                            isOpened: isOpened,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          VendorOrderStatus.shortLabel(
                            vendorStatus,
                            isOpened: isOpened,
                            isStore: isStore,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 8, 8),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      rating?.toStringAsFixed(1) ?? '0.0',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: cs.onSurface,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EtaBadge extends StatelessWidget {
  const _EtaBadge({required this.etaMinutesText});

  final String? etaMinutesText;

  @override
  Widget build(BuildContext context) {
    if (etaMinutesText == null || etaMinutesText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${etaMinutesText!.trim()} د',
        style: TextStyle(
          fontSize: 9.5,
          color: cs.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
