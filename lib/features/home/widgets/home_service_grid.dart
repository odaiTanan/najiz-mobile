import 'package:flutter/material.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';
import 'package:najiz_go_express/features/home/widgets/home_service_tile.dart';

/// Horizontally scrollable service tiles for the home screen.
class HomeServiceGrid extends StatelessWidget {
  const HomeServiceGrid({
    super.key,
    required this.services,
    this.selectedServiceId,
    required this.onTap,
  });

  static const double tileWidth = HomeServiceTile.compactWidth;
  static const double tileHeight = HomeServiceTile.compactHeight;
  static const double tileSpacing = HomeServiceTile.compactSpacing;

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
          return HomeServiceTile(
            service: service,
            selected: selectedServiceId == service.id,
            onTap: () => onTap(service),
          );
        },
      ),
    );
  }
}
