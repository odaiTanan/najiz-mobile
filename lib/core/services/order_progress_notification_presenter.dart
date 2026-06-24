import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_strings.dart';
import 'package:najiz_go_express/core/services/order_notification_cache_writer.dart';
import 'package:najiz_go_express/core/services/order_notification_stepper.dart';
import 'package:najiz_go_express/core/services/order_progress_notification_mapper.dart';
import 'package:najiz_go_express/core/services/taxi_order_state.dart';

class OrderProgressNotificationPresenter {
  OrderProgressNotificationPresenter({
    required FlutterLocalNotificationsPlugin plugin,
    required String channelId,
    required int Function(String key) stableInt,
  })  : _plugin = plugin,
        _channelId = channelId,
        _stableInt = stableInt;

  final FlutterLocalNotificationsPlugin _plugin;
  final String _channelId;
  final int Function(String key) _stableInt;

  Future<void> showOrUpdate(
    Map<String, dynamic> data, {
    String? titleOverride,
    String? bodyOverride,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (TaxiOrderState.shouldIgnorePayload(data, bodyOverride: bodyOverride)) {
      return;
    }

    final snapshot = OrderProgressNotificationMapper.fromPayload(
      data,
      defaultAppTitle: AppStrings.appName,
      titleOverride: titleOverride,
      bodyOverride: bodyOverride,
      stableInt: _stableInt,
    );
    if (snapshot.orderId <= 0) return;
    if (TaxiOrderState.isTaxiOrderType(snapshot.orderType) &&
        snapshot.body.trim().isEmpty) {
      return;
    }

    final stepperPng = await renderOrderStepperPng(
      labels: snapshot.labels,
      activeIndex: snapshot.stepIndex,
      allComplete: snapshot.isFinished,
      orderType: snapshot.orderType,
      isStore: snapshot.isStore,
    );

    await OrderNotificationCacheWriter.write(
      orderId: snapshot.orderId,
      stepperPng: stepperPng,
      stepIndex: snapshot.stepIndex,
      stepTotal: snapshot.stepTotal,
      isFinished: snapshot.isFinished,
      title: snapshot.title,
      body: snapshot.body,
    );

    final styleInformation = _buildStyle(
      title: snapshot.title,
      body: snapshot.body,
      stepperPng: stepperPng,
    );

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'notifications.trackOrders'.tr,
        channelDescription: 'notifications.orderStatusProgress'.tr,
        icon: '@drawable/ic_launcher_foreground',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: const Color(0xFFFF9800),
        importance: Importance.low,
        priority: Priority.low,
        showProgress: !snapshot.isFinished,
        maxProgress: snapshot.stepTotal,
        progress: snapshot.isFinished
            ? snapshot.stepTotal
            : (snapshot.stepIndex + 1).clamp(1, snapshot.stepTotal),
        groupKey: snapshot.groupKey,
        setAsGroupSummary: false,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        enableLights: false,
        ongoing: !snapshot.isFinished,
        autoCancel: snapshot.isFinished,
        styleInformation: styleInformation,
        ticker: snapshot.body,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.progress,
      ),
    );

    await _plugin.show(
      snapshot.notificationId,
      snapshot.title,
      snapshot.body,
      details,
    );
  }

  StyleInformation _buildStyle({
    required String title,
    required String body,
    required Uint8List? stepperPng,
  }) {
    if (stepperPng != null && stepperPng.isNotEmpty) {
      return BigPictureStyleInformation(
        ByteArrayAndroidBitmap(stepperPng),
        contentTitle: body,
        summaryText: title,
        hideExpandedLargeIcon: true,
      );
    }
    return BigTextStyleInformation(
      body,
      contentTitle: title,
    );
  }
}
