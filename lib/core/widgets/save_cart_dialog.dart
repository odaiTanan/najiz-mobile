import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';

/// Shows a confirmation dialog asking whether to save the current cart.
/// Returns `true` if user wants to save, `false` to discard, `null` if dismissed.
Future<bool?> showSaveCartDialog(BuildContext context) {
  return AppPopupDialog.show<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text('cart.saveTitle'.tr),
      content: Text('cart.saveMessage'.tr),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('cart.saveNo'.tr),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('cart.saveYes'.tr),
        ),
      ],
    ),
  );
}
