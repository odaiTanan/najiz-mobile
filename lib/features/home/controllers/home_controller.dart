import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/data/models/offer_model.dart';
import 'package:najiz_go_express/data/models/service_model.dart';
import 'package:najiz_go_express/data/models/vendor_model.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/views/notifications_screen.dart';
import 'package:najiz_go_express/features/home/views/restaurant_products_screen.dart';
import 'package:najiz_go_express/features/home/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/features/home/views/shipping_screen.dart';
import 'package:najiz_go_express/features/home/views/taxi_booking_screen.dart';
import 'package:najiz_go_express/features/home/views/my_orders_screen.dart';
import 'package:najiz_go_express/features/support/views/support_chat_screen.dart';

class HomeController extends GetxController {
  HomeController({this.token, HomeRepository? repository})
    : _repository = repository ?? HomeRepository();

  final String? token;
  final HomeRepository _repository;
  late final AuthStateManager _authStateManager;
  late final PushNotificationService _pushNotificationService;

  final isLoading = false.obs;
  final offers = <OfferModel>[].obs;
  final services = <ServiceModel>[].obs;
  final vendors = <VendorModel>[].obs;
  final selectedServiceId = RxnInt();
  final restaurantServiceId = RxnInt();
  final displayName = ''.obs;
  final errorMessage = RxnString();

  bool get isGuest => _authStateManager.isGuest;
  String? get activeToken => _authStateManager.token.value ?? token;
  RxInt get unreadNotifications => _pushNotificationService.unreadCount;

  @override
  void onInit() {
    super.onInit();
    _authStateManager = Get.find<AuthStateManager>();
    _pushNotificationService = Get.find<PushNotificationService>();
    _loadIdentity();
    loadHomeData();
  }

  Future<void> _loadIdentity() async {
    final identity = await SessionService.getUserIdentity();
    final resolved = (identity['name'] ?? identity['phone'] ?? '').trim();
    displayName.value = resolved;
  }

  Future<void> loadHomeData() async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      final loadedOffers = await _repository.getOffers(token: activeToken);
      final loadedServices = await _repository.getServices(token: activeToken);

      offers.assignAll(loadedOffers);
      services.assignAll(loadedServices);

      if (loadedServices.isNotEmpty) {
        final initialServiceId = _pickDefaultRestaurantServiceId(
          loadedServices,
        );
        restaurantServiceId.value = initialServiceId;
        selectedServiceId.value = initialServiceId;
        await loadVendorsByService(initialServiceId);
      } else {
        restaurantServiceId.value = null;
        vendors.clear();
      }
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value =
          'حدث خطأ غير متوقع أثناء تحميل بيانات الصفحة الرئيسية';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadVendorsByService(int serviceId) async {
    selectedServiceId.value = serviceId;
    try {
      final loadedVendors = await _repository.getVendorsByService(
        token: activeToken,
        serviceId: serviceId,
      );
      vendors.assignAll(loadedVendors);
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
      vendors.clear();
    } catch (_) {
      errorMessage.value = 'فشل تحميل المطاعم';
      vendors.clear();
    }
  }

  void onServiceTap(ServiceModel service) {
    if (service.id == 2) {
      Get.to(() => ShippingScreen(token: activeToken));
      return;
    }
    if (service.id == 3) {
      Get.to(() => RestaurantProductsScreen(token: activeToken, serviceId: 3));
      return;
    }
    if (service.id == 5) {
      Get.to(() => TaxiBookingScreen(token: activeToken));
      return;
    }
    if (_isRestaurantService(service)) {
      selectedServiceId.value = service.id;
      loadVendorsByService(service.id);
      Get.to(
        () =>
            RestaurantProductsScreen(token: activeToken, serviceId: service.id),
      );
    }
  }

  void onRestaurantCardTap(VendorModel vendor) {
    Get.to(
      () => RestaurantVendorProductsScreen(
        token: activeToken,
        vendorId: vendor.id,
      ),
    );
  }

  void openNotifications() {
    Get.to(() => const NotificationsScreen());
  }

  void openSupportChat() {
    AuthGuardService.runOrRequestLogin(
      onAuthenticated: (token) async {
        Get.to(() => SupportChatScreen(token: token));
      },
      message: 'يرجى تسجيل الدخول لمراسلة الدعم الفني',
    );
  }

  void onBottomNavTap(int index) {
    if (index == 1) {
      AuthGuardService.runOrRequestLogin(
        onAuthenticated: (token) async {
          Get.to(() => MyOrdersScreen(token: token));
        },
      );
    }
  }

  int _pickDefaultRestaurantServiceId(List<ServiceModel> loadedServices) {
    final restaurantService = loadedServices.firstWhereOrNull((service) {
      final name = service.name.trim().toLowerCase();
      return name.contains('restaurant') ||
          name.contains('food') ||
          name.contains('مطاعم');
    });

    if (restaurantService != null) return restaurantService.id;

    // Backend docs use /services/1/vendors for restaurants.
    final serviceOne = loadedServices.firstWhereOrNull(
      (service) => service.id == 1,
    );
    if (serviceOne != null) return serviceOne.id;

    return loadedServices.first.id;
  }

  bool _isRestaurantService(ServiceModel service) {
    final name = service.name.trim().toLowerCase();
    return name.contains('restaurant') ||
        name.contains('food') ||
        name.contains('مطاعم') ||
        service.id == 1;
  }
}
