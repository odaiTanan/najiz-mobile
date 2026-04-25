class TaxiPricingModel {
  final TaxiLocation pickupLocation;
  final TaxiLocation dropoffLocation;
  final List<TaxiPricingCategory> categories;

  const TaxiPricingModel({
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.categories,
  });

  factory TaxiPricingModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    return TaxiPricingModel(
      pickupLocation: TaxiLocation.fromJson(
        data['pickup_location'] is Map<String, dynamic>
            ? data['pickup_location'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      dropoffLocation: TaxiLocation.fromJson(
        data['dropoff_location'] is Map<String, dynamic>
            ? data['dropoff_location'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      categories: _asList(data['categories'])
          .map(TaxiPricingCategory.fromJson)
          .toList(growable: false),
    );
  }
}

class TaxiLocation {
  final double lat;
  final double lng;

  const TaxiLocation({
    required this.lat,
    required this.lng,
  });

  factory TaxiLocation.fromJson(Map<String, dynamic> json) {
    return TaxiLocation(
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
    );
  }
}

class TaxiPricingCategory {
  final TaxiVehicleCategory vehicleCategory;
  final TaxiPricingInfo pricing;

  const TaxiPricingCategory({
    required this.vehicleCategory,
    required this.pricing,
  });

  factory TaxiPricingCategory.fromJson(Map<String, dynamic> json) {
    return TaxiPricingCategory(
      vehicleCategory: TaxiVehicleCategory.fromJson(
        json['vehicle_category'] is Map<String, dynamic>
            ? json['vehicle_category'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
      pricing: TaxiPricingInfo.fromJson(
        json['pricing'] is Map<String, dynamic>
            ? json['pricing'] as Map<String, dynamic>
            : <String, dynamic>{},
      ),
    );
  }
}

class TaxiVehicleCategory {
  final int id;
  final String name;
  final String? icon;
  final double basePrice;
  final double pricePerKm;

  const TaxiVehicleCategory({
    required this.id,
    required this.name,
    this.icon,
    required this.basePrice,
    required this.pricePerKm,
  });

  factory TaxiVehicleCategory.fromJson(Map<String, dynamic> json) {
    return TaxiVehicleCategory(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      icon: json['icon']?.toString(),
      basePrice: _asDouble(json['base_price']),
      pricePerKm: _asDouble(json['price_per_km']),
    );
  }
}

class TaxiPricingInfo {
  final double distanceKm;
  final double estimatedPrice;
  final double adminCommission;

  const TaxiPricingInfo({
    required this.distanceKm,
    required this.estimatedPrice,
    required this.adminCommission,
  });

  factory TaxiPricingInfo.fromJson(Map<String, dynamic> json) {
    return TaxiPricingInfo(
      distanceKm: _asDouble(json['distance_km']),
      estimatedPrice: _asDouble(json['estimated_price']),
      adminCommission: _asDouble(json['admin_commission']),
    );
  }
}

List<Map<String, dynamic>> _asList(dynamic data) {
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
      .toList(growable: false);
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

