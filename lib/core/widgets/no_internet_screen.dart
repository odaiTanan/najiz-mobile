import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

class NoInternetScreen extends StatefulWidget {
  final Future<void> Function() onRetry;
  final void Function(Object error)? onError;

  const NoInternetScreen({
    super.key,
    required this.onRetry,
    this.onError,
  });

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _isRetrying = false;
  String? _errorText;

  Future<void> _retry() async {
    if (_isRetrying) return;
    setState(() {
      _isRetrying = true;
      _errorText = null;
    });

    try {
      await widget.onRetry();
      if (mounted) {
        // Close this screen only if it is still open.
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Get.back();
        }
      }
    } catch (err) {
      // Allow the caller to handle non-internet errors.
      if (widget.onError != null) {
        widget.onError!(err);
        return;
      }
      // If retry still fails with no special handler, keep the user on this screen.
      if (mounted) {
        setState(() {
          _errorText = 'لا يتوفر إنترنت حاليا، حاول مرة أخرى';
        });
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 18),
                const Text(
                  'لا يتوفر إنترنت',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تحقق من الاتصال ثم اضغط إعادة المحاولة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _errorText!,
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                    child: _isRetrying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'إعادة المحاولة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
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

