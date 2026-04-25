import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

class NetworkImageWithFallback extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final Map<String, String>? headers;

  const NetworkImageWithFallback({
    super.key,
    required this.url,
    required this.fit,
    this.headers,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: const Color(0xFFDEE3EA),
        child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
      );
    }

    return Image.network(
      url!,
      fit: fit,
      headers: headers,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFDEE3EA),
        child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
      ),
    );
  }
}
