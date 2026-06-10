import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/features/auth/widgets/auth_text_field.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(String password) onSubmit;

  static Future<bool?> show({
    required BuildContext context,
    required Future<void> Function(String password) onSubmit,
  }) {
    return AppPopupDialog.show<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteAccountDialog(onSubmit: onSubmit),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(_passwordController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      title: Text('profile.deleteAccountTitle'.tr),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'profile.deleteAccountConfirmMessage'.tr,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              label: 'profile.deleteAccountPasswordLabel'.tr,
              hintText: 'profile.deleteAccountPasswordHint'.tr,
              controller: _passwordController,
              obscureText: _obscurePassword,
              textCapitalization: TextCapitalization.none,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'validation.enterPassword'.tr;
                }
                return null;
              },
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text('profile.deleteAccount'.tr),
        ),
      ],
    );
  }
}
