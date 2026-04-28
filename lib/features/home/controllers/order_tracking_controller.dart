import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/core/services/order_websocket_service.dart';

class OrderTrackingController extends GetxController {
  OrderTrackingController({
    required this.token,
    required this.orderId,
    required this.orderNumber,
    required this.initialStatus,
    required this.initialDispatchStatus,
  });

  final String token;
  final int orderId;
  final String orderNumber;
  final String initialStatus;
  final String initialDispatchStatus;

  final currentStatus = ''.obs;
  final currentDispatchStatus = ''.obs;
  final isLiveConnected = false.obs;
  final errorMessage = RxnString();
  final isSubmittingRating = false.obs;
  final ratingSubmitted = false.obs;
  final hasPromptedForRating = false.obs;
  final showRatingButton = false.obs;

  final HomeRepository _repository = HomeRepository();
  final PushNotificationService _pushService = Get.find<PushNotificationService>();

  OrderWebSocketService? _wsService;
  bool _didNotifyNearAddress = false;
  bool _didNotifyArrivedWaiting = false;

  @override
  void onInit() {
    super.onInit();
    currentStatus.value = initialStatus;
    currentDispatchStatus.value = initialDispatchStatus;
    _emitDriverArrivalNotificationsIfNeeded();
    _connect();
  }

  Future<void> _connect() async {
    errorMessage.value = null;
    _wsService = OrderWebSocketService(token: token);
    try {
      await _wsService!.subscribeToOrder(
        orderId: orderId,
        onOrderUpdated: _onOrderUpdated,
      );
      isLiveConnected.value = true;
    } catch (e) {
      isLiveConnected.value = false;
      errorMessage.value = 'تعذر الاتصال بالتتبع اللحظي: $e';
    }
  }

  void _onOrderUpdated(Map<String, dynamic> payload) {
    print('[TRACKING][UPDATE] $payload');
    currentStatus.value = (payload['status'] ?? currentStatus.value).toString();
    currentDispatchStatus.value =
        (payload['dispatch_status'] ?? currentDispatchStatus.value).toString();
    _emitDriverArrivalNotificationsIfNeeded();
  }

  void _emitDriverArrivalNotificationsIfNeeded() {
    final status = _normalizeStatus(currentStatus.value);
    final dispatch = _normalizeStatus(currentDispatchStatus.value);

    if (_isCompletedOrCancelled(status)) return;

    final isDriverNearAddress =
        _nearAddressStatuses.contains(status) ||
        _nearAddressStatuses.contains(dispatch);

    final isDriverArrivedWaiting =
        _arrivedWaitingStatuses.contains(status) ||
        _arrivedWaitingStatuses.contains(dispatch);

    if (!_didNotifyNearAddress && isDriverNearAddress) {
      _didNotifyNearAddress = true;
      _pushService.pushLocalInAppNotification(
        title: 'تنبيه التوصيل',
        body: 'السائق أصبح على مقربة من عنوانك',
        dedupeKey: 'order-$orderId-near-address',
        data: {'order_id': orderId, 'event': 'driver_near_address'},
      );
    }

    if (!_didNotifyArrivedWaiting && isDriverArrivedWaiting) {
      _didNotifyArrivedWaiting = true;
      _pushService.pushLocalInAppNotification(
        title: 'تنبيه التوصيل',
        body: 'السائق وصل وهو في الانتظار',
        dedupeKey: 'order-$orderId-arrived-waiting',
        data: {'order_id': orderId, 'event': 'driver_arrived_waiting'},
      );
    }
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  }

  bool _isCompletedOrCancelled(String status) {
    return status == 'delivered' || status == 'cancelled';
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

  Future<void> submitRating({
    required int vendorRating,
    int? deliveryRating,
    String? comment,
  }) async {
    isSubmittingRating.value = true;
    try {
      await _repository.rateOrder(
        token: token,
        orderId: orderId,
        vendorRating: vendorRating,
        deliveryRating: deliveryRating,
        comment: comment,
      );
      ratingSubmitted.value = true;
      showRatingButton.value = false;
    } on HomeApiException catch (e) {
      throw e.message;
    } catch (_) {
      throw 'تعذر إرسال التقييم حاليا';
    } finally {
      isSubmittingRating.value = false;
    }
  }

  void postponeRating() {
    showRatingButton.value = true;
  }

  @override
  void onClose() {
    _wsService?.disconnect();
    super.onClose();
  }
}
