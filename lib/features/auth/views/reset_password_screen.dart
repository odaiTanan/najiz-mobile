import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/utils/validators.dart';
import 'package:najiz_go_express/features/auth/controllers/reset_password_controller.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_button.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_header.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_text_field.dart';

class ResetPasswordScreen extends StatelessWidget {
  final String phone;
  final String resetToken;

  const ResetPasswordScreen({
    super.key,
    required this.phone,
    required this.resetToken,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ResetPasswordController(
        phone: phone,
        resetToken: resetToken,
      ),
    );
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
                  title: 'auth.newPasswordLabel'.tr,
                  subtitle: 'auth.newPasswordHint'.tr,
                ),
                const SizedBox(height: 18),
                Obx(
                  () => AuthTextField(
                    label: 'auth.newPasswordLabel'.tr,
                    hintText: 'auth.newPasswordHint'.tr,
                    controller: controller.passwordController,
                    obscureText: controller.isPasswordHidden.value,
                    validator: Validators.password8,
                    suffixIcon: IconButton(
                      onPressed: controller.togglePasswordVisibility,
                      icon: Icon(
                        controller.isPasswordHidden.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const LinearProgressIndicator(
                  value: 0.35,
                  backgroundColor: Color(0xFFFFE4CC),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                ),
                const SizedBox(height: 6),
                Text(
                  'auth.strongPasswordHint'.tr,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Obx(
                  () => AuthTextField(
                    label: 'auth.confirmNewPasswordLabel'.tr,
                    hintText: 'auth.reenterPasswordHint'.tr,
                    controller: controller.confirmPasswordController,
                    obscureText: controller.isPasswordHidden.value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'validation.confirmPassword'.tr;
                      }
                      if (value != controller.passwordController.text) {
                        return 'validation.passwordsMismatch'.tr;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Obx(
                  () => AuthButton(
                    text: 'auth.updatePasswordBtn'.tr,
                    isLoading: controller.isLoading.value,
                    onPressed: controller.resetPassword,
                  ),
                ),
                const SizedBox(height: 120),
                Center(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 16,
                      ),
                      children: [
                        TextSpan(text: 'auth.troubleQuestion'.tr),
                        TextSpan(
                          text: 'auth.contactNajizSupport'.tr,
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
