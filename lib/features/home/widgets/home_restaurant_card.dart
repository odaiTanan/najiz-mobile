import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

class HomeRestaurantCard extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double? rating;
  final String? subtitle;
  final VoidCallback? onTap;
  final int? vendorId;

  const HomeRestaurantCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.rating,
    this.subtitle,
    this.onTap,
    this.vendorId,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF0F2F5)),
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
                        child: NetworkImageWithFallback(
                          url: imageUrl,
                          fit: BoxFit.cover,
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
                      const Positioned(
                        left: 8,
                        bottom: 7,
                        child: _EtaBadge(),
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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                child: Text(
                  (subtitle == null || subtitle!.trim().isEmpty)
                      ? 'مطعم'
                      : subtitle!.trim(),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8B95A7),
                    fontSize: 11,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 5, 8, 8),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Text(
                      'توصيل مجاني',
                      style: TextStyle(
                        color: Color(0xFF7EB17B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      rating?.toStringAsFixed(1) ?? '0.0',
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.star_rounded,
                      size: 12,
                      color: Color(0xFF111827),
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
  const _EtaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        '25-35',
        style: TextStyle(
          fontSize: 9.5,
          color: Color(0xFF111827),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
