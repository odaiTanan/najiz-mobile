import 'package:get/get.dart';
import 'package:najiz_go_express/features/taxi/repositories/taxi_repository.dart';

void registerTaxiDependencies() {
  if (!Get.isRegistered<TaxiRepository>()) {
    Get.put(TaxiRepository(), permanent: true);
  }
}

TaxiRepository resolveTaxiRepository([TaxiRepository? override]) {
  return override ?? Get.find<TaxiRepository>();
}
