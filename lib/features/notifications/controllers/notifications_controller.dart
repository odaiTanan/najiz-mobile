import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/features/notifications/models/app_notification_item.dart';
import 'package:najiz_go_express/features/orders/views/my_orders_screen.dart';

class NotificationsController extends GetxController {
  late final PushNotificationService _pushService;
  late final AuthStateManager _authStateManager;

  List<AppNotificationItem> get notifications => _pushService.notifications;
  RxInt get unreadCount => _pushService.unreadCount;

  @override
  void onInit() {
    super.onInit();
    _pushService = Get.find<PushNotificationService>();
    _authStateManager = Get.find<AuthStateManager>();
  }

  Future<void> markAllRead() => _pushService.markAllRead();

  Future<void> onNotificationTap(AppNotificationItem item) async {
    await _pushService.markAsRead(item.id);
    if (item.data['type']?.toString() == 'order_status') {
      final token = _authStateManager.token.value;
      if (token != null && token.trim().isNotEmpty) {
        Get.to(() => MyOrdersScreen(token: token));
      }
    }
  }
}
