import 'package:get/get.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/orders/services/order_cancellation_limit_service.dart';

void registerOrdersDependencies() {
  if (!Get.isRegistered<OrdersRepository>()) {
    Get.put(OrdersRepository(), permanent: true);
  }
  if (!Get.isRegistered<OrderCancellationLimitService>()) {
    Get.put(OrderCancellationLimitService(), permanent: true);
  }
}

OrdersRepository resolveOrdersRepository([OrdersRepository? override]) {
  return override ?? Get.find<OrdersRepository>();
}

OrderCancellationLimitService resolveOrderCancellationLimitService(
  [OrderCancellationLimitService? override]
) {
  return override ?? Get.find<OrderCancellationLimitService>();
}
