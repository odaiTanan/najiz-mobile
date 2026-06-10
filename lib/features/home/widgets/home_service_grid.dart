import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/data/models/service_model.dart';

/// Horizontally scrollable service tiles for the home screen (icon + title).
class HomeServiceGrid extends StatelessWidget {
  const HomeServiceGrid({
    super.key,
    required this.services,
    this.selectedServiceId,
    required this.onTap,
  });

  static const double tileWidth = 82;
  static const double tileHeight = 100;
  static const double tileSpacing = 10;

  final List<ServiceModel> services;
  final int? selectedServiceId;
  final void Function(ServiceModel) onTap;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: tileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: tileSpacing),
        itemBuilder: (_, index) {
          final service = services[index];
          final isSelected = selectedServiceId == service.id;
          return _HomeServiceTile(
            service: service,
            isSelected: isSelected,
            onTap: () => onTap(service),
          );
        },
      ),
    );
  }
}

class _HomeServiceTile extends StatelessWidget {
  const _HomeServiceTile({
    required this.service,
    required this.isSelected,
    required this.onTap,
  });

  final ServiceModel service;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final iconUrl = service.icon?.trim() ?? '';

    return SizedBox(
      width: HomeServiceGrid.tileWidth,
      height: HomeServiceGrid.tileHeight,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : cs.outlineVariant,
              width: isSelected ? 1.6 : 1.1,
            ),
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
                width: 44,
                height: 44,
                child: iconUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          iconUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.widgets_outlined,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.widgets_outlined,
                        color: cs.onSurfaceVariant,
                      ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    service.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
