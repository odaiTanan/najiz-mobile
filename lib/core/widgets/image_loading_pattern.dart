import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_images.dart';

/// Branded placeholder for loading, missing, or broken vendor/product images.
class ImageLoadingPattern extends StatelessWidget {
  const ImageLoadingPattern({
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.backgroundColor = Colors.white,
  });

  final BoxFit fit;
  final Alignment alignment;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: Image.asset(
        AppImages.imageLoadingPattern,
        fit: fit,
        alignment: alignment,
        width: double.infinity,
        height: double.infinity,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }
}
