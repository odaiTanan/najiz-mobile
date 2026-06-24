import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
import 'package:najiz_go_express/features/home/services/home_bootstrap_cache.dart';

/// مدة دخول الشعار: قصيرة — لا تنتظر الشبكة.
const _kLogoAnimDuration = Duration(milliseconds: 650);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _navDelay = Duration(milliseconds: 120);

  @override
  void initState() {
    super.initState();
    _startBootstrap();
  }

  Future<void> _startBootstrap() async {
    await HomeBootstrapCache.warmMemory();
    final auth = Get.find<AuthStateManager>();
    final controller = Get.put(
      HomeController(token: auth.token.value),
      permanent: true,
    );
    controller.primeInstantShell();
    unawaited(controller.loadHomeData());

    await Future<void>.delayed(_navDelay);
    _goHome();
  }

  void _goHome() {
    if (!mounted) return;
    AppRoutes.openHome();
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: pageBg,
      body: ColoredBox(
        color: pageBg,
        child: SafeArea(
          child: Center(
            child: _AnimatedLogo(
              height: (MediaQuery.sizeOf(context).height * 0.22).clamp(96.0, 180.0),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo({required this.height});

  final double height;

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _kLogoAnimDuration,
      curve: Curves.easeOutQuart,
      builder: (context, t, child) {
        final u = t.clamp(0.0, 1.0);
        return Opacity(
          opacity: u,
          child: Transform.scale(
            scale: 0.94 + 0.06 * u,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Image.asset(
          logoAsset,
          height: widget.height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
