import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';

/// مدة دخول الشعار: قصيرة وناعمة (نمط تطبيقات premium).
const _kLogoAnimDuration = Duration(milliseconds: 1180);

/// ~4 أسطر تقريباً (ارتفاع سطر نص ~22 logical px).
const _kLogoTopNudge = 88.0;

/// Splash: يتبع خلفية الثيم — شعار بنصف الصفحة تقريباً مع أنيميشن خفيف، Lottie أسفل.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _navDelay = Duration(milliseconds: 5200);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(_navDelay, _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    Get.offAll(() => const HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final w = size.width;

    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: pageBg,
      body: ColoredBox(
        color: pageBg,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: (topInset > 0 ? 12.0 : 24.0) + _kLogoTopNudge),
              const Center(child: _AnimatedLogo()),
              const Spacer(flex: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                child: Center(
                  child: Lottie.asset(
                    'assets/lottie/delivery_splash.json',
                    width: w * 0.92,
                    fit: BoxFit.contain,
                    repeat: false,
                    delegates: LottieDelegates(
                      values: [
                        ValueDelegate.opacity(
                          const ['White Solid 1', '**'],
                          value: 0,
                        ),
                      ],
                    ),
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.02),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedLogo extends StatelessWidget {
  const _AnimatedLogo();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _kLogoAnimDuration,
      curve: Curves.easeOutQuart,
      builder: (context, t, child) {
        final u = t.clamp(0.0, 1.0);
        // دخول خفيف: شفافية + ارتفاع بسيط + تكبير دقيق (مثل Instagram / Spotify).
        return Opacity(
          opacity: u,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - u)),
            child: Transform.scale(
              scale: 0.965 + 0.035 * u,
              alignment: Alignment.center,
              child: child,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Image.asset(
          'assets/logo.png',
          height: 132,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
