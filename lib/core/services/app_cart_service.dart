import 'dart:convert';

import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/models/checkout_cart_item.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppCartService extends GetxService {
  final vendorId = RxnInt();
  final items = <CheckoutCartItem>[].obs;
  final totalCount = 0.obs;

  bool get hasItems => items.isNotEmpty;

  static const String _savedCartPayloadKey = 'saved_cart_payload_v1';
  static const String _hasSavedCartKey = 'has_saved_cart_v1';

  void setCart({required int vendorId, required List<CheckoutCartItem> items}) {
    this.vendorId.value = vendorId;
    this.items.assignAll(items);
    _recalculateCount();
  }

  void clear() {
    vendorId.value = null;
    items.clear();
    _recalculateCount();
  }

  Future<void> persistCurrentCart() async {
    final vId = vendorId.value;
    if (vId == null || items.isEmpty) return;

    final payload = <String, dynamic>{
      'vendorId': vId,
      'items': items.map(_itemToJson).toList(growable: false),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_savedCartPayloadKey, jsonEncode(payload));
    await prefs.setBool(_hasSavedCartKey, true);
  }

  /// Restores the saved cart into memory if present.
  /// Returns true if a saved cart was restored.
  Future<bool> restoreSavedCartIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSaved = prefs.getBool(_hasSavedCartKey) ?? false;
    if (!hasSaved) return false;

    final raw = prefs.getString(_savedCartPayloadKey);
    if (raw == null || raw.trim().isEmpty) return false;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final vId = (decoded['vendorId'] as num?)?.toInt();
    final itemsRaw = decoded['items'];
    if (vId == null || itemsRaw is! List) return false;

    final restoredItems = itemsRaw
        .whereType<Map>()
        .map((e) => _itemFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);

    if (restoredItems.isEmpty) return false;

    setCart(vendorId: vId, items: restoredItems);
    return true;
  }

  /// Consume the saved-cart flag/snapshot (cart remains in memory).
  Future<void> consumeSavedCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSavedCartKey, false);
    await prefs.remove(_savedCartPayloadKey);
  }

  /// Clears saved cart snapshot and flag, and also clears the in-memory cart.
  Future<void> clearSavedCart() async {
    await consumeSavedCart();
    clear();
  }

  void _recalculateCount() {
    totalCount.value = items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Map<String, dynamic> _itemToJson(CheckoutCartItem item) {
    return <String, dynamic>{
      'productId': item.productId,
      'name': item.name,
      'image': item.image,
      'description': item.description,
      'unitPrice': item.unitPrice,
      'quantity': item.quantity,
      'note': item.note,
      'extras': item.extras.map(_extraToJson).toList(growable: false),
    };
  }

  CheckoutCartItem _itemFromJson(Map<String, dynamic> json) {
    final extrasRaw = json['extras'];
    final extras = extrasRaw is List
        ? extrasRaw
            .whereType<Map>()
            .map((e) => _extraFromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <CheckoutCartExtraItem>[];

    final unitPrice = _asDouble(json['unitPrice']);

    return CheckoutCartItem(
      productId: (json['productId'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      image: json['image']?.toString(),
      description: json['description']?.toString(),
      unitPrice: unitPrice,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      extras: extras,
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> _extraToJson(CheckoutCartExtraItem item) {
    return <String, dynamic>{
      'extraId': item.extraId,
      'name': item.name,
      'price': item.price,
      'quantity': item.quantity,
    };
  }

  CheckoutCartExtraItem _extraFromJson(Map<String, dynamic> json) {
    return CheckoutCartExtraItem(
      extraId: (json['extraId'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      price: _asDouble(json['price']) ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed;
  }
}
