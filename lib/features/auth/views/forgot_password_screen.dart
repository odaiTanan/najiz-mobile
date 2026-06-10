import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/utils/validators.dart';
import 'package:najiz_go_express/features/auth/controllers/forgot_password_controller.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_button.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_header.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ForgotPasswordController());
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(height: 4),
                AuthHeader(
                  title: 'auth.resetPasswordTitle'.tr,
                  subtitle: 'auth.resetPasswordSubtitle'.tr,
                ),
                const SizedBox(height: 18),
                AuthTextField(
                  label: 'auth.phoneLabel'.tr,
                  hintText: 'auth.phoneHint'.tr,
                  controller: controller.phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 18),
                Obx(
                  () => AuthButton(
                    text: 'auth.sendOtpBtn'.tr,
                    isLoading: controller.isLoading.value,
                    onPressed: controller.sendCode,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'auth.rememberPassword'.tr,
                      style: const TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 120),
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 16,
                      ),
                      children: [
                        TextSpan(text: 'auth.troubleQuestion'.tr),
                        TextSpan(
                          text: 'auth.contactSupport'.tr,
                          style: const TextStyle(color: AppColors.primary),
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
    );
  }
}
