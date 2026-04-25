import 'package:get/get.dart';
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

  OrderWebSocketService? _wsService;

  @override
  void onInit() {
    super.onInit();
    currentStatus.value = initialStatus;
    currentDispatchStatus.value = initialDispatchStatus;
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
  }

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
