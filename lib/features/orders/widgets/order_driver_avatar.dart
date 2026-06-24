import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/network_image_with_fallback.dart';

class OrderDriverAvatar extends StatelessWidget {
  const OrderDriverAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 22,
  });

  final String? avatarUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = radius * 2;

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: avatarUrl == null || avatarUrl!.isEmpty
            ? ColoredBox(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.person, color: cs.onSurfaceVariant, size: radius),
              )
            : NetworkImageWithFallback(
                url: avatarUrl,
                fit: BoxFit.cover,
              ),
      ),
    );
  }
}
