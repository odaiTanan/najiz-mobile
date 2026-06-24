import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/features/orders/controllers/transport_order_tracking_controller.dart';
import 'package:najiz_go_express/features/orders/errors/orders_api_exception.dart';

class TaxiTripSosButton extends StatelessWidget {
  const TaxiTripSosButton({
    super.key,
    required this.controller,
    this.floating = false,
  });

  final TransportOrderTrackingController controller;
  final bool floating;

  static const int _maxReasonLength = 500;

  static Future<void> showDialog({
    required BuildContext context,
    required TransportOrderTrackingController controller,
  }) {
    return AppPopupDialog.show(
      context: context,
      barrierDismissible: !controller.isSubmittingSos.value,
      builder: (dialogContext) => _TaxiSosDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.canShowTaxiSos) {
        return const SizedBox.shrink();
      }

      final isBusy = controller.isSubmittingSos.value;
      final isSent = controller.sosSubmitted.value;

      if (floating) {
        return Material(
          elevation: 6,
          shadowColor: Colors.red.withValues(alpha: 0.35),
          color: isSent ? Colors.green.shade700 : Colors.red.shade700,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: isBusy || isSent
                ? null
                : () => showDialog(context: context, controller: controller),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Center(
                child: isBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isSent ? '✓' : 'SOS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isBusy || isSent
              ? null
              : () => showDialog(context: context, controller: controller),
          icon: isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(isSent ? Icons.check_circle_outline : Icons.sos_outlined),
          label: Text(
            isSent ? 'tracking.sosSent'.tr : 'tracking.sosButton'.tr,
          ),
          style: FilledButton.styleFrom(
            backgroundColor: isSent ? Colors.green.shade700 : Colors.red.shade700,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    });
  }
}

class _TaxiSosDialog extends StatefulWidget {
  const _TaxiSosDialog({required this.controller});

  final TransportOrderTrackingController controller;

  @override
  State<_TaxiSosDialog> createState() => _TaxiSosDialogState();
}

class _TaxiSosDialogState extends State<_TaxiSosDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reasonController.text.trim();
    try {
      await widget.controller.sendSos(
        reason: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(
        'tracking.sosSentTitle'.tr,
        'tracking.sosSentMessage'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
      );
    } on OrdersApiException catch (e) {
      AppSnackbar.show('tracking.sosFailed'.tr, e.message);
    } catch (_) {
      AppSnackbar.show(
        'tracking.sosFailed'.tr,
        'errors.generic'.tr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Obx(() {
      final isBusy = widget.controller.isSubmittingSos.value;

      return AlertDialog(
        title: Row(
          children: [
            Icon(Icons.sos_outlined, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'tracking.sosDialogTitle'.tr,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tracking.sosDialogMessage'.tr,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _reasonController,
                enabled: !isBusy,
                maxLength: TaxiTripSosButton._maxReasonLength,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'tracking.sosReasonLabel'.tr,
                  hintText: 'tracking.sosReasonHint'.tr,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isBusy ? null : () => Navigator.of(context).pop(),
            child: Text('common.cancel'.tr),
          ),
          FilledButton(
            onPressed: isBusy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            child: isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('tracking.sosConfirm'.tr),
          ),
        ],
      );
    });
  }
}
