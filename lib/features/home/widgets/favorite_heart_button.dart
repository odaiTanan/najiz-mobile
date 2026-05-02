import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/core/services/favorites_controller.dart';

enum FavoriteHeartVariant {
  /// Heart on dark photo overlay (e.g. vendor cover).
  onDarkImage,

  /// Heart on white / light card background.
  onLightCard,
}

/// Heart toggle for favorites — POST /favorites/toggle via [FavoritesController].
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({
    super.key,
    required this.favoriteType,
    required this.entityId,
    this.variant = FavoriteHeartVariant.onDarkImage,
    this.size = 22,
    this.padding = const EdgeInsets.all(4),
  });

  final String favoriteType;
  final int entityId;
  final FavoriteHeartVariant variant;
  final double size;
  final EdgeInsetsGeometry padding;

  bool _active(FavoritesController c) {
    return favoriteType == 'vendor'
        ? c.isVendorFavorite(entityId)
        : c.isProductFavorite(entityId);
  }

  Future<void> _onTap() async {
    await AuthGuardService.runOrRequestLogin(
      message: 'favorites.loginRequired'.tr,
      onAuthenticated: (token) async {
        final c = Get.find<FavoritesController>();
        try {
          if (favoriteType == 'vendor') {
            await c.toggleVendorWithToken(token, entityId);
          } else {
            await c.toggleProductWithToken(token, entityId);
          }
        } catch (_) {
          Get.snackbar('common.error'.tr, 'favorites.toggleFailed'.tr);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<FavoritesController>();
    return Obx(() {
      final active = _active(c);
      final Color iconColor;
      switch (variant) {
        case FavoriteHeartVariant.onDarkImage:
          iconColor = active ? AppColors.primary : Colors.white.withValues(alpha: 0.92);
        case FavoriteHeartVariant.onLightCard:
          iconColor = active ? AppColors.primary : const Color(0xFF94A3B8);
      }
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: padding,
            child: Icon(
              active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: size,
              color: iconColor,
              shadows: variant == FavoriteHeartVariant.onDarkImage
                  ? const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      );
    });
  }
}
