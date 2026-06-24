import 'package:najiz_go_express/features/orders/models/order_driver_info.dart';

class UserOrderVendor {
  final int id;
  final String name;
  final String? logo;
  final double? lat;
  final double? lng;
  final int? serviceId;

  const UserOrderVendor({
    required this.id,
    required this.name,
    this.logo,
    this.lat,
    this.lng,
    this.serviceId,
  });

  factory UserOrderVendor.fromJson(Map<String, dynamic> json) {
    return UserOrderVendor(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      logo: json['logo']?.toString(),
      lat: _asNullableDouble(json['lat']),
      lng: _asNullableDouble(json['lng']),
      serviceId: _asInt(json['service_id']),
    );
  }
}

class UserOrderItem {
  final int id;
  final int productId;
  final int quantity;
  final double price;
  final double total;
  final String? productName;
  final String? productImage;

  const UserOrderItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.price,
    required this.total,
    this.productName,
    this.productImage,
  });

  factory UserOrderItem.fromJson(Map<String, dynamic> json) {
    final product = _asMap(json['product']);
    return UserOrderItem(
      id: _asInt(json['id']) ?? 0,
      productId: _asInt(json['product_id']) ?? 0,
      quantity: _asInt(json['quantity']) ?? 0,
      price: _asDouble(json['price']),
      total: _asDouble(json['total']),
      productName: product?['name']?.toString(),
      productImage: product?['image']?.toString(),
    );
  }
}

class UserOrderShipping {
  final int id;
  final String? deliveryCode;
  final String? parcelCategory;

  const UserOrderShipping({
    required this.id,
    this.deliveryCode,
    this.parcelCategory,
  });

  factory UserOrderShipping.fromJson(Map<String, dynamic> json) {
    return UserOrderShipping(
      id: _asInt(json['id']) ?? 0,
      deliveryCode: json['delivery_code']?.toString(),
      parcelCategory: json['parcel_category']?.toString(),
    );
  }
}

class UserOrderAddress {
  final int id;
  final String? region;
  final String? street;
  final String? buildingNumber;
  final String? apartmentNumber;

  const UserOrderAddress({
    required this.id,
    this.region,
    this.street,
    this.buildingNumber,
    this.apartmentNumber,
  });

  factory UserOrderAddress.fromJson(Map<String, dynamic> json) {
    return UserOrderAddress(
      id: _asInt(json['id']) ?? 0,
      region: json['region']?.toString(),
      street: json['street']?.toString(),
      buildingNumber: json['building_number']?.toString(),
      apartmentNumber: json['apartment_number']?.toString(),
    );
  }

  String get formatted {
    return [
      region,
      street,
      buildingNumber,
      apartmentNumber,
    ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
  }
}

class UserOrder {
  final int id;
  final String orderNumber;
  final String type;
  final String status;
  final String dispatchStatus;
  final double lat;
  final double lng;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String createdAt;
  final UserOrderVendor? vendor;
  final List<UserOrderItem> items;
  final UserOrderShipping? shippingOrder;
  final OrderDriverInfo? deliveryMan;
  final UserOrderAddress? address;

  const UserOrder({
    required this.id,
    required this.orderNumber,
    required this.type,
    required this.status,
    required this.dispatchStatus,
    required this.lat,
    required this.lng,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.createdAt,
    this.vendor,
    this.items = const [],
    this.shippingOrder,
    this.deliveryMan,
    this.address,
  });

  factory UserOrder.fromJson(Map<String, dynamic> json) {
    final vendorRaw = _asMap(json['vendor']);
    final itemsRaw = json['items'];
    final shippingRaw = _asMap(json['shipping_order'] ?? json['shippingOrder']);
    final deliveryManRaw = _asMap(json['delivery_man'] ?? json['deliveryMan']);
    final addressRaw = _asMap(json['address']);

    return UserOrder(
      id: _asInt(json['id']) ?? 0,
      orderNumber: (json['order_number'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      dispatchStatus: (json['dispatch_status'] ?? '').toString(),
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      subtotal: _asDouble(json['subtotal']),
      deliveryFee: _asDouble(json['delivery_fee']),
      total: _asDouble(json['total']),
      createdAt: (json['created_at'] ?? '').toString(),
      vendor: vendorRaw == null ? null : UserOrderVendor.fromJson(vendorRaw),
      items: itemsRaw is List
          ? itemsRaw
              .whereType<Map>()
              .map((e) => UserOrderItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      shippingOrder:
          shippingRaw == null ? null : UserOrderShipping.fromJson(shippingRaw),
      deliveryMan: deliveryManRaw == null
          ? null
          : OrderDriverInfo.fromPayload(deliveryManRaw),
      address:
          addressRaw == null ? null : UserOrderAddress.fromJson(addressRaw),
    );
  }
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _asNullableDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}
