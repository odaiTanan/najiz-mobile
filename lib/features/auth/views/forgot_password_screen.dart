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
                  title: 'إعادة تعيين كلمة المرور',
                  subtitle:
                      'أدخل رقم الجوال المرتبط بحسابك وسنرسل لك رمز تحقق (OTP) لإعادة تعيين كلمة المرور.',
                ),
                const SizedBox(height: 18),
                AuthTextField(
                  label: 'رقم الجوال',
                  hintText: 'مثال: 0991234567',
                  controller: controller.phoneController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 18),
                Obx(
                  () => AuthButton(
                    text: 'إرسال رمز التحقق',
                    isLoading: controller.isLoading.value,
                    onPressed: controller.sendCode,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: const Text(
                      'تذكرت كلمة المرور',
                      style: TextStyle(color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 120),
                Center(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      children: [
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

