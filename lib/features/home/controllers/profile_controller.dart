import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/home/models/user_profile_model.dart';

class ProfileController extends GetxController {
  ProfileController({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;
  final isLoading = false.obs;
  final isLoggingOut = false.obs;
  final profile = Rxn<UserProfileModel>();

  late final AuthStateManager _authState;

  bool get isGuest => _authState.isGuest;

  @override
  void onInit() {
    super.onInit();
    _authState = Get.find<AuthStateManager>();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final fallback = await SessionService.getUserIdentity();
    if (_authState.isGuest) {
      profile.value = UserProfileModel.fromBackend(null, fallback: fallback);
      return;
    }

    isLoading.value = true;
    try {
      final token = _authState.token.value;
      if (token == null || token.trim().isEmpty) {
        profile.value = UserProfileModel.fromBackend(null, fallback: fallback);
        return;
      }
      final backendProfile = await _authRepository.getCurrentUser(token: token);
      final model = UserProfileModel.fromBackend(
        backendProfile,
        fallback: fallback,
      );
      profile.value = model;
      await SessionService.saveUserIdentity(
        name: model.name,
        phone: model.phone,
        email: model.email,
      );
      if (model.address != null && model.address!.trim().isNotEmpty) {
        await SessionService.saveAddress(model.address!);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveAddress(String address) async {
    await SessionService.saveAddress(address);
    final current = profile.value;
    profile.value = UserProfileModel(
      name: current?.name,
      email: current?.email,
      phone: current?.phone,
      address: address,
    );
  }

  Future<void> logout() async {
    if (isLoggingOut.value) return;
    isLoggingOut.value = true;
    try {
      if (Get.isRegistered<AppCartService>()) {
        Get.find<AppCartService>().clear();
      }
      if (Get.isRegistered<PushNotificationService>()) {
        // Keep notifications list local as history; only unsubscribe device is needed.
      }
      await _authState.markGuest();
      profile.value = UserProfileModel.fromBackend(
        null,
        fallback: await SessionService.getUserIdentity(),
      );
    } finally {
      isLoggingOut.value = false;
    }
  }
}
