import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';
import 'package:najiz_go_express/features/home/widgets/service_icon_badge.dart';

enum HomeServiceTileLayout { compact, grid }

/// Shared service tile for [HomeServiceGrid] and [AllServicesScreen].
class HomeServiceTile extends StatelessWidget {
  const HomeServiceTile({
    super.key,
    required this.service,
    required this.onTap,
    this.selected = false,
    this.layout = HomeServiceTileLayout.compact,
  });

  static const double compactWidth = 96;
  static const double compactHeight = 120;
  static const double compactSpacing = 10;
  static const double compactImageHeight = 72;
  static const double gridImageHeight = 108;

  final ServiceModel service;
  final VoidCallback onTap;
  final bool selected;
  final HomeServiceTileLayout layout;

  @override
  Widget build(BuildContext context) {
    return switch (layout) {
      HomeServiceTileLayout.compact => _CompactServiceTile(
          service: service,
          selected: selected,
          onTap: onTap,
        ),
      HomeServiceTileLayout.grid => _GridServiceTile(
          service: service,
          onTap: onTap,
        ),
    };
  }
}

class _CompactServiceTile extends StatelessWidget {
  const _CompactServiceTile({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final ServiceModel service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      width: HomeServiceTile.compactWidth,
      height: HomeServiceTile.compactHeight,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: AppColors.primary, width: 1.6)
                : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A111827),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: HomeServiceTile.compactImageHeight,
                child: ServiceIconBadge(
                  service: service,
                  borderRadius: 12,
                  iconSize: 28,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    service.displayName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.2,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridServiceTile extends StatelessWidget {
  const _GridServiceTile({
    required this.service,
    required this.onTap,
  });

  final ServiceModel service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: HomeServiceTile.gridImageHeight,
            child: ServiceIconBadge(
              service: service,
              borderRadius: 12,
              iconSize: 40,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.displayName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
