import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/data/models/service_model.dart';

/// Service tiles matching the home screen grid (icon + title, white card).
class HomeServiceGrid extends StatelessWidget {
  const HomeServiceGrid({
    super.key,
    required this.services,
    this.selectedServiceId,
    required this.onTap,
    this.crossAxisCount = 4,
    this.shrinkWrap = true,
    this.physics = const NeverScrollableScrollPhysics(),
    this.padding = EdgeInsets.zero,
  });

  final List<ServiceModel> services;
  final int? selectedServiceId;
  final void Function(ServiceModel) onTap;
  final int crossAxisCount;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemCount: services.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.86,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, index) {
        final service = services[index];
        final cs = Theme.of(context).colorScheme;
        final iconUrl = service.icon?.trim() ?? '';
        final isSelected = selectedServiceId == service.id;
        return InkWell(
          onTap: () => onTap(service),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 48,
                  height: 48,
                  child: (iconUrl.isNotEmpty)
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    service.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
