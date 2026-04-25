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
  });

  factory UserOrder.fromJson(Map<String, dynamic> json) {
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
