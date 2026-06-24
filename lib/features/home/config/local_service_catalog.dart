import 'package:flutter/material.dart';
import 'package:najiz_go_express/features/home/models/service_kind.dart';

class LocalServiceDefinition {
  const LocalServiceDefinition({
    required this.id,
    required this.nameKey,
    required this.kind,
    required this.iconData,
    required this.iconColor,
    required this.sortOrder,
    this.iconAsset,
  });

  final int id;
  final String nameKey;
  final ServiceKind kind;
  final IconData iconData;
  final Color iconColor;
  final int sortOrder;

  /// Optional local image. Add PNG under [assets/services/] and register in pubspec.
  final String? iconAsset;
}

/// Local names and visuals for home / all-services tiles.
/// API still provides which service IDs are active; display comes from here.
class LocalServiceCatalog {
  LocalServiceCatalog._();

  static const Map<int, LocalServiceDefinition> byId = {
    5: LocalServiceDefinition(
      id: 5,
      nameKey: 'homeServices.taxi',
      kind: ServiceKind.taxi,
      iconData: Icons.local_taxi_rounded,
      iconColor: Color(0xFFFFB300),
      sortOrder: 0,
      iconAsset: 'assets/services/taxi.png',
    ),
    1: LocalServiceDefinition(
      id: 1,
      nameKey: 'homeServices.restaurant',
      kind: ServiceKind.restaurant,
      iconData: Icons.restaurant_rounded,
      iconColor: Color(0xFFFF6B35),
      sortOrder: 1,
      iconAsset: 'assets/services/restaurant.png',
    ),
    3: LocalServiceDefinition(
      id: 3,
      nameKey: 'homeServices.store',
      kind: ServiceKind.store,
      iconData: Icons.storefront_rounded,
      iconColor: Color(0xFF5C6BC0),
      sortOrder: 2,
      iconAsset: 'assets/services/store.png',
    ),
    2: LocalServiceDefinition(
      id: 2,
      nameKey: 'homeServices.shipping',
      kind: ServiceKind.shipping,
      iconData: Icons.local_shipping_rounded,
      iconColor: Color(0xFF1E88E5),
      sortOrder: 3,
      iconAsset: 'assets/services/shipping.png',
    ),
  };

  static LocalServiceDefinition? find(int id) => byId[id];

  static int sortOrderFor(int id) => byId[id]?.sortOrder ?? (100 + id);
}
