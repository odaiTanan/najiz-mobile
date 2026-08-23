import 'package:get/get.dart';
import 'package:najiz_go_express/features/wassini/repositories/wassini_repository.dart';

void registerWassiniDependencies() {
  if (!Get.isRegistered<WassiniRepository>()) {
    Get.put(WassiniRepository(), permanent: true);
  }
}

WassiniRepository resolveWassiniRepository([WassiniRepository? override]) {
  return override ?? Get.find<WassiniRepository>();
}
