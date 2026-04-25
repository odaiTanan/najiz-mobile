class CheckoutCartItem {
  final int productId;
  final String name;
  final String? image;
  final String? description;
  final double? unitPrice;
  final int quantity;

  const CheckoutCartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.image,
    this.description,
    this.unitPrice,
  });

  double get lineTotal => (unitPrice ?? 0) * quantity;
}

