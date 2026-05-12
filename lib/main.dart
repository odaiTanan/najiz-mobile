import 'dart:async';

import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/errors/global_error_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_strings.dart';
import 'package:najiz_go_express/core/localization/app_translations.dart';
import 'package:najiz_go_express/core/services/theme_controller.dart';
import 'package:najiz_go_express/core/theme/app_theme.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/no_internet_gate_controller.dart';
import 'package:najiz_go_express/core/widgets/no_internet_screen.dart';
import 'package:najiz_go_express/core/services/favorites_controller.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/features/auth/controllers/login_controller.dart';
import 'package:najiz_go_express/features/splash/views/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  installGlobalErrorHandling();
  await AppTranslations.init();
  final token = await SessionService.getToken();
  final savedLocale = await SessionService.getLocaleCode();
  final authStateManager = Get.put(AuthStateManager(), permanent: true);
  await authStateManager.initialize(initialToken: token);
  Get.put(FavoritesController(), permanent: true);
  Get.put(AppCartService(), permanent: true);
  Get.put(ThemeController(), permanent: true);
  await Get.find<ThemeController>().hydrate();
  Get.put(NoInternetGateController(), permanent: true);
  Get.put(PushNotificationService(), permanent: true);
  Get.put(LoginController());
  runApp(MyApp(initialLocaleCode: savedLocale));
  unawaited(Get.find<PushNotificationService>().initialize(token: token));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialLocaleCode});

  final String? initialLocaleCode;

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();
    return Obx(
      () => GetMaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeController.materialThemeMode,
        translations: AppTranslations.instance,
        locale: initialLocaleCode == 'en'
            ? const Locale('en', 'US')
            : const Locale('ar', 'SA'),
        fallbackLocale: const Locale('ar', 'SA'),
        supportedLocales: const [
          Locale('ar', 'SA'),
          Locale('ar'),
          Locale('en', 'US'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) {
          final localeCode = Localizations.localeOf(context).languageCode;
          final media = MediaQuery.of(context);
          final gate = Get.find<NoInternetGateController>();
          final wrapped = MediaQuery(
            data: media.copyWith(textScaler: const TextScaler.linear(0.88)),
            child: Directionality(
              textDirection: localeCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
          );
          return Obx(() {
            if (!gate.active.value) return wrapped;
            return Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFFFF8F0),
                        Color(0xFFFFF0E0),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                  child: const SizedBox.expand(),
                ),
                NoInternetScreen(
                  onRetry: () => gate.invokeUserRetry(),
                  onRetrySucceeded: gate.dismiss,
                ),
              ],
            );
          });
        },
        home: const SplashScreen(),
      ),
    );
  }
}
