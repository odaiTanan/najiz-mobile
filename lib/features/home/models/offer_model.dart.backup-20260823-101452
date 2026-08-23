import 'package:najiz_go_express/features/home/config/local_service_catalog.dart';
import 'package:najiz_go_express/features/home/models/service_kind.dart';

class OfferModel {
  final int id;
  final int? vendorId;
  final int? serviceId;
  final String? service;
  final String name;
  final String? image;
  final bool isActive;
  final OfferVendorModel? vendor;

  const OfferModel({
    required this.id,
    required this.name,
    this.vendorId,
    this.serviceId,
    this.service,
    this.image,
    this.isActive = false,
    this.vendor,
  });

  /// Single source of truth for CTA and navigation.
  /// Priority: offer.serviceId → vendor.serviceId → service/service_type/type → unknown.
  ServiceKind get serviceKind {
    final fromOfferId = _kindFromServiceId(serviceId);
    if (fromOfferId != ServiceKind.unknown) return fromOfferId;

    final fromVendorId = _kindFromServiceId(vendor?.serviceId);
    if (fromVendorId != ServiceKind.unknown) return fromVendorId;

    return _kindFromServiceLabel(service);
  }

  /// Localization key for the offer CTA button.
  String get ctaLocalizationKey {
    switch (serviceKind) {
      case ServiceKind.restaurant:
        return 'offers.orderNow';
      case ServiceKind.store:
        return 'offers.shopNow';
      case ServiceKind.taxi:
        return 'offers.bookNow';
      case ServiceKind.shipping:
        return 'offers.orderShipping';
      case ServiceKind.supermarket:
      case ServiceKind.unknown:
        return 'offers.viewDetails';
    }
  }

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    final vendorRaw = json['vendor'];
    OfferVendorModel? vendor;
    if (vendorRaw is Map<String, dynamic>) {
      vendor = OfferVendorModel.fromJson(vendorRaw);
    } else if (vendorRaw is Map) {
      vendor = OfferVendorModel.fromJson(
        vendorRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
    }

    return OfferModel(
      id: _asInt(json['id']),
      vendorId: _asNullableInt(json['vendor_id']),
      serviceId: _asNullableInt(json['service_id']),
      service: _firstNonEmpty([
        json['service'],
        json['service_type'],
        json['type'],
      ]),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      isActive: _asBool(json['is_active']),
      vendor: vendor,
    );
  }

  static ServiceKind _kindFromServiceId(int? id) {
    if (id == null || id <= 0) return ServiceKind.unknown;
    return LocalServiceCatalog.find(id)?.kind ?? ServiceKind.unknown;
  }

  static ServiceKind _kindFromServiceLabel(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return ServiceKind.unknown;

    switch (normalized) {
      case 'restaurant':
      case 'restaurants':
        return ServiceKind.restaurant;
      case 'store':
      case 'stores':
      case 'shop':
      case 'shops':
      case 'market':
        return ServiceKind.store;
      case 'taxi':
        return ServiceKind.taxi;
      case 'shipping':
      case 'shipment':
        return ServiceKind.shipping;
    }

    if (normalized.contains('restaurant') || normalized.contains('مطعم')) {
      return ServiceKind.restaurant;
    }
    if (normalized.contains('store') ||
        normalized.contains('shop') ||
        normalized.contains('market') ||
        normalized.contains('متجر')) {
      return ServiceKind.store;
    }
    if (normalized.contains('taxi') || normalized.contains('تاكسي')) {
      return ServiceKind.taxi;
    }
    if (normalized.contains('ship') || normalized.contains('شحن')) {
      return ServiceKind.shipping;
    }

    return ServiceKind.unknown;
  }
}

class OfferVendorModel {
  final int id;
  final int? serviceId;
  final String name;
  final String? image;
  final String? logo;
  final String? description;
  final double? rating;

  const OfferVendorModel({
    required this.id,
    this.serviceId,
    required this.name,
    this.image,
    this.logo,
    this.description,
    this.rating,
  });

  factory OfferVendorModel.fromJson(Map<String, dynamic> json) {
    return OfferVendorModel(
      id: _asInt(json['id']),
      serviceId: _asNullableInt(json['service_id']),
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      logo: json['logo']?.toString(),
      description: json['description']?.toString(),
      rating: _asNullableDouble(json['rating']),
    );
  }
}

String? _firstNonEmpty(List<dynamic> values) {
  for (final raw in values) {
    final value = raw?.toString().trim();
    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }
  return null;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value == 1;
  final normalized = value?.toString().toLowerCase();
  return normalized == '1' || normalized == 'true';
}
