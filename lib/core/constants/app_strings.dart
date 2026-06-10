import 'package:get/get.dart';

class AppStrings {
  AppStrings._();

  static const String appName = 'NajizGo';

  // These are used in a few legacy places — redirected to i18n for proper translation.
  static String get welcomeBack => 'login.title'.tr;
  static String get loginSubtitle => 'login.subtitle'.tr;
  static String get createAccount => 'auth.createAccountBtn'.tr;
  static String get signupSubtitle => 'auth.joinSubtitle'.tr;
  static String get name => 'auth.fullNameLabel'.tr;
  static String get phone => 'auth.phoneLabel'.tr;
  static String get confirmPassword => 'auth.confirmNewPasswordLabel'.tr;
  static String get mobileOrEmail => 'auth.enterPhoneHint'.tr;
  static String get password => 'login.passwordLabel'.tr;
  static String get forgotPassword => 'login.forgotPassword'.tr;
  static String get login => 'login.loginBtn'.tr;
  static String get sendCode => 'auth.sendOtpBtn'.tr;
  static String get enterCode => 'auth.verificationSubtitle'.tr;
  static String get verifyCode => 'auth.verificationTitle'.tr;
  static String get continueText => 'common.confirm'.tr;
  static String get updatePassword => 'auth.updatePasswordBtn'.tr;
  static String get resetSubtitle => 'auth.newPasswordHint'.tr;
  static String get orContinueWith => 'login.orContinueWith'.tr;
  static String get google => 'login.google'.tr;
  static String get apple => 'login.apple'.tr;
  static String get dontHaveAccount => 'auth.alreadyHaveAccount'.tr;
  static String get signUp => 'auth.createAccountBtn'.tr;
}
