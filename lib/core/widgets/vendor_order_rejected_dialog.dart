import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';

Future<void> showVendorOrderRejectedDialog(
  BuildContext context, {
  required bool isStoreOrder,
}) {
  return AppPopupDialog.show<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final message = isStoreOrder
          ? 'tracking.storeRejectedMessage'.tr
          : 'tracking.vendorRejectedMessage'.tr;

      return PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    AppColors.primary.withValues(alpha: 0.14),
                    cs.surface,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  isStoreOrder
                      ? Icons.storefront_outlined
                      : Icons.restaurant_outlined,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('tracking.returnHome'.tr),
              ),
            ),
          ],
        ),
      );
    },
  );
}
