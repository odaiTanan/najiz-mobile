import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/data/models/offer_model.dart';
import 'package:najiz_go_express/data/models/service_model.dart';
import 'package:najiz_go_express/data/models/vendor_model.dart';
import 'package:najiz_go_express/data/repositories/auth_repository.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/user_order.dart';
import 'package:najiz_go_express/features/home/views/notifications_screen.dart';
import 'package:najiz_go_express/features/home/views/order_tracking_screen.dart';
import 'package:najiz_go_express/features/home/views/order_checkout_screen.dart';
import 'package:najiz_go_express/features/home/views/restaurant_products_screen.dart';
import 'package:najiz_go_express/features/home/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/features/home/views/shipping_screen.dart';
import 'package:najiz_go_express/features/home/views/taxi_booking_screen.dart';
import 'package:najiz_go_express/features/home/views/my_orders_screen.dart';
import 'package:najiz_go_express/features/home/views/transport_order_tracking_screen.dart';
import 'package:najiz_go_express/features/support/views/support_chat_screen.dart';

class HomeController extends GetxController {
  HomeController({this.token, HomeRepository? repository})
    : _repository = repository ?? HomeRepository();

  final String? token;
  final HomeRepository _repository;
  final AuthRepository _authRepository = AuthRepository();
  late final AuthStateManager _authStateManager;
  late final PushNotificationService _pushNotificationService;

  final isLoading = false.obs;
  final offers = <OfferModel>[].obs;
  final services = <ServiceModel>[].obs;
  final vendors = <VendorModel>[].obs;
  final vendorActiveFilter = RxnBool();
  final vendorCuisineFilter = RxnString();
  final selectedServiceId = RxnInt();
  final restaurantServiceId = RxnInt();
  final activeOrders = <UserOrder>[].obs;
  final displayName = ''.obs;
  final errorMessage = RxnString();

  bool get isGuest => _authStateManager.isGuest;
  String? get activeToken => _authStateManager.token.value ?? token;
  RxInt get unreadNotifications => _pushNotificationService.unreadCount;
  UserOrder? get primaryActiveOrder =>
      activeOrders.isEmpty ? null : activeOrders.first;
  bool get hasMoreActiveOrders => activeOrders.length > 1;
  List<VendorModel> get filteredVendors {
    return vendors.where((vendor) {
      final activeOk = vendorActiveFilter.value == null
          ? true
          : (vendorActiveFilter.value! ? vendor.isOpened : !vendor.isOpened);
      final cuisine = vendorCuisineFilter.value;
      final cuisineOk = cuisine == null
          ? true
          : _vendorMatchesCuisine(vendor: vendor, cuisine: cuisine);
      return activeOk && cuisineOk;
    }).toList(growable: false);
  }

  @override
  void onInit() {
    super.onInit();
    _authStateManager = Get.find<AuthStateManager>();
    _pushNotificationService = Get.find<PushNotificationService>();
    _loadIdentity();
    _initSavedCartIfAny();
    loadHomeData();
  }

  Future<void> _loadIdentity() async {
    final identity = await SessionService.getUserIdentity();
    final resolved = (identity['name'] ?? identity['phone'] ?? '').trim();
    displayName.value = resolved;

    final authToken = activeToken;
    if (authToken == null || authToken.trim().isEmpty) return;
    try {
      final user = await _authRepository.getCurrentUser(token: authToken);
      if (user == null || user.isEmpty) return;
      final name = (user['name'] ?? user['full_name'] ?? '').toString().trim();
      final phone = (user['phone'] ?? '').toString().trim();
      final email = (user['email'] ?? '').toString().trim();
      await SessionService.saveUserIdentity(
        name: name.isEmpty ? null : name,
        phone: phone.isEmpty ? null : phone,
        email: email.isEmpty ? null : email,
      );
      displayName.value = (name.isNotEmpty ? name : phone);
    } catch (_) {
      // Keep local cached identity if profile sync fails.
    }
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
      await _loadActiveOrders();
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
    } catch (_) {
      errorMessage.value =
          'حدث خطأ غير متوقع أثناء تحميل بيانات الصفحة الرئيسية';
    } finally {
      isLoading.value = false;
    }
  }

  void _initSavedCartIfAny() {
    Future.microtask(() async {
      final cart = Get.find<AppCartService>();
      final restored = await cart.restoreSavedCartIfAny();
      if (!restored) return;
      final vendorId = cart.vendorId.value;
      final items = cart.items.toList(growable: false);
      if (vendorId == null || items.isEmpty) return;

      final ctx = Get.overlayContext ?? Get.context;
      if (ctx == null) return;

      // Show a snackbar once after app opens.
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: const Text('لديك سلة محفوظة'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: '→',
            onPressed: () {
              cart.consumeSavedCart();
              Get.to(
                () => OrderCheckoutScreen(
                  token: activeToken,
                  vendorId: vendorId,
                  items: items,
                  serviceId: selectedServiceId.value,
                ),
              );
            },
          ),
        ),
      );
    });
  }

  Future<void> _loadActiveOrders() async {
    final authToken = activeToken;
    if (authToken == null || authToken.trim().isEmpty || isGuest) {
      activeOrders.clear();
      return;
    }
    try {
      final all = await _repository.getMyOrders(token: authToken);
      final active = all.where(_isActiveOrder).toList(growable: false);
      active.sort((a, b) {
        final ad = DateTime.tryParse(a.createdAt);
        final bd = DateTime.tryParse(b.createdAt);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });
      activeOrders.assignAll(active);
    } catch (_) {
      activeOrders.clear();
    }
  }

  bool _isActiveOrder(UserOrder order) {
    final status = order.status.toLowerCase();
    return status != 'delivered' && status != 'cancelled';
  }

  Future<void> loadVendorsByService(int serviceId) async {
    selectedServiceId.value = serviceId;
    try {
      final loadedVendors = await _repository.getVendorsByService(
        token: activeToken,
        serviceId: serviceId,
      );
      vendors.assignAll(loadedVendors);
      vendorActiveFilter.value = null;
      vendorCuisineFilter.value = null;
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
        serviceId: selectedServiceId.value ?? vendor.serviceId,
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

  void openPrimaryActiveOrder() {
    final order = primaryActiveOrder;
    if (order == null) return;
    if (order.type == 'shipping' || order.type == 'taxi') {
      Get.to(
        () => TransportOrderTrackingScreen(
          token: activeToken ?? token ?? '',
          orderId: order.id,
          orderNumber: order.orderNumber,
          orderType: order.type,
          initialStatus: order.status,
          initialDispatchStatus: order.dispatchStatus,
          pickupLat: order.lat,
          pickupLng: order.lng,
          destinationLat: order.lat,
          destinationLng: order.lng,
        ),
      );
      return;
    }
    Get.to(
      () => OrderTrackingScreen(
        token: activeToken ?? token ?? '',
        orderId: order.id,
        orderNumber: order.orderNumber,
        initialStatus: order.status,
        initialDispatchStatus: order.dispatchStatus,
      ),
    );
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

  void toggleVendorActiveFilter(bool active) {
    vendorActiveFilter.value = vendorActiveFilter.value == active ? null : active;
  }

  void toggleVendorCuisineFilter(String cuisine) {
    vendorCuisineFilter.value = vendorCuisineFilter.value == cuisine ? null : cuisine;
  }

  bool _vendorMatchesCuisine({
    required VendorModel vendor,
    required String cuisine,
  }) {
    final haystack = '${vendor.name} ${vendor.description ?? ''}'.toLowerCase();
    switch (cuisine) {
      case 'fastfood':
        return haystack.contains('وجبات سريعة') ||
            haystack.contains('fast') ||
            haystack.contains('burger') ||
            haystack.contains('shawarma');
      case 'western':
        return haystack.contains('غربي') ||
            haystack.contains('western') ||
            haystack.contains('pizza') ||
            haystack.contains('burger');
      case 'eastern':
        return haystack.contains('شرقي') ||
            haystack.contains('eastern') ||
            haystack.contains('مشاوي') ||
            haystack.contains('عربي');
      default:
        return true;
    }
  }
}
