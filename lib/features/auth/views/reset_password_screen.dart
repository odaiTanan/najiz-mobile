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

    return Scaffold(
      backgroundColor: AppColors.background,
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
                  title: 'إنشاء كلمة مرور جديدة',
                  subtitle:
                      'ضع كلمة مرور قوية لحساب NajizGo الخاص بك لحماية بياناتك.',
                ),
                const SizedBox(height: 18),
                Obx(
                  () => AuthTextField(
                    label: 'كلمة المرور الجديدة',
                    hintText: 'أدخل على الأقل 8 أحرف',
                    controller: controller.passwordController,
                    obscureText: controller.isPasswordHidden.value,
                    validator: Validators.password8,
                    suffixIcon: IconButton(
                      onPressed: controller.togglePasswordVisibility,
                      icon: Icon(
                        controller.isPasswordHidden.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: Colors.grey,
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
                const Text(
                  'مطلوب كلمة مرور قوية',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Obx(
                  () => AuthTextField(
                    label: 'تأكيد كلمة المرور الجديدة',
                    hintText: 'أعد إدخال كلمة المرور',
                    controller: controller.confirmPasswordController,
                    obscureText: controller.isPasswordHidden.value,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى تأكيد كلمة المرور';
                      }
                      if (value != controller.passwordController.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 18),
                Obx(
                  () => AuthButton(
                    text: 'تحديث كلمة المرور',
                    isLoading: controller.isLoading.value,
                    onPressed: controller.resetPassword,
                  ),
                ),
                const SizedBox(height: 120),
                const Center(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      children: [
                        TextSpan(text: 'هل تواجه مشكلة؟ '),
                        TextSpan(
                          text: 'تواصل مع دعم نجز جو',
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
                      style: const TextStyle(color: AppColors.error),
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

