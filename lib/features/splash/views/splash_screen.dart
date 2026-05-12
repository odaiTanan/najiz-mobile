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
  static const _navDelay = Duration(milliseconds: 900);

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
                    'assets/lottie/yellow_delivery_guy.json',
                    width: w * 0.92,
                    fit: BoxFit.contain,
                    repeat: true,
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

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo();

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float;
  late final Animation<double> _floatY;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _floatY = Tween<double>(begin: -5, end: 5).animate(
      CurvedAnimation(parent: _float, curve: Curves.easeInOut),
    );
    Future<void>.delayed(_kLogoAnimDuration, () {
      if (!mounted) return;
      _float.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

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
        // دخول خفيف: شفافية + ارتفاع بسيط + تكبير دقيق (مثل Instagram / Spotify).
        final entered = Opacity(
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
        return AnimatedBuilder(
          animation: _floatY,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, _float.isAnimating ? _floatY.value : 0),
              child: entered,
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Image.asset(
          logoAsset,
          height: 228,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
