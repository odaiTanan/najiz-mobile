import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:najiz_go_express/core/services/order_notification_stepper.dart';
import 'package:najiz_go_express/features/home/models/app_notification_item.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService extends GetxService {
  static const String _oneSignalAppId = '9281c288-37c8-4a61-8a13-72feafc8b32a';
  static const String _storageKey = 'app_notifications_history';
  static const String _orderNotificationIdsKey = 'order_progress_notification_ids';
  static const String _chatNotificationIdsKey = 'chat_progress_notification_ids';
  /// v2: channel recreated so importance/playSound apply (Android locks first creation).
  static const String _ordersChannelId = 'orders_progress_channel_v2';
  static const String _chatChannelId = 'chat_updates_channel';

  final _http = http.Client();
  final Map<String, DateTime> _recentLocalKeys = <String, DateTime>{};
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, int> _orderNotificationIds = <String, int>{};
  final Map<String, int> _chatNotificationIds = <String, int>{};

  final notifications = <AppNotificationItem>[].obs;
  final unreadCount = 0.obs;
  bool _initialized = false;
  bool _localInitialized = false;

  Future<void> initialize({String? token}) async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromStorage();
    await _loadNotificationIdMappings();
    await _initLocalNotifications();
    OneSignal.initialize(_oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final notification = event.notification;
      final merged = mergeOneSignalNotificationData(notification);
      final type = merged['type']?.toString().trim().toLowerCase();

      // One notification in the tray: we draw progress locally; suppress OS duplicate.
      if (type == 'order_status') {
        event.preventDefault();
        unawaited(_handleOrderStatusForeground(notification, merged));
        return;
      }

      _handleLocalProgressNotification(merged);
      _handleOrderStatusMilestones(merged);
      _appendNotification(
        title: notification.title ?? 'إشعار جديد',
        body: notification.body ?? '',
        externalId: notification.notificationId,
        data: merged,
      );
    });

    OneSignal.Notifications.addClickListener((event) {
      final notification = event.notification;
      final merged = mergeOneSignalNotificationData(notification);
      _handleLocalProgressNotification(merged);
      _handleOrderStatusMilestones(merged);
      final type = merged['type']?.toString().trim().toLowerCase();
      final inAppId = type == 'order_status'
          ? _orderStatusInAppId(merged)
          : notification.notificationId;
      _appendNotification(
        title: notification.title ?? 'إشعار جديد',
        body: notification.body ?? '',
        externalId: inAppId,
        data: merged,
      );
    });

    if (token != null && token.trim().isNotEmpty) {
      await subscribeDevice(token);
    }
  }

  Future<void> _initLocalNotifications() async {
    if (_localInitialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _ordersChannelId,
          'تتبع الطلبات',
          description: 'تحديث حالة الطلب مع شريط التقدم',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: true,
        ),
      );
    }

    _localInitialized = true;
  }

  Future<void> _loadNotificationIdMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final ordersRaw = prefs.getString(_orderNotificationIdsKey);
    if (ordersRaw != null && ordersRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(ordersRaw);
        if (decoded is Map) {
          _orderNotificationIds
            ..clear()
            ..addAll(
              decoded.map((key, value) => MapEntry(
                    key.toString(),
                    int.tryParse(value.toString()) ?? _stableInt(key.toString()),
                  )),
            );
        }
      } catch (_) {}
    }

    final chatsRaw = prefs.getString(_chatNotificationIdsKey);
    if (chatsRaw != null && chatsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(chatsRaw);
        if (decoded is Map) {
          _chatNotificationIds
            ..clear()
            ..addAll(
              decoded.map((key, value) => MapEntry(
                    key.toString(),
                    int.tryParse(value.toString()) ?? _stableInt(key.toString()),
                  )),
            );
        }
      } catch (_) {}
    }
  }

  Future<void> _saveNotificationIdMappings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _orderNotificationIdsKey,
      jsonEncode(_orderNotificationIds),
    );
    await prefs.setString(
      _chatNotificationIdsKey,
      jsonEncode(_chatNotificationIds),
    );
  }

  Future<void> _handleLocalProgressNotification(Map<String, dynamic>? data) async {
    if (data == null || !_localInitialized) return;
    final type = data['type']?.toString().trim().toLowerCase();
    if (type == 'order_status') {
      await _upsertOrderProgressNotification(data);
      return;
    }
    if (type == 'chat') {
      await _upsertChatNotification(data);
    }
  }

  Future<void> _handleOrderStatusForeground(
    OSNotification notification,
    Map<String, dynamic> merged,
  ) async {
    await _upsertOrderProgressNotification(
      merged,
      titleOverride: notification.title,
      bodyOverride: notification.body,
    );
    _handleOrderStatusMilestones(merged);
    await _appendNotification(
      title: notification.title ?? 'إشعار جديد',
      body: notification.body ?? '',
      externalId: _orderStatusInAppId(merged),
      data: merged,
    );
  }

  String _orderStatusInAppId(Map<String, dynamic>? data) {
    if (data == null) return 'order_status_unknown';
    final oid = data['order_id']?.toString().trim() ?? '';
    final st = _normalizeStatus(
      data['status']?.toString() ?? data['order_status']?.toString() ?? '',
    );
    if (oid.isEmpty) return 'order_status_$st';
    return 'order_status_${oid}_$st';
  }

  Future<void> _upsertOrderProgressNotification(
    Map<String, dynamic> data, {
    String? titleOverride,
    String? bodyOverride,
  }) async {
    final rawOrderId = data['order_id'];
    final orderId = rawOrderId?.toString().trim();
    if (orderId == null || orderId.isEmpty || orderId == 'null') return;

    final collapseId = data['collapse_id']?.toString().trim();
    final orderKey =
        collapseId != null && collapseId.isNotEmpty
            ? collapseId
            : data['notification_key']?.toString().trim().isNotEmpty == true
            ? data['notification_key']!.toString().trim()
            : 'order_$orderId';
    final androidGroup = data['android_group']?.toString().trim();
    final groupKey = androidGroup != null && androidGroup.isNotEmpty
        ? androidGroup
        : 'order_$orderId';
    final explicitNotificationId =
        _asInt(data['android_notification_id']) ?? _asInt(data['order_id']);
    final notificationId = _safeAndroidNotifyId(
      explicitNotificationId ??
          _resolveNotificationId(
            key: orderKey,
            store: _orderNotificationIds,
          ),
    );
    if (explicitNotificationId == null) {
      await _saveNotificationIdMappings();
    }

    final orderType = (data['order_type'] ?? data['service_type'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final resolvedStepTotal =
        _asInt(data['step_total']) ?? defaultStepTotalForOrderType(orderType);
    final effectiveStatus = _effectiveStatusForProgress(data);
    final serviceName = data['service_name']?.toString().trim().toLowerCase();
    final resolvedStepIndex = _asInt(data['step_index']) ??
        _statusToStepIndex(
          effectiveStatus,
          resolvedStepTotal,
          orderType: orderType,
          serviceName: serviceName,
        );

    final int clampedTotal = resolvedStepTotal <= 0
        ? defaultStepTotalForOrderType(orderType)
        : resolvedStepTotal;
    final int clampedStep =
        resolvedStepIndex.clamp(0, clampedTotal).toInt();
    final orderNumber = data['order_number']?.toString().trim();
    final statusText = data['status_label']?.toString().trim().isNotEmpty == true
        ? data['status_label'].toString().trim()
        : _defaultStatusLabel(effectiveStatus);
    final title = (titleOverride != null && titleOverride.trim().isNotEmpty)
        ? titleOverride.trim()
        : (orderNumber != null && orderNumber.isNotEmpty
            ? 'طلبك $orderNumber'
            : 'تحديث حالة الطلب');
    final bodyFromRemote =
        bodyOverride != null && bodyOverride.trim().isNotEmpty
            ? bodyOverride.trim()
            : null;
    final body = bodyFromRemote ??
        '$statusText ($clampedStep/$clampedTotal)';
    final isFinished = _isTerminalOrderStatus(effectiveStatus);

    DefaultStyleInformation styleInfo = BigTextStyleInformation(body);
    var useStepperBitmap = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final labels = stepperLabelsForOrderType(orderType);
      final n = clampedTotal.clamp(1, labels.length).toInt();
      final subLabels = labels.sublist(0, n);
      final maxActive = subLabels.length - 1;
      final activeDraw =
          isFinished ? maxActive : clampedStep.clamp(0, maxActive).toInt();
      final bytes = await renderOrderStepperPng(
        labels: subLabels,
        activeIndex: activeDraw,
        allComplete: isFinished,
        orderType: orderType,
        isStore: serviceName == 'store',
      );
      if (bytes != null && bytes.isNotEmpty) {
        styleInfo = BigPictureStyleInformation(
          ByteArrayAndroidBitmap(bytes),
          summaryText: body,
          hideExpandedLargeIcon: true,
        );
        useStepperBitmap = true;
      }
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _ordersChannelId,
        'تتبع الطلبات',
        channelDescription: 'تحديث حالة الطلب مع شريط التقدم',
        color: const Color(0xFFFF8A00),
        importance: Importance.low,
        priority: Priority.low,
        showProgress: !isFinished && !useStepperBitmap,
        maxProgress: clampedTotal,
        progress: isFinished ? clampedTotal : clampedStep,
        groupKey: groupKey,
        onlyAlertOnce: true,
        playSound: true,
        enableVibration: true,
        enableLights: false,
        ongoing: !isFinished,
        autoCancel: isFinished,
        styleInformation: styleInfo,
      ),
    );
    await _localNotifications.show(notificationId, title, body, details);
  }

  int _safeAndroidNotifyId(int id) {
    if (id == 0) return _stableInt('order_notify_zero');
    return id & 0x7fffffff;
  }

  Future<void> _upsertChatNotification(Map<String, dynamic> data) async {
    final conversationId = data['conversation_id']?.toString().trim();
    if (conversationId == null || conversationId.isEmpty) return;
    final key = 'chat_$conversationId';
    final notificationId = _resolveNotificationId(
      key: key,
      store: _chatNotificationIds,
    );
    await _saveNotificationIdMappings();

    final sender = data['sender_name']?.toString().trim();
    final message = data['message']?.toString().trim();
    final title = (sender != null && sender.isNotEmpty)
        ? 'رسالة جديدة من $sender'
        : 'رسالة جديدة';
    final body = (message != null && message.isNotEmpty)
        ? message
        : 'لديك رسالة جديدة في المحادثة';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _chatChannelId,
        'Chat Updates',
        channelDescription: 'Chat updates by conversation',
        importance: Importance.high,
        priority: Priority.high,
        onlyAlertOnce: true,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
    await _localNotifications.show(notificationId, title, body, details);
  }

  int _resolveNotificationId({
    required String key,
    required Map<String, int> store,
  }) {
    final existing = store[key];
    if (existing != null) return existing;
    final generated = _stableInt(key);
    store[key] = generated;
    return generated;
  }

  int _stableInt(String input) {
    var hash = 0;
    for (final code in input.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    if (hash == 0) return 1;
    return hash;
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static const Set<String> _arrivalProgressStatuses = {
    'arrived',
    'waiting',
    'arrived_waiting',
    'driver_arrived',
    'at_destination',
    'at_pickup',
    'waiting_at_destination',
    'waiting_at_pickup',
  };

  String _effectiveStatusForProgress(Map<String, dynamic> data) {
    final main = _normalizeStatus(
      data['status']?.toString() ?? data['order_status']?.toString() ?? '',
    );
    final dispatch = _normalizeStatus(
      data['dispatch_status']?.toString() ??
          data['driver_status']?.toString() ??
          '',
    );
    if (_arrivalProgressStatuses.contains(main)) return main;
    if (_arrivalProgressStatuses.contains(dispatch)) return dispatch;
    if (main.isNotEmpty) return main;
    return dispatch;
  }

  int _statusToStepIndex(
    String status,
    int stepTotal, {
    String orderType = '',
    String? serviceName,
  }) {
    final max = stepTotal <= 0 ? 5 : stepTotal;
    final isStore = serviceName == 'store';
    final type = orderType == 'shipping'
        ? 'shipping'
        : orderType == 'taxi'
            ? 'taxi'
            : 'food';

    int mapFood(String s) {
      switch (s) {
        case 'pending':
        case 'no_driver':
          return 0;
        case 'accepted':
          return 1;
        case 'preparing':
        case 'ready':
          return 2;
        case 'on_the_way_to_pickup':
          return isStore ? 2 : 3;
        case 'picked_up':
          return 3;
        case 'on_way':
          return max > 4 ? 4 : (max - 1).clamp(1, max);
        case 'arrived':
        case 'waiting':
        case 'arrived_waiting':
        case 'driver_arrived':
        case 'at_destination':
        case 'at_pickup':
        case 'waiting_at_destination':
        case 'waiting_at_pickup':
          return max > 4 ? 4 : (max - 1).clamp(1, max);
        case 'delivered':
        case 'completed':
        case 'cancelled':
        case 'canceled':
          return max;
        default:
          return 1;
      }
    }

    int mapShipping(String s) {
      switch (s) {
        case 'pending':
        case 'no_driver':
          return 0;
        case 'accepted':
          return 1;
        case 'preparing':
          return 1;
        case 'on_the_way_to_pickup':
          return 2;
        case 'picked_up':
          return 3;
        case 'on_way':
          return 4;
        case 'arrived':
        case 'waiting':
        case 'arrived_waiting':
        case 'driver_arrived':
        case 'at_destination':
        case 'at_pickup':
        case 'waiting_at_destination':
        case 'waiting_at_pickup':
          return 4;
        case 'delivered':
        case 'completed':
        case 'cancelled':
        case 'canceled':
          return max;
        default:
          return 1;
      }
    }

    int mapTaxi(String s) {
      switch (s) {
        case 'pending':
        case 'no_driver':
          return 0;
        case 'accepted':
          return 1;
        case 'preparing':
          return 2;
        case 'on_the_way_to_pickup':
        case 'on_way':
          return 2;
        case 'picked_up':
          return 3;
        case 'arrived':
        case 'waiting':
        case 'arrived_waiting':
        case 'driver_arrived':
        case 'at_destination':
        case 'at_pickup':
        case 'waiting_at_destination':
        case 'waiting_at_pickup':
          return 3;
        case 'delivered':
        case 'completed':
        case 'cancelled':
        case 'canceled':
          return max;
        default:
          return 1;
      }
    }

    switch (type) {
      case 'shipping':
        return mapShipping(status).clamp(0, max);
      case 'taxi':
        return mapTaxi(status).clamp(0, max);
      default:
        return mapFood(status).clamp(0, max);
    }
  }

  String _defaultStatusLabel(String statusRaw) {
    final status = _normalizeStatus(statusRaw);
    switch (status) {
      case 'pending':
        return 'بانتظار القبول';
      case 'accepted':
        return 'تم قبول الطلب';
      case 'on_the_way_to_pickup':
        return 'السائق متجه للاستلام';
      case 'picked_up':
        return 'تم الاستلام';
      case 'on_way':
        return 'في الطريق للتسليم';
      case 'preparing':
        return 'قيد التحضير';
      case 'ready':
        return 'طلبك جاهز';
      case 'arrived':
      case 'waiting':
      case 'arrived_waiting':
      case 'driver_arrived':
      case 'at_destination':
      case 'at_pickup':
      case 'waiting_at_destination':
      case 'waiting_at_pickup':
        return 'السائق وصل وهو في الانتظار';
      case 'no_driver':
        return 'لا يوجد سائق متاح حالياً';
      case 'delivered':
      case 'completed':
        return 'تم التسليم';
      case 'cancelled':
      case 'canceled':
        return 'تم إلغاء الطلب';
      default:
        return 'تحديث جديد على الطلب';
    }
  }

  bool _isTerminalOrderStatus(String statusRaw) {
    final status = _normalizeStatus(statusRaw);
    return status == 'delivered' ||
        status == 'completed' ||
        status == 'cancelled' ||
        status == 'canceled';
  }

  Future<void> _handleOrderStatusMilestones(Map<String, dynamic>? data) async {
    if (data == null) return;
    final type = data['type']?.toString().trim().toLowerCase();
    if (type != 'order_status') return;

    final orderId = data['order_id']?.toString();
    if (orderId == null || orderId.trim().isEmpty) return;

    final status = _normalizeStatus(
      data['status']?.toString() ?? data['order_status']?.toString() ?? '',
    );
    final dispatchStatus = _normalizeStatus(
      data['dispatch_status']?.toString() ??
          data['driver_status']?.toString() ??
          '',
    );
    final isNearAddress = _nearAddressStatuses.contains(status) ||
        _nearAddressStatuses.contains(dispatchStatus);
    final isArrivedWaiting = _arrivedWaitingStatuses.contains(status) ||
        _arrivedWaitingStatuses.contains(dispatchStatus);

    if (isNearAddress) {
      await pushLocalInAppNotification(
        title: 'تنبيه التوصيل',
        body: 'السائق أصبح على مقربة من عنوانك',
        dedupeKey: 'onesignal-order-$orderId-near-address',
        data: {
          ...data,
          'event': 'driver_near_address',
        },
      );
    }

    if (isArrivedWaiting) {
      await pushLocalInAppNotification(
        title: 'تنبيه التوصيل',
        body: 'السائق وصل وهو في الانتظار',
        dedupeKey: 'onesignal-order-$orderId-arrived-waiting',
        data: {
          ...data,
          'event': 'driver_arrived_waiting',
        },
      );
    }
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  static const Set<String> _nearAddressStatuses = {
    'on_way',
    'near_destination',
    'nearby',
    'approaching_destination',
    'driver_near',
  };

  static const Set<String> _arrivedWaitingStatuses = {
    'arrived',
    'waiting',
    'arrived_waiting',
    'driver_arrived',
    'at_destination',
    'at_pickup',
    'waiting_at_destination',
    'waiting_at_pickup',
  };

  Future<void> subscribeDevice(String userToken) async {
    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId == null || playerId.trim().isEmpty) return;

    final uri = Uri.parse('${ApiConfig.baseUrl}/onesignal/subscribe');
    try {
      await _http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $userToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'player_id': playerId}),
          )
          .timeout(ApiConfig.timeout);
    } catch (_) {
      // Keep app flow intact even if notification subscription fails.
    }
  }

  Future<void> unsubscribeDevice(String userToken) async {
    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId == null || playerId.trim().isEmpty) return;

    final uri = Uri.parse('${ApiConfig.baseUrl}/onesignal/unsubscribe');
    try {
      await _http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $userToken',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'player_id': playerId}),
          )
          .timeout(ApiConfig.timeout);
    } catch (_) {
      // Keep app flow intact even if notification unsubscription fails.
    }
  }

  Future<void> markAllRead() async {
    final updated = notifications
        .map((item) => item.copyWith(isRead: true))
        .toList(growable: false);
    notifications.assignAll(updated);
    _recalculateUnread();
    await _saveToStorage();
  }

  Future<void> markAsRead(String id) async {
    final index = notifications.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final target = notifications[index];
    if (target.isRead) return;
    notifications[index] = target.copyWith(isRead: true);
    _recalculateUnread();
    await _saveToStorage();
  }

  Future<void> pushLocalInAppNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? dedupeKey,
    Duration dedupeWindow = const Duration(minutes: 20),
    bool showSnack = true,
  }) async {
    final key = dedupeKey?.trim();
    if (key != null && key.isNotEmpty) {
      final now = DateTime.now();
      final previous = _recentLocalKeys[key];
      if (previous != null && now.difference(previous) < dedupeWindow) {
        return;
      }
      _recentLocalKeys[key] = now;
    }

    await _appendNotification(
      title: title,
      body: body,
      externalId:
          'local-${DateTime.now().microsecondsSinceEpoch}-${key ?? 'event'}',
      data: data,
    );

    if (showSnack) {
      AppSnackbar.show(
        title,
        body,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );
    }
  }

  Future<void> _appendNotification({
    required String title,
    required String body,
    String? externalId,
    Map<String, dynamic>? data,
  }) async {
    final id = (externalId != null && externalId.trim().isNotEmpty)
        ? externalId
        : DateTime.now().microsecondsSinceEpoch.toString();

    final alreadyExists = notifications.any((item) => item.id == id);
    if (alreadyExists) return;

    final item = AppNotificationItem(
      id: id,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      data: data ?? const <String, dynamic>{},
      isRead: false,
    );
    notifications.insert(0, item);
    _recalculateUnread();
    await _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      notifications.clear();
      _recalculateUnread();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        notifications.clear();
        _recalculateUnread();
        return;
      }
      final loaded = decoded
          .whereType<Map>()
          .map(
            (e) => AppNotificationItem.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
      notifications.assignAll(loaded);
    } catch (_) {
      notifications.clear();
    }
    _recalculateUnread();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      notifications.map((item) => item.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey, payload);
  }

  void _recalculateUnread() {
    unreadCount.value = notifications.where((n) => !n.isRead).length;
  }
}
