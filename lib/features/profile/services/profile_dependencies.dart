import 'package:get/get.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';

void registerProfileDependencies() {
  if (!Get.isRegistered<ProfileRepository>()) {
    Get.put(ProfileRepository(), permanent: true);
  }
}

ProfileRepository resolveProfileRepository([ProfileRepository? override]) {
  return override ?? Get.find<ProfileRepository>();
}
