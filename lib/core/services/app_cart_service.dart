import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/models/checkout_cart_item.dart';

class AppCartService extends GetxService {
  final vendorId = RxnInt();
  final items = <CheckoutCartItem>[].obs;
  final totalCount = 0.obs;

  bool get hasItems => items.isNotEmpty;

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

  void _recalculateCount() {
    totalCount.value = items.fold<int>(0, (sum, item) => sum + item.quantity);
  }
}
