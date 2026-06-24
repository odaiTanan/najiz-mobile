import 'package:get/get.dart';
import 'package:najiz_go_express/features/favorites/repositories/favorites_repository.dart';

void registerFavoritesDependencies() {
  if (!Get.isRegistered<FavoritesRepository>()) {
    Get.put(FavoritesRepository(), permanent: true);
  }
}

FavoritesRepository resolveFavoritesRepository([FavoritesRepository? override]) {
  return override ?? Get.find<FavoritesRepository>();
}
