import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/peak_hour/controllers/peak_hour_controller.dart';

class PeakHourPriceNotice extends StatefulWidget {
  const PeakHourPriceNotice({
    super.key,
    required this.visible,
    this.padding,
  });

  final bool visible;
  final EdgeInsetsGeometry? padding;

  @override
  State<PeakHourPriceNotice> createState() => _PeakHourPriceNoticeState();
}

class _PeakHourPriceNoticeState extends State<PeakHourPriceNotice> {
  @override
  void initState() {
    super.initState();
    _refreshIfNeeded();
  }

  @override
  void didUpdateWidget(PeakHourPriceNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _refreshIfNeeded();
    }
  }

  void _refreshIfNeeded() {
    if (!widget.visible || !Get.isRegistered<PeakHourController>()) {
      return;
    }
    unawaited(Get.find<PeakHourController>().ensureFreshStatus());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || !Get.isRegistered<PeakHourController>()) {
      return const SizedBox.shrink();
    }

    final controller = Get.find<PeakHourController>();

    return Obx(() {
      final isActive = controller.status.value?.isPeakHourActive == true;
      if (!isActive) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: widget.padding ?? EdgeInsets.zero,
        child: Text(
          'peakHour.priceNotice'.tr,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      );
    });
  }
}
