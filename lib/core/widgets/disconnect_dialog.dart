import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';

/// Shows a "connection lost" dialog with a retry callback.
/// Used in taxi, shipping, and transport tracking screens.
void showDisconnectDialog(BuildContext context, {required VoidCallback onRetry}) {
  AppPopupDialog.show<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Theme.of(dialogContext).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Text('connection.disconnectTitle'.tr),
      content: Text('connection.disconnectMessage'.tr),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('connection.close'.tr),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(dialogContext).pop();
            onRetry();
          },
          child: Text('connection.retry'.tr),
        ),
      ],
    ),
  );
}
