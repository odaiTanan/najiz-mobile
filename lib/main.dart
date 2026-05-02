import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/errors/global_error_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/constants/app_strings.dart';
import 'package:najiz_go_express/core/localization/app_translations.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
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
  Get.put(AppCartService(), permanent: true);
  final pushService = Get.put(PushNotificationService(), permanent: true);
  await pushService.initialize(token: token);
  Get.put(LoginController());
  runApp(MyApp(initialLocaleCode: savedLocale));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialLocaleCode});

  final String? initialLocaleCode;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
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
        return MediaQuery(
          data: media.copyWith(textScaler: const TextScaler.linear(0.88)),
          child: Directionality(
            textDirection: localeCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      theme: ThemeData(
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.primaryLight,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
