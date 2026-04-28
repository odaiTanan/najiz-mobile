class CheckoutCartItem {
  final int productId;
  final String name;
  final String? image;
  final String? description;
  final double? unitPrice;
  final int quantity;
  final List<CheckoutCartExtraItem> extras;
  final String? note;

  const CheckoutCartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.image,
    this.description,
    this.unitPrice,
    this.extras = const [],
    this.note,
  });

  double get extrasTotal =>
      extras.fold<double>(0, (sum, item) => sum + item.lineTotal);

  double get lineTotal => ((unitPrice ?? 0) * quantity) + extrasTotal;
}

class CheckoutCartExtraItem {
  final int extraId;
  final String name;
  final double price;
  final int quantity;

  const CheckoutCartExtraItem({
    required this.extraId,
    required this.name,
    required this.price,
    this.quantity = 1,
  });

  double get lineTotal => price * quantity;
}

