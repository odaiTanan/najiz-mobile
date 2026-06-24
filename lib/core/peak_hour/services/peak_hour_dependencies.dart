import 'package:get/get.dart';
import 'package:najiz_go_express/core/peak_hour/repositories/peak_hour_repository.dart';

void registerPeakHourDependencies() {
  if (!Get.isRegistered<PeakHourRepository>()) {
    Get.put(PeakHourRepository(), permanent: true);
  }
}

PeakHourRepository resolvePeakHourRepository([PeakHourRepository? override]) {
  return override ?? Get.find<PeakHourRepository>();
}
