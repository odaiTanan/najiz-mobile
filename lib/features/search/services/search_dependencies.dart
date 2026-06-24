import 'package:get/get.dart';
import 'package:najiz_go_express/features/search/repositories/search_repository.dart';

void registerSearchDependencies() {
  if (!Get.isRegistered<SearchRepository>()) {
    Get.put(SearchRepository(), permanent: true);
  }
}

SearchRepository resolveSearchRepository([SearchRepository? override]) {
  return override ?? Get.find<SearchRepository>();
}
