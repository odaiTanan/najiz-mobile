import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/orders/errors/orders_api_exception.dart';
import 'package:najiz_go_express/features/orders/models/user_order.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/orders/services/orders_dependencies.dart';

class MyOrdersController extends GetxController {
  MyOrdersController({OrdersRepository? repository})
    : _repository = repository ?? resolveOrdersRepository();

  final OrdersRepository _repository;
  late final AuthStateManager _auth;

  final isLoading = true.obs;
  final isLoadingMore = false.obs;
  final errorMessage = RxnString();
  final orders = <UserOrder>[].obs;
  final currentPage = 1.obs;
  final lastPage = 1.obs;

  String? get token => _auth.token.value;

  @override
  void onInit() {
    super.onInit();
    _auth = Get.find<AuthStateManager>();
    if (orders.isEmpty) {
      loadOrders();
    }
  }

  Future<void> loadOrders() => load(reset: true);

  Future<void> loadMoreIfNeeded() => load(reset: false);

  Future<void> load({required bool reset}) async {
    final authToken = token;
    if (authToken == null || authToken.trim().isEmpty) {
      isLoading.value = false;
      orders.clear();
      return;
    }

    if (reset) {
      isLoading.value = true;
      errorMessage.value = null;
      orders.clear();
      currentPage.value = 1;
      lastPage.value = 1;
    } else {
      if (isLoadingMore.value || currentPage.value >= lastPage.value) return;
      isLoadingMore.value = true;
    }

    final page = reset ? 1 : currentPage.value + 1;

    try {
      final result = await _repository.getMyOrdersPage(
        token: authToken,
        page: page,
      );
      if (reset) {
        orders.assignAll(result.items);
      } else {
        orders.addAll(result.items);
      }
      currentPage.value = result.currentPage;
      lastPage.value = result.lastPage;
      errorMessage.value = null;
    } on OrdersApiException catch (e) {
      if (reset) {
        errorMessage.value = e.message;
        orders.clear();
      }
    } catch (_) {
      if (reset) {
        errorMessage.value = 'orders.loadFailed'.tr;
        orders.clear();
      }
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> cancelOrder(int orderId, {String? cancellationReason}) async {
    final authToken = token;
    if (authToken == null || authToken.trim().isEmpty) {
      throw OrdersApiException('guard.loginRequired'.tr);
    }
    try {
      await _repository.cancelOrder(
        token: authToken,
        orderId: orderId,
        cancellationReason: cancellationReason,
      );
      await loadOrders();
    } on OrdersApiException {
      rethrow;
    } catch (_) {
      throw OrdersApiException('orders.cancelFailed'.tr);
    }
  }
}
