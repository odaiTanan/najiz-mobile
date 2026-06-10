import 'package:get/get.dart';

/// User-facing error messages — returns translated strings via i18n.
class AppErrorMessages {
  AppErrorMessages._();

  static String get noInternet => 'errors.noInternet'.tr;
  static String get requestTimeout => 'errors.requestTimeout'.tr;
  static String get connectionFailed => 'errors.connectionFailed'.tr;
  static String get unexpected => 'errors.unexpected'.tr;
  static String get serverUnavailable => 'errors.serverUnavailable'.tr;
  static String get notFound => 'errors.notFound'.tr;
  static String get unauthorized => 'errors.unauthorized'.tr;
  static String get forbidden => 'errors.forbidden'.tr;
  static String get badRequest => 'errors.badRequest'.tr;
  static String get displayError => 'errors.displayError'.tr;
}
