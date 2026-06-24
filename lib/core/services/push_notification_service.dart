import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_strings.dart';
import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/core/services/order_notification_stepper.dart';
import 'package:najiz_go_express/core/services/order_progress_notification_mapper.dart';
import 'package:najiz_go_express/core/services/order_progress_notification_presenter.dart';
import 'package:najiz_go_express/core/services/order_status_native_bridge.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/taxi_order_state.dart';
import 'package:najiz_go_express/features/notifications/models/app_notification_item.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService extends GetxService {
  static const String _oneSignalAppId = '9281c288-37c8-4a61-8a13-72feafc8b32a';
  static const String _storageKey = 'app_notifications_history';
  static const String _orderNotificationIdsKey = 'order_progress_notification_ids';
  static const String _chatNotificationIdsKey = 'chat_progress_notification_ids';
  static const String _ordersChannelId = 'orders_progress_channel';
  static const String _chatChannelId = 'chat_updates_channel';

  ApiClient get _api => resolveApiClient();
  final Map<String, DateTime> _recentLocalKeys = <String, DateTime>{};
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, int> _orderNotificationIds = <String, int>{};
  final Map<String, int> _chatNotificationIds = <String, int>{};
  OrderProgressNotificationPresenter? _orderProgressPresenter;

  final notifications = <AppNotificationItem>[].obs;
  final unreadCount = 0.obs;
  bool _initialized = false;
  bool _localInitialized = false;
  String? _pendingSubscribeToken;

  Future<void> initialize({String? token}) async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromStorage();
    await _loadNotificationIdMappings();
    await _initLocalNotifications();
    OneSignal.initialize(_oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    OneSignal.User.pushSubscription.addObserver((state) {
      final playerId = state.current.id;
      if (playerId == null || playerId.trim().isEmpty) return;
      final authToken = _pendingSubscribeToken ??
          (Get.isRegistered<AuthStateManager>()
              ? Get.find<AuthStateManager>().token.value
              : null);
      if (authToken == null || authToken.trim().isEmpty) return;
      unawaited(subscribeDevice(authToken));
    });

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final notification = event.notification;
      final merged = mergeOneSignalNotificationData(notification);
      final type = merged['type']?.toString().trim().toLowerCase();

      if (type == 'order_status') {
        event.preventDefault();
        unawaited(
          _handleOrderStatusPayload(
            merged,
            title: notification.title,
            body: notification.body,
          ),
        );
        return;
      }

      _handleLocalProgressNotification(merged);
      _handleOrderStatusMilestones(merged);
      _appendNotification(
        title: notification.title ?? 'notifications.newNotification'.tr,
        body: notification.body ?? '',
        externalId: notification.notificationId,
        data: merged,
      );
    });

    OneSignal.Notifications.addClickListener((event) {
      final notification = event.notification;
      final merged = mergeOneSignalNotificationData(notification);
      final type = merged['type']?.toString().trim().toLowerCase();

      if (type == 'order_status') {
        unawaited(
          _handleOrderStatusPayload(
            merged,
            title: notification.title,
            body: notification.body,
          ),
        );
        return;
      }

      _handleLocalProgressNotification(merged);
      _handleOrderStatusMilestones(merged);
      _appendNotification(
        title: notification.title ?? 'notifications.newNotification'.tr,
        body: notification.body ?? '',
        externalId: notification.notificationId,
        data: merged,
      );
    });

    OrderStatusNativeBridge.register((payload, {title, body}) async {
      await _handleOrderStatusPayload(
        payload,
        title: title,
        body: body,
      );
    });

    if (token != null && token.trim().isNotEmpty) {
      _pendingSubscribeToken = token.trim();
      await subscribeDevice(token);
    }
  }

  Future<void> _initLocalNotifications() async {
    if (_localInitialized) return;
    const android = AndroidInitializationSettings(
      '@drawable/ic_launcher_foreground',
    );
    const settings = InitializationSettings(android: android);
    await _localNotifications.initialize(settings);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        AndroidNotificationChannel(
          _ordersChannelId,
          'notifications.trackOrders'.tr,
          description: 'notifications.orderStatusProgress'.tr,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
        ),
      );
    }

    _localInitialized = true;
    _orderProgressPresenter = OrderProgressNotificationPresenter(
      plugin: _localNotifications,
      channelId: _ordersChannelId,
      stableInt: _stableInt,
    );
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

  Future<void> _handleOrderStatusPayload(
    Map<String, dynamic> merged, {
    String? title,
    String? body,
  }) async {
    if (TaxiOrderState.shouldIgnorePayload(merged, bodyOverride: body)) return;

    await _upsertOrderProgressNotification(
      merged,
      titleOverride: title,
      bodyOverride: body,
    );
    await _upsertOrderInAppCenter(
      merged,
      title: title,
      body: body,
    );
  }

  Future<void> _upsertOrderInAppCenter(
    Map<String, dynamic> merged, {
    String? title,
    String? body,
  }) async {
    final id = _orderStatusInAppId(merged);
    final resolvedTitle = OrderProgressNotificationMapper.resolveDisplayTitle(
      merged,
      titleOverride: title,
      defaultAppTitle: AppStrings.appName,
    );
    final resolvedBody = OrderProgressNotificationMapper.resolveDisplayBody(
      merged,
      bodyOverride: body,
      orderType: merged['order_type']?.toString() ??
          merged['service_type']?.toString(),
    );
    if (TaxiOrderState.isTaxiOrderType(
          (merged['order_type'] ?? merged['service_type'] ?? '').toString(),
        ) &&
        resolvedBody.trim().isEmpty &&
        !TaxiOrderState.isNotificationAllowed(
          TaxiOrderState.resolveNotificationStatus(merged, bodyOverride: body),
        )) {
      return;
    }

    final index = notifications.indexWhere((item) => item.id == id);
    final item = AppNotificationItem(
      id: id,
      title: resolvedTitle,
      body: resolvedBody,
      createdAt: DateTime.now(),
      data: merged,
      isRead: index >= 0 ? notifications[index].isRead : false,
    );
    if (index >= 0) {
      notifications[index] = item;
    } else {
      notifications.insert(0, item);
    }
    _recalculateUnread();
    await _saveToStorage();
  }

  String _orderStatusInAppId(Map<String, dynamic>? data) {
    if (data == null) return 'order_status_unknown';
    final oid = data['order_id']?.toString().trim() ?? '';
    if (oid.isEmpty) return 'order_status_unknown';
    return 'order_status_$oid';
  }

  Future<void> _upsertOrderProgressNotification(
    Map<String, dynamic> data, {
    String? titleOverride,
    String? bodyOverride,
  }) async {
    if (!_localInitialized || _orderProgressPresenter == null) return;

    final rawOrderId = data['order_id'];
    final orderId = rawOrderId?.toString().trim();
    if (orderId == null || orderId.isEmpty || orderId == 'null') return;

    final collapseId = data['collapse_id']?.toString().trim();
    final orderKey = collapseId != null && collapseId.isNotEmpty
        ? collapseId
        : 'order_$orderId';
    final explicitNotificationId =
        _asInt(data['android_notification_id']) ?? _asInt(data['order_id']);
    if (explicitNotificationId == null) {
      _resolveNotificationId(
        key: orderKey,
        store: _orderNotificationIds,
      );
      await _saveNotificationIdMappings();
    }

    await _orderProgressPresenter!.showOrUpdate(
      data,
      titleOverride: titleOverride,
      bodyOverride: bodyOverride,
    );
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
        ? 'notifications.newChatMessage'.trParams({'sender': sender})
        : 'notifications.newMessage'.tr;
    final body = (message != null && message.isNotEmpty)
        ? message
        : 'notifications.newMessageInChat'.tr;

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

  Future<void> _handleOrderStatusMilestones(Map<String, dynamic>? data) async {
    if (data == null) return;
    final type = data['type']?.toString().trim().toLowerCase();
    if (type == 'order_status') return;

    final orderType =
        (data['order_type'] ?? data['service_type'] ?? '').toString();
    if (TaxiOrderState.isTaxiOrderType(orderType)) return;

    final orderId = data['order_id']?.toString();
    if (orderId == null || orderId.trim().isEmpty) return;

    final status = OrderProgressNotificationMapper.canonicalStatus(
      data['status']?.toString() ?? data['order_status']?.toString() ?? '',
    );
    final dispatchStatus = OrderProgressNotificationMapper.canonicalStatus(
      data['dispatch_status']?.toString() ??
          data['driver_status']?.toString() ??
          '',
    );
    final isPrePickupAssignment =
        _prePickupAssignmentStatuses.contains(status) ||
        _prePickupAssignmentStatuses.contains(dispatchStatus);

    final isNearAddress = !isPrePickupAssignment &&
        (_nearAddressStatuses.contains(status) ||
            _nearAddressStatuses.contains(dispatchStatus));
    final isArrivedWaiting = !isPrePickupAssignment &&
        (_arrivedWaitingStatuses.contains(status) ||
            _arrivedWaitingStatuses.contains(dispatchStatus));

    if (isNearAddress) {
      await pushLocalInAppNotification(
        title: 'tracking.deliveryAlert'.tr,
        body: 'tracking.driverNearby'.tr,
        dedupeKey: 'onesignal-order-$orderId-near-address',
        data: {
          ...data,
          'event': 'driver_near_address',
        },
      );
    }

    if (isArrivedWaiting) {
      await pushLocalInAppNotification(
        title: 'tracking.deliveryAlert'.tr,
        body: 'tracking.driverWaiting'.tr,
        dedupeKey: 'onesignal-order-$orderId-arrived-waiting',
        data: {
          ...data,
          'event': 'driver_arrived_waiting',
        },
      );
    }
  }

  static const Set<String> _prePickupAssignmentStatuses = {
    'pending',
    'searching',
    'dispatching',
    'assigned',
    'accepted',
    'driver_assigned',
    'accepted_by_driver',
  };

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
    final normalizedToken = userToken.trim();
    if (normalizedToken.isEmpty) return;
    _pendingSubscribeToken = normalizedToken;

    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId == null || playerId.trim().isEmpty) return;

    try {
      await _api.request(
        method: 'POST',
        path: Endpoints.onesignalSubscribe,
        token: normalizedToken,
        body: {'player_id': playerId},
        retries: 0,
      );
    } catch (_) {
      // Keep app flow intact even if notification subscription fails.
    }
  }

  Future<void> unsubscribeDevice(String userToken) async {
    final playerId = OneSignal.User.pushSubscription.id;
    if (playerId == null || playerId.trim().isEmpty) return;

    try {
      await _api.request(
        method: 'POST',
        path: Endpoints.onesignalUnsubscribe,
        token: userToken,
        body: {'player_id': playerId},
        retries: 0,
      );
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
