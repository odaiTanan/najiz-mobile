import 'package:get/get.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';

void registerAuthDependencies() {
  if (!Get.isRegistered<AuthRepository>()) {
    Get.put(AuthRepository(), permanent: true);
  }
}

AuthRepository resolveAuthRepository([AuthRepository? override]) {
  return override ?? Get.find<AuthRepository>();
}
