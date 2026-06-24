import 'dart:convert';

import 'package:najiz_go_express/features/home/models/offer_model.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeBootstrapSnapshot {
  const HomeBootstrapSnapshot({
    required this.offers,
    required this.services,
    this.vendors = const [],
    this.vendorServiceId,
  });

  final List<OfferModel> offers;
  final List<ServiceModel> services;
  final List<VendorModel> vendors;
  final int? vendorServiceId;
}

/// Persists the last successful home bootstrap for instant cold-start paint.
class HomeBootstrapCache {
  HomeBootstrapCache._();

  static const _offersKey = 'home_bootstrap_offers_v1';
  static const _servicesKey = 'home_bootstrap_services_v1';
  static const _vendorsKey = 'home_bootstrap_vendors_v1';
  static const _vendorServiceIdKey = 'home_bootstrap_vendor_service_id_v1';
  static const _savedAtKey = 'home_bootstrap_saved_at_v1';
  static const Duration ttl = Duration(hours: 12);

  static HomeBootstrapSnapshot? _memory;

  static HomeBootstrapSnapshot? get memory => _memory;

  /// Loads disk cache into memory before first frame (call from [main]).
  static Future<void> warmMemory() async {
    if (_memory != null) return;
    await load();
  }

  static void applyToMemory(HomeBootstrapSnapshot snapshot) {
    _memory = snapshot;
  }

  static Future<HomeBootstrapSnapshot?> load() async {
    if (_memory != null) return _memory;

    final prefs = await SharedPreferences.getInstance();
    final savedAtMs = prefs.getInt(_savedAtKey);
    if (savedAtMs == null) return null;

    final savedAt = DateTime.fromMillisecondsSinceEpoch(savedAtMs);
    if (DateTime.now().difference(savedAt) > ttl) return null;

    final offersRaw = prefs.getString(_offersKey);
    final servicesRaw = prefs.getString(_servicesKey);
    if (offersRaw == null || servicesRaw == null) return null;

    try {
      final offers = _decodeList(offersRaw)
          .map(OfferModel.fromJson)
          .toList(growable: false);
      final services = _decodeList(servicesRaw)
          .map(ServiceModel.fromJson)
          .toList(growable: false);

      final vendorsRaw = prefs.getString(_vendorsKey);
      final vendors = vendorsRaw == null
          ? const <VendorModel>[]
          : _decodeList(vendorsRaw)
              .map(VendorModel.fromJson)
              .toList(growable: false);

      final snapshot = HomeBootstrapSnapshot(
        offers: offers,
        services: services,
        vendors: vendors,
        vendorServiceId: prefs.getInt(_vendorServiceIdKey),
      );
      _memory = snapshot;
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save({
    required List<OfferModel> offers,
    required List<ServiceModel> services,
    List<VendorModel> vendors = const [],
    int? vendorServiceId,
  }) async {
    final snapshot = HomeBootstrapSnapshot(
      offers: offers,
      services: services,
      vendors: vendors,
      vendorServiceId: vendorServiceId,
    );
    _memory = snapshot;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _offersKey,
      jsonEncode(offers.map(_offerToJson).toList(growable: false)),
    );
    await prefs.setString(
      _servicesKey,
      jsonEncode(services.map(_serviceToJson).toList(growable: false)),
    );
    await prefs.setString(
      _vendorsKey,
      jsonEncode(vendors.map(_vendorToJson).toList(growable: false)),
    );
    if (vendorServiceId != null) {
      await prefs.setInt(_vendorServiceIdKey, vendorServiceId);
    } else {
      await prefs.remove(_vendorServiceIdKey);
    }
    await prefs.setInt(_savedAtKey, DateTime.now().millisecondsSinceEpoch);
  }

  static List<Map<String, dynamic>> _decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  static Map<String, dynamic> _offerToJson(OfferModel offer) => {
        'id': offer.id,
        'vendor_id': offer.vendorId,
        'service_id': offer.serviceId,
        'service': offer.service,
        'name': offer.name,
        'image': offer.image,
        'is_active': offer.isActive ? 1 : 0,
      };

  static Map<String, dynamic> _serviceToJson(ServiceModel service) => {
        'id': service.id,
        'name': service.name,
        'icon': service.icon,
        'nameKey': service.nameKey,
        'iconAsset': service.iconAsset,
        'kind': service.kind.name,
      };

  static Map<String, dynamic> _vendorToJson(VendorModel vendor) => {
        'id': vendor.id,
        'service_id': vendor.serviceId,
        'classification_id': vendor.classificationId,
        'name': vendor.name,
        'image': vendor.image,
        'logo': vendor.logo,
        'description': vendor.description,
        'is_opened': vendor.isOpened ? 1 : 0,
        'is_active': vendor.isActive ? 1 : 0,
        'rating': vendor.rating,
        'vendor_status': vendor.vendorStatus,
      };
}
