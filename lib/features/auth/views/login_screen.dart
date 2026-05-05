import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_strings.dart';
import 'package:najiz_go_express/core/theme/text_styles.dart';
import 'package:najiz_go_express/core/utils/validators.dart';
import 'package:najiz_go_express/features/auth/controllers/login_controller.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_button.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_header.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_text_field.dart';
import 'package:najiz_go_express/features/auth/views/forgot_password_screen.dart';
import 'package:najiz_go_express/features/auth/views/signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LoginController>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
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
                const AuthHeader(),
                const SizedBox(height: 22),
                AuthTextField(
                  label: AppStrings.phone,
                  hintText: 'أدخل رقم الجوال',
                  controller: controller.phoneOrEmailController,
                  keyboardType: TextInputType.phone,
                  validator: Validators.phone,
                ),
                const SizedBox(height: 14),
                Obx(
                  () => AuthTextField(
                    label: AppStrings.password,
                    hintText: 'أدخل كلمة المرور',
                    controller: controller.passwordController,
                    obscureText: controller.isPasswordHidden.value,
                    validator: Validators.password,
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Get.to(() => const ForgotPasswordScreen()),
                    child: Text(AppStrings.forgotPassword, style: AppTextStyles.link),
                  ),
                ),
                const SizedBox(height: 6),
                Obx(
                  () => AuthButton(
                    text: AppStrings.login,
                    isLoading: controller.isLoading.value,
                    onPressed: controller.login,
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${AppStrings.dontHaveAccount} ',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      InkWell(
                        onTap: () => Get.to(() => const SignupScreen()),
                        child: Text(AppStrings.signUp, style: AppTextStyles.link),
                      ),
                    ],
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

