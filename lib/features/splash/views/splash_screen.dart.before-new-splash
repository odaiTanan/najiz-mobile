import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/home/controllers/home_controller.dart';
import 'package:najiz_go_express/features/home/services/home_bootstrap_cache.dart';
import 'package:najiz_go_express/features/orders/views/transport_order_tracking_screen.dart';
import 'package:najiz_go_express/features/taxi/services/taxi_cold_start_restorer.dart';
import 'package:najiz_go_express/features/taxi/views/taxi_booking_screen.dart';

const _kMinSplashDuration = Duration(milliseconds: 1600);
const _kAnimationWaitTimeout = Duration(seconds: 3);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final Completer<void> _animationDone = Completer<void>();

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

    // Taxi cold-start: classify newest active taxi while splash runs.
    final resumeFuture = auth.isGuest
        ? Future<TaxiColdStartIntent>.value(const TaxiColdStartIntent.none())
        : TaxiColdStartRestorer.resolve(token: auth.token.value);

    await Future.wait<void>([
      Future<void>.delayed(_kMinSplashDuration),
      _animationDone.future.timeout(_kAnimationWaitTimeout, onTimeout: () {}),
    ]);

    if (!mounted) return;
    final intent = await resumeFuture;
    if (!mounted) return;

    final token = auth.token.value;
    switch (intent.kind) {
      case TaxiColdStartKind.searching:
        final order = intent.order;
        if (order == null || token == null || token.trim().isEmpty) {
          _goHome();
          return;
        }
        Get.offAll(
          () => TaxiBookingScreen(
            token: token,
            resumeSearchingOrder: order,
          ),
        );
        return;
      case TaxiColdStartKind.assigned:
        final order = intent.order;
        if (order == null || token == null || token.trim().isEmpty) {
          _goHome();
          return;
        }
        // Same destination as Home openPrimaryActiveOrder / My Orders track.
        Get.offAll(
          () => TransportOrderTrackingScreen(
            token: token,
            orderId: order.orderId,
            orderNumber: order.orderNumber,
            orderType: 'taxi',
            initialStatus: order.status,
            initialDispatchStatus: order.dispatchStatus,
            pickupLat: order.lat,
            pickupLng: order.lng,
            destinationLat: order.lat,
            destinationLng: order.lng,
          ),
        );
        return;
      case TaxiColdStartKind.noDriver:
        if (token == null || token.trim().isEmpty) {
          _goHome();
          return;
        }
        // Same dialog as Finding Driver _handleNoDriver → showNoDriverAssignedDialog.
        Get.offAll(
          () => TaxiBookingScreen(
            token: token,
            resumeNoDriverDialog: true,
          ),
        );
        return;
      case TaxiColdStartKind.none:
        _goHome();
        return;
    }
  }

  void _goHome() {
    if (!mounted) return;
    AppRoutes.openHome();
  }

  @override
  Widget build(BuildContext context) {
    final pageBg = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark ? 'assets/logo_dark.png' : 'assets/logo_light.png';
    final screenHeight = MediaQuery.sizeOf(context).height;
    return Scaffold(
      backgroundColor: pageBg,
      body: ColoredBox(
        color: pageBg,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.topCenter,
                  child: Image.asset(
                    logoAsset,
                    height: (screenHeight * 0.11).clamp(56.0, 90.0),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _AnimatedLogo(
                    height: (screenHeight * 0.28).clamp(170.0, 260.0),
                    onCompleted: () {
                      if (!_animationDone.isCompleted) {
                        _animationDone.complete();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLogo extends StatefulWidget {
  const _AnimatedLogo({required this.height, required this.onCompleted});

  final double height;
  final VoidCallback onCompleted;

  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SizedBox(
        height: widget.height,
        child: Lottie.asset(
          'assets/lottie/yellow_delivery_guy.json',
          controller: _controller,
          repeat: false,
          fit: BoxFit.contain,
          onLoaded: (composition) {
            _controller.duration = composition.duration;
            if (!_didStart) {
              _didStart = true;
              _controller.forward(from: 0);
            }
          },
        ),
      ),
    );
  }
}
