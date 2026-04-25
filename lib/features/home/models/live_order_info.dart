class LiveOrderInfo {
  final int orderId;
  final String orderNumber;
  final String status;
  final String dispatchStatus;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;

  const LiveOrderInfo({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.dispatchStatus,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
  });
}
