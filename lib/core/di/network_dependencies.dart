import 'package:get/get.dart';
import 'package:najiz_go_express/data/api/api_client.dart';

void registerNetworkDependencies() {
  if (!Get.isRegistered<ApiClient>()) {
    Get.put(ApiClient.standard(), permanent: true);
  }
}

ApiClient resolveApiClient([ApiClient? override]) {
  return override ?? Get.find<ApiClient>();
}
