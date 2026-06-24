import 'package:get/get.dart';
import 'package:najiz_go_express/features/auth/views/forgot_password_screen.dart';
import 'package:najiz_go_express/features/auth/views/login_screen.dart';
import 'package:najiz_go_express/features/auth/views/signup_screen.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';
import 'package:najiz_go_express/features/notifications/views/notifications_screen.dart';
import 'package:najiz_go_express/features/profile/models/create_address_payload.dart';
import 'package:najiz_go_express/features/profile/views/profile_address_editor_screen.dart';
import 'package:najiz_go_express/features/profile/views/profile_settings_screen.dart';
import 'package:najiz_go_express/features/profile/views/referral_coupon_screen.dart';
import 'package:najiz_go_express/features/search/views/search_screen.dart';
import 'package:najiz_go_express/features/support/views/cms_dynamic_page_screen.dart';
import 'package:najiz_go_express/features/support/views/faq_screen.dart';
import 'package:najiz_go_express/features/support/views/support_chat_screen.dart';

/// Central navigation entry points for the app.
class AppRoutes {
  AppRoutes._();

  // ── Root ──────────────────────────────────────────────────────────────────

  static void openHome({String? token, bool offAll = true}) {
    final page = HomeScreen(token: token);
    if (offAll) {
      Get.offAll(() => page);
    } else {
      Get.off(() => page);
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static void openLogin({bool offAll = false}) {
    const page = LoginScreen();
    if (offAll) {
      Get.offAll(() => page);
    } else {
      Get.to(() => page);
    }
  }

  static void openSignup() {
    Get.to(() => const SignupScreen());
  }

  static void openForgotPassword() {
    Get.to(() => const ForgotPasswordScreen());
  }

  // ── Notifications & support ─────────────────────────────────────────────────

  static void openNotifications() {
    Get.to(() => const NotificationsScreen());
  }

  static void openSupportChat({required String token}) {
    Get.to(() => SupportChatScreen(token: token));
  }

  // ── Profile & CMS ─────────────────────────────────────────────────────────

  static void openProfileSettings({String? token}) {
    Get.to(() => ProfileSettingsScreen(token: token));
  }

  static void openProfileAddressEditor({
    String? initialAddress,
    required Future<void> Function(CreateAddressPayload payload) onSave,
  }) {
    Get.to(
      () => ProfileAddressEditorScreen(
        initialAddress: initialAddress,
        onSave: onSave,
      ),
    );
  }

  static void openReferralCoupon({required String token}) {
    Get.to(() => ReferralCouponScreen(token: token));
  }

  static void openSearch({String? token}) {
    Get.to(() => SearchScreen(token: token));
  }

  static void openFaq({String? token}) {
    Get.to(() => FaqScreen(token: token));
  }

  static void openCmsPage({
    required String slug,
    String? token,
    required String fallbackTitle,
  }) {
    Get.to(
      () => CmsDynamicPageScreen(
        slug: slug,
        token: token,
        fallbackTitle: fallbackTitle,
      ),
    );
  }
}
