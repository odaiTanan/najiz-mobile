import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/models/service_kind.dart';

class ServiceModel {
  const ServiceModel({
    required this.id,
    this.name = '',
    this.icon,
    this.nameKey,
    this.iconAsset,
    this.iconData,
    this.iconColor,
    this.kind = ServiceKind.unknown,
  });

  final int id;
  final String name;
  final String? icon;
  final String? nameKey;
  final String? iconAsset;
  final IconData? iconData;
  final Color? iconColor;
  final ServiceKind kind;

  String get displayName {
    final key = nameKey;
    if (key != null && key.isNotEmpty) return key.tr;
    if (name.trim().isNotEmpty) return name.trim();
    return 'homeServices.unknown'.tr;
  }

  ServiceModel copyWith({
    int? id,
    String? name,
    String? icon,
    String? nameKey,
    String? iconAsset,
    IconData? iconData,
    Color? iconColor,
    ServiceKind? kind,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      nameKey: nameKey ?? this.nameKey,
      iconAsset: iconAsset ?? this.iconAsset,
      iconData: iconData ?? this.iconData,
      iconColor: iconColor ?? this.iconColor,
      kind: kind ?? this.kind,
    );
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
      nameKey: json['nameKey']?.toString(),
      iconAsset: json['iconAsset']?.toString(),
      kind: _parseKind(json['kind']),
    );
  }
}

ServiceKind _parseKind(dynamic raw) {
  final value = raw?.toString().trim();
  if (value == null || value.isEmpty) return ServiceKind.unknown;
  for (final kind in ServiceKind.values) {
    if (kind.name == value) return kind;
  }
  return ServiceKind.unknown;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
