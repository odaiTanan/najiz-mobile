import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/constants/app_strings.dart';
import 'package:najiz_go_express/core/utils/validators.dart';
import 'package:najiz_go_express/features/auth/controllers/otp_verification_controller.dart';
import 'package:najiz_go_express/features/auth/models/otp_purpose.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_button.dart';

class OtpVerificationScreen extends StatefulWidget {
  final OtpPurpose purpose;
  final String phone;

  const OtpVerificationScreen({
    super.key,
    required this.purpose,
    required this.phone,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final OtpVerificationController controller;
  final FocusNode _codeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      OtpVerificationController(purpose: widget.purpose, phone: widget.phone),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _codeFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isForgot = widget.purpose == OtpPurpose.forgotPassword;
    final cs = Theme.of(context).colorScheme;

    String formatUnit(int value) => value.toString().padLeft(2, '0');

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        // If the system didn't pop, we still allow leaving the screen.
        if (!didPop && mounted) Get.back();
      },
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            child: Form(
              key: controller.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                      Row(
                        children: [
                          Icon(Icons.arrow_back, size: 18, color: cs.onSurface),
                          const SizedBox(width: 10),
                          Text(
                            'التحقق',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 24,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: const Icon(
                          Icons.verified_user,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.enterCode,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أدخل رمز التحقق المكوّن من 6 أرقام المرسل إلى رقم الجوال أو البريد الإلكتروني للمتابعة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Stack(
                        children: [
                          Opacity(
                            // Keep it hit-testable while still invisible.
                            opacity: 0.01,
                            child: TextFormField(
                              controller: controller.codeController,
                              focusNode: _codeFocusNode,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onChanged: controller.onCodeChanged,
                              validator: Validators.otpCode,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _codeFocusNode.requestFocus();
                              // Place cursor at the end for easier editing/deleting.
                              final text = controller.codeController.text;
                              controller.codeController.selection =
                                  TextSelection.collapsed(offset: text.length);
                            },
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: controller.codeController,
                              builder: (_, value, unusedValue) {
                                final code = value.text;
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (index) {
                                    final char = index < code.length
                                        ? code[index]
                                        : '';
                                    final isCurrent = code.length == index;
                                    return Container(
                                      width: 44,
                                      height: 52,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isCurrent
                                              ? AppColors.primary
                                              : cs.outlineVariant,
                                          width: isCurrent ? 1.4 : 1,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        char,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: cs.onSurface,
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Obx(() {
                        final minutes = controller.remainingSeconds.value ~/ 60;
                        final seconds = controller.remainingSeconds.value % 60;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _TimeBox(
                              value: formatUnit(minutes),
                              label: 'د',
                              colorScheme: cs,
                            ),
                            const SizedBox(width: 12),
                            _TimeBox(
                              value: formatUnit(seconds),
                              label: 'ث',
                              colorScheme: cs,
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 14),
                      Obx(
                        () => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'لم يصلك الرمز؟ ',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            GestureDetector(
                              onTap: controller.remainingSeconds.value == 0
                                  ? controller.resendCode
                                  : null,
                              child: Text(
                                'إعادة إرسال الرمز',
                                style: TextStyle(
                                  color: controller.remainingSeconds.value == 0
                                      ? AppColors.primary
                                      : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => AuthButton(
                          text: isForgot
                              ? AppStrings.continueText
                              : AppStrings.verifyCode,
                          isLoading: controller.isLoading.value,
                          onPressed: controller.submit,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 16,
                      ),
                      children: const [
                        TextSpan(text: 'هل تواجه مشكلة؟ '),
                        TextSpan(
                          text: 'تواصل مع الدعم',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                Obx(() {
                  final err = controller.errorMessage.value;
                  if (err == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      err,
                      style: TextStyle(color: cs.error),
                    ),
                  );
                }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String value;
  final String label;
  final ColorScheme colorScheme;

  const _TimeBox({
    required this.value,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 58,
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
