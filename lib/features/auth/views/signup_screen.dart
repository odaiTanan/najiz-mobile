import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/utils/validators.dart';
import 'package:najiz_go_express/features/auth/controllers/signup_controller.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_button.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_header.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_text_field.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SignupController());
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
                  title: 'auth.joinTitle'.tr,
                  subtitle: 'auth.joinSubtitle'.tr,
                ),
                const SizedBox(height: 18),
                AuthTextField(
                  label: 'auth.fullNameLabel'.tr,
                  hintText: 'auth.fullNameLabel'.tr,
                  controller: controller.nameController,
                  validator: Validators.fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'auth.emailLabel'.tr,
                  hintText: 'auth.emailHint'.tr,
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.email,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                const SizedBox(height: 14),
                Text(
                  'auth.phoneLabel'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 76,
                      child: TextFormField(
                        controller: controller.countryCodeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cs.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: controller.phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: Validators.syrianMobileLocal,
                        decoration: InputDecoration(
                          hintText: '',
                          prefixIcon: const Icon(Icons.phone_iphone_outlined),
                          filled: true,
                          fillColor: cs.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Obx(
                  () => AuthTextField(
                    label: 'login.passwordLabel'.tr,
                    hintText: 'auth.enterPasswordHint'.tr,
                    controller: controller.passwordController,
                    obscureText: controller.isPasswordHidden.value,
                    validator: Validators.password8,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    onChanged: controller.onPasswordChanged,
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
                Obx(() {
                  final message = controller.passwordLiveMessage.value;
                  if (message == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: controller.isPasswordStrong.value
                            ? Colors.green
                            : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),
                Obx(
                  () => AuthTextField(
                    label: 'auth.confirmNewPasswordLabel'.tr,
                    hintText: 'auth.reenterPasswordHint'.tr,
                    controller: controller.confirmPasswordController,
                    obscureText: controller.isConfirmPasswordHidden.value,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'validation.confirmPassword'.tr;
                      }
                      if (value != controller.passwordController.text) {
                        return 'validation.passwordsMismatch'.tr;
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      onPressed: controller.toggleConfirmPasswordVisibility,
                      icon: Icon(
                        controller.isConfirmPasswordHidden.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'auth.referralCodeLabel'.tr,
                  hintText: 'auth.referralCodeHint'.tr,
                  controller: controller.referralCodeController,
                  textCapitalization: TextCapitalization.characters,
                  prefixIcon: const Icon(Icons.card_giftcard_outlined),
                ),
                const SizedBox(height: 18),
                Obx(
                  () => AuthButton(
                    text: 'auth.createAccountBtn'.tr,
                    isLoading: controller.isLoading.value,
                    onPressed: controller.signUp,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'auth.alreadyHaveAccount'.tr,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      InkWell(
                        onTap: () => Get.back(),
                        child: Text(
                          'auth.loginHere'.tr,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
