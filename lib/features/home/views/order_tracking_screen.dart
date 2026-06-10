import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/features/home/controllers/order_tracking_controller.dart';
import 'package:najiz_go_express/features/home/views/home_screen.dart';

class OrderTrackingScreen extends StatelessWidget {
  final String token;
  final int orderId;
  final String orderNumber;
  final String initialStatus;
  final String initialDispatchStatus;

  const OrderTrackingScreen({
    super.key,
    required this.token,
    required this.orderId,
    required this.orderNumber,
    required this.initialStatus,
    required this.initialDispatchStatus,
  });

  void _handleBack(OrderTrackingController controller, BuildContext context) {
    Get.off(() => HomeScreen(token: controller.token));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = Get.put(
      OrderTrackingController(
        token: token,
        orderId: orderId,
        orderNumber: orderNumber,
        initialStatus: initialStatus,
        initialDispatchStatus: initialDispatchStatus,
      ),
      tag: 'order-tracking-$orderId',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _handleBack(controller, context);
      },
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () async {
              _handleBack(controller, context);
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          backgroundColor: cs.surfaceContainerLowest,
          foregroundColor: cs.onSurface,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'tracking.title'.tr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Obx(
                () => ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  children: [
                    _TopLiveCard(
                      orderNumber: orderNumber,
                      connected: controller.isLiveConnected.value,
                    ),
                    const SizedBox(height: 12),
                    if (controller.errorMessage.value != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          controller.errorMessage.value!,
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    _StatusCard(
                      title: 'tracking.orderStatus'.tr,
                      value: _statusLabel(controller.currentStatus.value),
                    ),
                    const SizedBox(height: 10),
                    _StatusCard(
                      title: 'tracking.dispatchStatus'.tr,
                      value: _dispatchLabel(controller.currentDispatchStatus.value),
                    ),
                    const SizedBox(height: 14),
                    _TimelineCard(
                      status: controller.currentStatus.value,
                      dispatchStatus: controller.currentDispatchStatus.value,
                    ),
                  ],
                ),
              ),
              _DeliveredRatingListener(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveredRatingListener extends StatefulWidget {
  final OrderTrackingController controller;

  const _DeliveredRatingListener({required this.controller});

  @override
  State<_DeliveredRatingListener> createState() => _DeliveredRatingListenerState();
}

class _DeliveredRatingListenerState extends State<_DeliveredRatingListener>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconAnimationController;

  @override
  void initState() {
    super.initState();
    _iconAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.95,
      upperBound: 1.08,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final delivered = widget.controller.currentStatus.value == 'delivered';
      if (!delivered ||
          widget.controller.ratingSubmitted.value) {
        return const SizedBox.shrink();
      }
      if (!widget.controller.hasPromptedForRating.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.controller.hasPromptedForRating.value = true;
          _showDeliveryCompletedChoiceDialog(
            context,
            widget.controller,
            _iconAnimationController,
          );
        });
      }

      if (!widget.controller.showRatingButton.value) {
        return const SizedBox.shrink();
      }
      return Positioned(
        left: 16,
        right: 16,
        bottom: 14,
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: () => _showRatingDialog(
              context,
              widget.controller,
              _iconAnimationController,
            ),
            icon: const Icon(Icons.star_rounded),
            label: Text(
              'tracking.rateOrder'.tr,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      );
    });
  }
}

Future<void> _showDeliveryCompletedChoiceDialog(
  BuildContext context,
  OrderTrackingController controller,
  Animation<double> iconAnimation,
) async {
  await AppPopupDialog.show<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      final dcs = Theme.of(dialogContext).colorScheme;
      return Dialog(
        backgroundColor: dcs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: iconAnimation,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: dcs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'tracking.orderCompleted'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  color: dcs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'tracking.rateNowQuestion'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dcs.onSurfaceVariant,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      controller.postponeRating();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: dcs.surface,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'tracking.later'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _showRatingDialog(context, controller, iconAnimation);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'tracking.yesNow'.tr,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    },
  );
}

Future<void> _showRatingDialog(
  BuildContext context,
  OrderTrackingController controller,
  Animation<double> iconAnimation,
) async {
  await AppPopupDialog.show<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OrderDeliveredRatingDialog(
      controller: controller,
      iconAnimation: iconAnimation,
    ),
  );
}

class _OrderDeliveredRatingDialog extends StatefulWidget {
  final OrderTrackingController controller;
  final Animation<double> iconAnimation;

  const _OrderDeliveredRatingDialog({
    required this.controller,
    required this.iconAnimation,
  });

  @override
  State<_OrderDeliveredRatingDialog> createState() =>
      _OrderDeliveredRatingDialogState();
}

class _OrderDeliveredRatingDialogState extends State<_OrderDeliveredRatingDialog> {
  late final TextEditingController _commentController;
  int _vendorRating = 5;
  int _deliveryRating = 5;
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ScaleTransition(
                    scale: widget.iconAnimation,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          const Color(0xFF16A34A).withValues(alpha: 0.18),
                          cs.surface,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF0F9D58),
                        size: 40,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'tracking.deliveredSuccess'.tr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'tracking.rateHelpText'.tr,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'tracking.rateVendor'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                _RatingStars(
                  value: _vendorRating,
                  onChanged: (v) => setState(() => _vendorRating = v),
                ),
                const SizedBox(height: 10),
                Text(
                  'tracking.rateDelivery'.tr,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                _RatingStars(
                  value: _deliveryRating,
                  onChanged: (v) => setState(() => _deliveryRating = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  onChanged: (_) {
                    if (_commentError != null) {
                      setState(() => _commentError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'tracking.optionalNotes'.tr,
                    errorText: _commentError,
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Obx(
                    () => FilledButton(
                      onPressed: widget.controller.isSubmittingRating.value
                          ? null
                          : () async {
                              final comment = _commentController.text.trim();
                              final requireComment =
                                  _vendorRating < 4 || _deliveryRating < 4;
                              if (requireComment && comment.isEmpty) {
                                setState(() {
                                  _commentError =
                                      'tracking.lowRatingNeedsComment'.tr;
                                });
                                return;
                              }
                              try {
                                await widget.controller.submitRating(
                                  vendorRating: _vendorRating,
                                  deliveryRating: _deliveryRating,
                                  comment: comment.isEmpty ? null : comment,
                                );
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                Get.offAll(
                                  () => HomeScreen(token: widget.controller.token),
                                );
                                AppSnackbar.show(
                                  'tracking.thanks'.tr,
                                  'tracking.ratingSent'.tr,
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFFE9F9EE),
                                  colorText: const Color(0xFF0F5132),
                                );
                              } catch (e) {
                                AppSnackbar.show(
                                  'tracking.sendFailed'.tr,
                                  e.toString(),
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFFFFF1F2),
                                  colorText: const Color(0xFFE11D48),
                                );
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: widget.controller.isSubmittingRating.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'tracking.submitRating'.tr,
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingStars extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RatingStars({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final star = index + 1;
        return IconButton(
          onPressed: () => onChanged(star),
          icon: Icon(
            value >= star ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFFF9800),
            size: 28,
          ),
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(minWidth: 34),
        );
      }),
    );
  }
}

class _TopLiveCard extends StatelessWidget {
  final String orderNumber;
  final bool connected;

  const _TopLiveCard({required this.orderNumber, required this.connected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'tracking.orderNumber'.tr,
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  orderNumber,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: connected
                    ? const Color(0xFFE9F9EE)
                    : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                connected
                    ? 'tracking.liveConnected'.tr
                    : 'tracking.liveDisconnected'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: connected
                      ? const Color(0xFF0F9D58)
                      : const Color(0xFFE11D48),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;

  const _StatusCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final String status;
  final String dispatchStatus;

  const _TimelineCard({required this.status, required this.dispatchStatus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stages = const [
      'food_accepted',
      'food_preparing',
      'food_driver_assigned',
      'food_on_way',
      'food_delivered',
    ];
    final currentIndex = _foodTimelineIndex(
      status: status,
      dispatchStatus: dispatchStatus,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'tracking.orderStages'.tr,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...stages.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final done = currentIndex >= i;
            final current = currentIndex == i;
            return _TimelineStepTile(
              label: _statusLabel(s),
              icon: _foodStageIcon(s),
              isDone: done,
              isCurrent: current,
              isLast: i == stages.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineStepTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStepTile({
    required this.label,
    required this.icon,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = isDone ? AppColors.primary : cs.outlineVariant;
    final textColor = isDone ? cs.onSurface : cs.onSurfaceVariant;

    return SizedBox(
      height: 64,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: isCurrent ? 28 : 26,
                  height: isCurrent ? 28 : 26,
                  decoration: BoxDecoration(
                    color: isDone
                        ? Color.alphaBlend(
                            AppColors.primary.withValues(alpha: 0.2),
                            cs.surface,
                          )
                        : cs.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? AppColors.primary : cs.outlineVariant,
                      width: isCurrent ? 1.8 : 1.1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: isCurrent ? 14 : 13,
                    color: isDone ? AppColors.primary : cs.onSurfaceVariant,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 4),
                      color: activeColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Color.alphaBlend(
                          AppColors.primary.withValues(alpha: 0.12),
                          cs.surfaceContainerHigh,
                        )
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'food_accepted':
      return 'tracking.foodAccepted'.tr;
    case 'food_preparing':
      return 'tracking.foodPreparing'.tr;
    case 'food_driver_assigned':
      return 'tracking.foodDriverAssigned'.tr;
    case 'food_on_way':
      return 'tracking.foodOnWay'.tr;
    case 'food_delivered':
      return 'tracking.foodDelivered'.tr;
    case 'pending':
      return 'tracking.pending'.tr;
    case 'accepted':
      return 'tracking.accepted'.tr;
    case 'preparing':
      return 'tracking.preparing'.tr;
    case 'ready':
      return 'tracking.ready'.tr;
    case 'picked_up':
      return 'tracking.pickedUp'.tr;
    case 'on_way':
      return 'tracking.onWay'.tr;
    case 'delivered':
      return 'tracking.delivered'.tr;
    case 'cancelled':
      return 'tracking.cancelled'.tr;
    default:
      return status;
  }
}

int _foodTimelineIndex({
  required String status,
  required String dispatchStatus,
}) {
  final s = status.trim().toLowerCase();
  final d = dispatchStatus.trim().toLowerCase();

  if (s == 'delivered') return 4;
  if (s == 'on_way') return 3;
  if (d == 'assigned' || s == 'ready' || s == 'picked_up') return 2;
  if (s == 'preparing') return 1;
  if (s == 'accepted' || d == 'accepted' || s == 'pending') return 0;
  return 0;
}

IconData _foodStageIcon(String stage) {
  switch (stage) {
    case 'food_accepted':
      return Icons.done_all_rounded;
    case 'food_preparing':
      return Icons.local_dining_rounded;
    case 'food_driver_assigned':
      return Icons.moped_rounded;
    case 'food_on_way':
      return Icons.alt_route_rounded;
    case 'food_delivered':
      return Icons.done_all_rounded;
    default:
      return Icons.radio_button_checked_rounded;
  }
}

String _dispatchLabel(String status) {
  switch (status) {
    case 'dispatching':
      return 'tracking.dispatching'.tr;
    case 'accepted':
      return 'tracking.driverAccepted'.tr;
    case 'on_way':
      return 'tracking.driverOnWay'.tr;
    case 'delivered':
      return 'tracking.handoverDelivered'.tr;
    default:
      return status.isEmpty ? '-' : status;
  }
}
