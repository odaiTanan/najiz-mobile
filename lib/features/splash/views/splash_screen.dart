import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoController;
  late final Animation<double> _logoScale;
  late final Animation<Offset> _logoSlide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _logoScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.04),
      end: const Offset(0, 0.04),
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));

    _timer = Timer(const Duration(milliseconds: 2800), () {
      Get.offAll(() => const HomeScreen());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0, -0.45),
              child: SlideTransition(
                position: _logoSlide,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Image.asset(
                      'assets/najiz_go_express_logo.png',
                      height: 160,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, 0.62),
              child: SizedBox(
                width: 220,
                height: 170,
                child: Lottie.network(
                  'https://assets10.lottiefiles.com/packages/lf20_jbrw3hcz.json',
                  repeat: true,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
