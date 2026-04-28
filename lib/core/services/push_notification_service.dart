import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:najiz_go_express/core/constants/api_config.dart';
import 'package:najiz_go_express/features/home/models/app_notification_item.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PushNotificationService extends GetxService {
  static const String _oneSignalAppId = '9281c288-37c8-4a61-8a13-72feafc8b32a';
  static const String _storageKey = 'app_notifications_history';

  final _http = http.Client();
  final Map<String, DateTime> _recentLocalKeys = <String, DateTime>{};

  final notifications = <AppNotificationItem>[].obs;
  final unreadCount = 0.obs;
  bool _initialized = false;

  Future<void> initialize({String? token}) async {
    if (_initialized) return;
    _initialized = true;

    await _loadFromStorage();
    OneSignal.initialize(_oneSignalAppId);
    await OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      final notification = event.notification;
      _handleOrderStatusMilestones(notification.additionalData);
      _appendNotification(
        title: notification.title ?? 'إشعار جديد',
        body: notification.body ?? '',
        externalId: notification.notificationId,
        data: notification.additionalData,
      );
    });

    OneSignal.Notifications.addClickListener((event) {
      final notification = event.notification;
      _handleOrderStatusMilestones(notification.additionalData);
      _appendNotification(
        title: notification.title ?? 'إشعار جديد',
        body: notification.body ?? '',
        externalId: notification.notificationId,
        data: notification.additionalData,
      );
    });

    if (token != null && token.trim().isNotEmpty) {
      await subscribeDevice(token);
    }
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
      Get.snackbar(
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
