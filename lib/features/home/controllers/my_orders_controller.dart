import 'package:get/get.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/user_order.dart';

class MyOrdersController extends GetxController {
  MyOrdersController({required this.token, HomeRepository? repository})
    : _repository = repository ?? HomeRepository();

  final String token;
  final HomeRepository _repository;

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final orders = <UserOrder>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadOrders();
  }

  Future<void> loadOrders() async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      final result = await _repository.getMyOrders(token: token);
      orders.assignAll(result);
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
      orders.clear();
    } catch (_) {
      errorMessage.value = 'تعذر تحميل الطلبات';
      orders.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> cancelOrder(int orderId) async {
    try {
      await _repository.cancelOrder(token: token, orderId: orderId);
      await loadOrders();
    } on HomeApiException {
      rethrow;
    } catch (_) {
      throw HomeApiException('تعذر إلغاء الطلب');
    }
  }
}
