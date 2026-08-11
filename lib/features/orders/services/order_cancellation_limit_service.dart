import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/theme/theme_context.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderCancellationLimitService extends GetxService {
  static const _countKey = 'order_cancellation_count';
  static const cancellationLimit = 3;

  Future<int> _incrementCount() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_countKey) ?? 0) + 1;
    await prefs.setInt(_countKey, next);
    return next;
  }

  Future<void> _resetCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_countKey);
  }

  /// Records a successful cancellation and enforces the local limit when reached.
  /// Returns `true` when the account was restricted and the user was signed out.
  Future<bool> onOrderCancelledSuccessfully(BuildContext context) async {
    final count = await _incrementCount();
    if (count < cancellationLimit) return false;
    if (!context.mounted) return false;

    await _showRestrictionDialog(context);
    if (Get.isRegistered<AppCartService>()) {
      Get.find<AppCartService>().clear();
    }
    await Get.find<AuthStateManager>()
        .invalidateSessionAndOpenLogin(offAll: true);
    await _resetCount();
    return true;
  }

  Future<void> _showRestrictionDialog(BuildContext context) {
    return AppPopupDialog.show<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AppPopupDialog.wrap(
        dialogContext,
        AlertDialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text(
            'orders.cancellationLimitTitle'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: dialogContext.uiText,
            ),
          ),
          content: Text(
            'orders.cancellationLimitMessage'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: dialogContext.uiSubtext,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'orders.cancellationLimitOk'.tr,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
