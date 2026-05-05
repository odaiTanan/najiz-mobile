import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/theme/theme_context.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/features/auth/views/login_screen.dart';
import 'package:najiz_go_express/features/auth/views/signup_screen.dart';

class AuthGuardService {
  AuthGuardService._();

  static Future<void> runOrRequestLogin({
    required Future<void> Function(String token) onAuthenticated,
    String message = 'يرجى تسجيل الدخول لإكمال الطلب',
  }) async {
    final auth = Get.find<AuthStateManager>();
    if (auth.isAuthenticated) {
      await onAuthenticated(auth.token.value!);
      return;
    }

    auth.setPendingIntent(onAuthenticated);

    await Get.dialog<void>(
      Builder(
        builder: (dialogContext) => AppPopupDialog.wrap(
          dialogContext,
          Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              decoration: AppPopupDialog.cardDecoration(dialogContext, radius: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _AnimatedAuthIcon(),
                  const SizedBox(height: 10),
                  Text(
                    'تسجيل الدخول مطلوب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: dialogContext.uiText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      color: dialogContext.uiSubtext,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Get.back();
                        Get.to(() => const LoginScreen());
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        'تسجيل الدخول',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        Get.to(() => const SignupScreen());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        backgroundColor: dialogContext.uiCard,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        'إنشاء حساب',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: const Text(
                      'إلغاء',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }
}

class _AnimatedAuthIcon extends StatefulWidget {
  const _AnimatedAuthIcon();

  @override
  State<_AnimatedAuthIcon> createState() => _AnimatedAuthIconState();
}

class _AnimatedAuthIconState extends State<_AnimatedAuthIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1.05).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6EC),
          borderRadius: BorderRadius.circular(33),
          border: Border.all(color: const Color(0xFFF0D9BD)),
        ),
        child: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFFB97B2A),
          size: 34,
        ),
      ),
    );
  }
}
