import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/create_address_payload.dart';
import 'package:najiz_go_express/features/home/models/referral_coupon_models.dart';
import 'package:najiz_go_express/features/home/models/user_profile_model.dart';

class ProfileController extends GetxController {
  ProfileController({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      _homeRepository = HomeRepository();

  final AuthRepository _authRepository;
  final HomeRepository _homeRepository;
  final isLoading = false.obs;
  final isLoggingOut = false.obs;
  final isDeletingAccount = false.obs;
  final profile = Rxn<UserProfileModel>();
  final referralInfo = Rxn<ReferralCodeInfo>();
  final isUpdatingAvatar = false.obs;

  late final AuthStateManager _authState;
  final ImagePicker _imagePicker = ImagePicker();

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
      referralInfo.value = null;
      return;
    }

    isLoading.value = true;
    referralInfo.value = null;
    try {
      final token = _authState.token.value;
      if (token == null || token.trim().isEmpty) {
        profile.value = UserProfileModel.fromBackend(null, fallback: fallback);
        referralInfo.value = null;
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
      await SessionService.saveAvatarPath(model.avatarPath);
      if (model.address != null && model.address!.trim().isNotEmpty) {
        await SessionService.saveAddress(model.address!);
      }
      try {
        referralInfo.value = await _homeRepository.getMyReferralCode(
          token: token,
        );
      } catch (_) {
        referralInfo.value = const ReferralCodeInfo(referralCode: '');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveAddress(CreateAddressPayload payload) async {
    final token = _authState.token.value;
    if (token == null || token.trim().isEmpty) {
      throw HomeApiException('checkout.loginForAddress'.tr);
    }

    await _homeRepository.addUserAddress(token: token, payload: payload.toJson());
    final address = payload.toDisplayText();
    await SessionService.saveAddress(address);
    final current = profile.value;
    profile.value = UserProfileModel(
      name: current?.name,
      email: current?.email,
      phone: current?.phone,
      address: address,
      avatarPath: current?.avatarPath,
    );
  }

  Future<void> pickProfileImageFromGallery() async {
    if (isUpdatingAvatar.value) return;
    try {
      isUpdatingAvatar.value = true;
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1400,
      );
      if (picked == null) return;
      await _saveAvatarPath(picked.path);
      AppSnackbar.show('common.done'.tr, 'profile.photoUpdated'.tr);
    } catch (_) {
      AppSnackbar.show('profile.photoUpdateFailed'.tr, 'profile.photoAccessDenied'.tr);
    } finally {
      isUpdatingAvatar.value = false;
    }
  }

  Future<void> clearProfileImage() async {
    if (isUpdatingAvatar.value) return;
    try {
      isUpdatingAvatar.value = true;
      await _saveAvatarPath(null);
      AppSnackbar.show('common.done'.tr, 'profile.photoDeleted'.tr);
    } catch (_) {
      AppSnackbar.show('profile.photoDeleteFailed'.tr, 'common.retry'.tr);
    } finally {
      isUpdatingAvatar.value = false;
    }
  }

  Future<void> _saveAvatarPath(String? path) async {
    await SessionService.saveAvatarPath(path);
    final current = profile.value;
    profile.value = UserProfileModel(
      name: current?.name,
      email: current?.email,
      phone: current?.phone,
      address: current?.address,
      avatarPath: path,
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
      referralInfo.value = null;
      profile.value = UserProfileModel.fromBackend(
        null,
        fallback: await SessionService.getUserIdentity(),
      );
    } finally {
      isLoggingOut.value = false;
    }
  }

  Future<void> deleteAccount(String password) async {
    if (isDeletingAccount.value) return;
    final token = _authState.token.value;
    if (token == null || token.trim().isEmpty) {
      throw AuthApiException('guard.loginRequired'.tr);
    }

    isDeletingAccount.value = true;
    try {
      await _authRepository.deleteAccount(token: token, password: password);
      if (Get.isRegistered<AppCartService>()) {
        Get.find<AppCartService>().clear();
      }
      await _authState.markGuest();
      referralInfo.value = null;
      profile.value = UserProfileModel.fromBackend(
        null,
        fallback: await SessionService.getUserIdentity(),
      );
    } finally {
      isDeletingAccount.value = false;
    }
  }

  static Future<void> persistLocale(String code) async {
    await SessionService.saveLocaleCode(code);
  }
}
