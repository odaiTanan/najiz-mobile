import 'package:get/get.dart';
import 'package:najiz_go_express/features/shipping/repositories/shipping_repository.dart';

void registerShippingDependencies() {
  if (!Get.isRegistered<ShippingRepository>()) {
    Get.put(ShippingRepository(), permanent: true);
  }
}

ShippingRepository resolveShippingRepository([ShippingRepository? override]) {
  return override ?? Get.find<ShippingRepository>();
}
