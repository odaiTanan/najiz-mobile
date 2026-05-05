import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/session_service.dart';

/// تفضيل المستخدم: فاتح أو داكن (يُحفظ في [SharedPreferences]).
class ThemeController extends GetxController {
  final isDark = false.obs;

  ThemeMode get materialThemeMode =>
      isDark.value ? ThemeMode.dark : ThemeMode.light;

  Future<void> hydrate() async {
    isDark.value = await SessionService.isDarkThemePreferred();
  }

  Future<void> setDark(bool value) async {
    isDark.value = value;
    await SessionService.saveThemeModeDark(value);
  }
}
