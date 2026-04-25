import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F8),
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تتبع الطلب',
          style: TextStyle(fontWeight: FontWeight.w800),
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
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  _StatusCard(
                    title: 'حالة الطلب',
                    value: _statusLabel(controller.currentStatus.value),
                  ),
                  const SizedBox(height: 10),
                  _StatusCard(
                    title: 'حالة الإرسال',
                    value: _dispatchLabel(controller.currentDispatchStatus.value),
                  ),
                  const SizedBox(height: 14),
                  _TimelineCard(status: controller.currentStatus.value),
                ],
              ),
            ),
            _DeliveredRatingListener(controller: controller),
          ],
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
            label: const Text(
              'تقييم الطلب',
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
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'تم إنهاء الطلب',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: const Text(
        'هل تريد تقييم الطلب الآن؟',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            controller.postponeRating();
          },
          child: const Text('لاحقًا'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _showRatingDialog(context, controller, iconAnimation);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('نعم، الآن'),
        ),
      ],
    ),
  );
}

Future<void> _showRatingDialog(
  BuildContext context,
  OrderTrackingController controller,
  Animation<double> iconAnimation,
) async {
  await showDialog<void>(
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
    return Dialog(
      backgroundColor: Colors.white,
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
                        color: const Color(0xFFE9F9EE),
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
                const Center(
                  child: Text(
                    'تم التوصيل بنجاح',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'قيّم طلبك لمساعدتنا على تحسين الخدمة',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'تقييم المطعم',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                _RatingStars(
                  value: _vendorRating,
                  onChanged: (v) => setState(() => _vendorRating = v),
                ),
                const SizedBox(height: 10),
                const Text(
                  'تقييم التوصيل',
                  style: TextStyle(fontWeight: FontWeight.w700),
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
                    hintText: 'ملاحظاتك (اختياري)',
                    errorText: _commentError,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8ECF2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE8ECF2)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: widget.controller.isSubmittingRating.value
                          ? null
                          : () async {
                              final comment = _commentController.text.trim();
                              final requireComment =
                                  _vendorRating < 4 || _deliveryRating < 4;
                              if (requireComment && comment.isEmpty) {
                                setState(() {
                                  _commentError =
                                      'يرجى كتابة ملاحظة عند تقييم أقل من 4 نجوم';
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
                                Get.snackbar(
                                  'شكرا لك',
                                  'تم إرسال تقييمك بنجاح',
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFFE9F9EE),
                                  colorText: const Color(0xFF0F5132),
                                );
                              } catch (e) {
                                Get.snackbar(
                                  'فشل الإرسال',
                                  e.toString(),
                                  snackPosition: SnackPosition.BOTTOM,
                                  backgroundColor: const Color(0xFFFFF1F2),
                                  colorText: const Color(0xFFE11D48),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
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
                          : const Text(
                              'إرسال التقييم',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF2)),
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
              color: const Color(0xFFFFF3E8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'رقم الطلب',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  orderNumber,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFFE9F9EE)
                  : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              connected ? 'متصل لحظيا' : 'غير متصل',
              style: TextStyle(
                color: connected
                    ? const Color(0xFF0F9D58)
                    : const Color(0xFFE11D48),
                fontSize: 11,
                fontWeight: FontWeight.w800,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
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

  const _TimelineCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final statuses = [
      'pending',
      'accepted',
      'preparing',
      'ready',
      'picked_up',
      'on_way',
      'delivered',
    ];
    final currentIndex = statuses.indexOf(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF2)),
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
          const Row(
            children: [
              Icon(Icons.route_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'مراحل الطلب',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...statuses.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final done = currentIndex >= i;
            final current = currentIndex == i;
            return _TimelineStepTile(
              label: _statusLabel(s),
              isDone: done,
              isCurrent: current,
              isLast: i == statuses.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineStepTile extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  const _TimelineStepTile({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDone ? AppColors.primary : const Color(0xFFCBD5E1);
    final textColor = isDone ? AppColors.textPrimary : AppColors.textSecondary;

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
                  width: isCurrent ? 14 : 12,
                  height: isCurrent ? 14 : 12,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? const Color(0xFFFFD7B0) : activeColor,
                      width: isCurrent ? 3 : 0,
                    ),
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
                  color: isCurrent ? const Color(0xFFFFF7EE) : const Color(0xFFF8FAFC),
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
    case 'pending':
      return 'قيد الانتظار';
    case 'accepted':
      return 'مقبول';
    case 'preparing':
      return 'قيد التحضير';
    case 'ready':
      return 'جاهز للاستلام';
    case 'picked_up':
      return 'تم الاستلام';
    case 'on_way':
      return 'في الطريق';
    case 'delivered':
      return 'تم التوصيل';
    case 'cancelled':
      return 'ملغي';
    default:
      return status;
  }
}

String _dispatchLabel(String status) {
  switch (status) {
    case 'dispatching':
      return 'جاري التعيين';
    case 'accepted':
      return 'تم قبول السائق';
    case 'on_way':
      return 'السائق بالطريق';
    case 'delivered':
      return 'تم التسليم';
    default:
      return status.isEmpty ? '-' : status;
  }
}
