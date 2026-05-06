import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';
import 'package:video_player/video_player.dart';

/// Video splash: plays once, then navigates to home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _splashVideoPath = 'assets/videos/splash.mp4.mp4';
  static const _fallbackDelay = Duration(seconds: 4);
  VideoPlayerController? _videoController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _goHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Get.offAll(() => const HomeScreen());
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(_splashVideoPath);
    _videoController = controller;

    controller.addListener(_onVideoTick);

    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.setLooping(false);
      await controller.play();
      setState(() {});
    } catch (_) {
      Future<void>.delayed(_fallbackDelay, _goHome);
    }
  }

  void _onVideoTick() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    if (duration == Duration.zero) return;

    final position = controller.value.position;
    final ended =
        position >= duration - const Duration(milliseconds: 120);
    if (ended) {
      _goHome();
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    final isReady = controller?.value.isInitialized == true;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: isReady
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller!.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
