import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AuthStateManager auth;
  late PushNotificationService push;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();
    auth = AuthStateManager();
    push = PushNotificationService();
    Get.put<AuthStateManager>(auth, permanent: true);
    Get.put<PushNotificationService>(push, permanent: true);
  });

  tearDown(Get.reset);

  Future<void> loginAs(String token) async {
    await auth.markAuthenticated(token);
  }

  Future<void> receiveLocalPush(String title) async {
    await push.pushLocalInAppNotification(
      title: title,
      body: 'body',
      dedupeKey: 'test-$title-${DateTime.now().microsecondsSinceEpoch}',
      showSnack: false,
    );
  }

  test('Flow A — normal login enables notifications and updates unread', () async {
    await loginAs('token-a');

    expect(push.debugAcceptUserNotifications, isTrue);
    expect(auth.isAuthenticated, isTrue);

    await receiveLocalPush('Hello A');

    expect(push.notifications.length, 1);
    expect(push.unreadCount.value, 1);
    expect(push.debugPendingSubscribeToken, 'token-a');

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('app_notifications_history');
    expect(raw, isNotNull);
    final decoded = jsonDecode(raw!) as List<dynamic>;
    expect(decoded, isNotEmpty);
    expect(decoded.first['title'], 'Hello A');
  });

  test('Flow B — restricted/logout clears history, unread, and badge state', () async {
    await loginAs('token-a');
    await receiveLocalPush('Keep private');
    expect(push.unreadCount.value, 1);

    await auth.markGuest();

    expect(auth.isGuest, isTrue);
    expect(push.debugAcceptUserNotifications, isFalse);
    expect(push.notifications, isEmpty);
    expect(push.unreadCount.value, 0);
    expect(push.debugPendingSubscribeToken, isNull);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_notifications_history'), isNull);
    expect(prefs.getString('auth_token'), isNull);
  });

  test('Flow C — next login does not restore previous user history', () async {
    await loginAs('token-a');
    await receiveLocalPush('User A only');
    await auth.markGuest();

    await loginAs('token-b');

    expect(push.debugAcceptUserNotifications, isTrue);
    expect(push.notifications, isEmpty);
    expect(push.unreadCount.value, 0);

    await receiveLocalPush('User B only');

    expect(push.notifications.length, 1);
    expect(push.notifications.first.title, 'User B only');
    expect(push.unreadCount.value, 1);
    expect(push.debugPendingSubscribeToken, 'token-b');

    final titles = push.notifications.map((n) => n.title).toList();
    expect(titles, isNot(contains('User A only')));
  });

  test('Flow D — normal logout then login restores notification handling', () async {
    await loginAs('token-a');
    await receiveLocalPush('Before logout');
    await auth.markGuest();

    expect(push.debugAcceptUserNotifications, isFalse);

    await loginAs('token-a-again');
    expect(push.debugAcceptUserNotifications, isTrue);

    await receiveLocalPush('After login');
    expect(push.notifications.length, 1);
    expect(push.notifications.first.title, 'After login');
    expect(push.unreadCount.value, 1);
  });

  test('Guest cannot persist authenticated-user notification history', () async {
    await loginAs('token-a');
    await auth.markGuest();

    await receiveLocalPush('Should be ignored');

    expect(push.notifications, isEmpty);
    expect(push.unreadCount.value, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_notifications_history'), isNull);
  });

  test('Stale epoch save cannot restore previous history after clear', () async {
    await loginAs('token-a');
    await receiveLocalPush('Stale candidate');
    final staleEpoch = push.debugHistoryEpoch;
    expect(staleEpoch, greaterThanOrEqualTo(0));

    await push.clearLocalHistory();
    expect(push.notifications, isEmpty);
    expect(push.debugHistoryEpoch, greaterThan(staleEpoch));

    // In-flight writer from the previous session attempts to persist.
    await push.debugSaveToStorage(expectedEpoch: staleEpoch);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_notifications_history'), isNull);

    // After resume + login path, a fresh write must succeed.
    push.resumeUserNotifications();
    auth.token.value = 'token-b';
    auth.status.value = AuthStatus.authenticated;

    await receiveLocalPush('Fresh after resume');
    expect(push.notifications.length, 1);
    expect(prefs.getString('app_notifications_history'), isNotNull);
  });

  test('invalidateSessionAndOpenLogin clears notification state for restricted account',
      () async {
    await loginAs('token-restricted');
    await receiveLocalPush('Restricted user notif');
    expect(push.unreadCount.value, 1);

    // Avoid navigation side effects from openLogin in unit tests by going
    // through markGuest, which invalidateSessionAndOpenLogin always calls.
    await auth.markGuest();

    expect(push.notifications, isEmpty);
    expect(push.unreadCount.value, 0);
    expect(push.debugAcceptUserNotifications, isFalse);
  });
}
