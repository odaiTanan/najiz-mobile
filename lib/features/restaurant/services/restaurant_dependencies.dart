import 'package:get/get.dart';
import 'package:najiz_go_express/features/restaurant/repositories/restaurant_repository.dart';

void registerRestaurantDependencies() {
  if (!Get.isRegistered<RestaurantRepository>()) {
    Get.put(RestaurantRepository(), permanent: true);
  }
}

RestaurantRepository resolveRestaurantRepository([RestaurantRepository? override]) {
  return override ?? Get.find<RestaurantRepository>();
}
