import 'package:flutter/material.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';

class ServiceIconBadge extends StatelessWidget {
  const ServiceIconBadge({
    super.key,
    required this.service,
    this.borderRadius = 10,
    this.iconSize = 26,
    this.fit = BoxFit.contain,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
  });

  final ServiceModel service;
  final double borderRadius;
  final double iconSize;
  final BoxFit fit;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final asset = service.iconAsset;
    if (asset != null && asset.isNotEmpty) {
      final image = Image.asset(
        asset,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
        errorBuilder: (_, __, ___) => _IconFallback(
          service: service,
          borderRadius: borderRadius,
          iconSize: iconSize,
        ),
      );

      Widget child = padding == EdgeInsets.zero
          ? image
          : Padding(padding: padding, child: image);

      if (backgroundColor != null) {
        child = ColoredBox(color: backgroundColor!, child: child);
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: child,
      );
    }

    return _IconFallback(
      service: service,
      borderRadius: borderRadius,
      iconSize: iconSize,
    );
  }
}

class _IconFallback extends StatelessWidget {
  const _IconFallback({
    required this.service,
    required this.borderRadius,
    required this.iconSize,
  });

  final ServiceModel service;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final color = service.iconColor ?? Theme.of(context).colorScheme.primary;
    final icon = service.iconData ?? Icons.apps_rounded;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: color,
        ),
      ),
    );
  }
}
