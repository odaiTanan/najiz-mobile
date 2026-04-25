import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
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
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AnimatedAuthIcon(),
              const SizedBox(height: 10),
              const Text(
                'تسجيل الدخول مطلوب',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2C2C2C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  color: Color(0xFF636363),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.to(() => const LoginScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF6EC),
                    foregroundColor: const Color(0xFFB97B2A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: Color(0xFFE9DCCF)),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'تسجيل الدخول',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  Get.back();
                  Get.to(() => const SignupScreen());
                },
                child: const Text(
                  'إنشاء حساب',
                  style: TextStyle(
                    color: Color(0xFFB97B2A),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    color: Color(0xFFB8A796),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
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
