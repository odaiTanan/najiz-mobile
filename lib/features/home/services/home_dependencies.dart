import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/services/offer_navigation_coordinator.dart';
import 'package:najiz_go_express/features/home/services/service_catalog_service.dart';

void registerHomeDependencies() {
  if (!Get.isRegistered<ServiceCatalogService>()) {
    Get.put(const ServiceCatalogService(), permanent: true);
  }
  if (!Get.isRegistered<HomeRepository>()) {
    Get.put(HomeRepository(), permanent: true);
  }
  if (!Get.isRegistered<OfferNavigationCoordinator>()) {
    Get.put(OfferNavigationCoordinator(), permanent: true);
  }
}

ServiceCatalogService resolveServiceCatalogService([
  ServiceCatalogService? override,
]) {
  return override ?? Get.find<ServiceCatalogService>();
}

HomeRepository resolveHomeRepository([HomeRepository? override]) {
  return override ?? Get.find<HomeRepository>();
}

OfferNavigationCoordinator resolveOfferNavigationCoordinator([
  OfferNavigationCoordinator? override,
]) {
  return override ?? Get.find<OfferNavigationCoordinator>();
}
