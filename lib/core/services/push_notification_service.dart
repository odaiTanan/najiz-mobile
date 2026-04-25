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
      _appendNotification(
        title: notification.title ?? 'إشعار جديد',
        body: notification.body ?? '',
        externalId: notification.notificationId,
        data: notification.additionalData,
      );
    });

    OneSignal.Notifications.addClickListener((event) {
      final notification = event.notification;
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
