import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
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
import 'package:najiz_go_express/features/home/views/cart_screen.dart';
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
  /// أثناء إعادة المحاولة بسبب الشبكة على الصفحة الرئيسية (شيمر + شريط تنبيه).
  final homeWaitingNetwork = false.obs;
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

  bool _homeOfflineSnackShown = false;

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

  Future<void> _fetchHomePayload({required bool propagateConnectivity}) async {
    final results = await Future.wait<dynamic>([
      _repository.getOffers(token: activeToken),
      _repository.getServices(token: activeToken),
    ]);
    final loadedOffers = (results[0] as List<OfferModel>);
    final loadedServices = (results[1] as List<ServiceModel>);

    offers.assignAll(loadedOffers);
    services.assignAll(loadedServices);

    if (loadedServices.isNotEmpty) {
      final initialServiceId = _pickDefaultRestaurantServiceId(
        loadedServices,
      );
      restaurantServiceId.value = initialServiceId;
      selectedServiceId.value = initialServiceId;
      unawaited(
        loadVendorsByService(
          initialServiceId,
          propagateConnectivity: propagateConnectivity,
        ),
      );
    } else {
      restaurantServiceId.value = null;
      vendors.clear();
    }
    unawaited(_loadActiveOrders());
  }

  Future<void> loadHomeData() async {
    errorMessage.value = null;
    isLoading.value = true;
    homeWaitingNetwork.value = false;

    try {
      while (!isClosed) {
        try {
          await _fetchHomePayload(propagateConnectivity: true);
          errorMessage.value = null;
          _homeOfflineSnackShown = false;
          homeWaitingNetwork.value = false;
          break;
        } on HomeApiException catch (e) {
          if (e.isConnectivityIssue) {
            homeWaitingNetwork.value = true;
            if (!_homeOfflineSnackShown) {
              _homeOfflineSnackShown = true;
              AppSnackbar.show(
                'offline.title'.tr,
                'home.waitingForNetworkHint'.tr,
                duration: const Duration(seconds: 4),
                icon: const Icon(Icons.wifi_off_rounded, color: AppColors.primary),
              );
            }
            await Future<void>.delayed(const Duration(seconds: 2));
            if (isClosed) return;
            continue;
          }
          homeWaitingNetwork.value = false;
          errorMessage.value = e.message;
          break;
        } catch (_) {
          homeWaitingNetwork.value = false;
          errorMessage.value = 'home_ctrl.loadFailed'.tr;
          break;
        }
      }
    } finally {
      homeWaitingNetwork.value = false;
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
          backgroundColor: Colors.white,
          content: Text(
            'home_ctrl.savedCart'.tr,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
          duration: const Duration(milliseconds: 500),
          action: SnackBarAction(
            label: '→',
            textColor: AppColors.primary,
            onPressed: () {
              cart.consumeSavedCart();
              Get.to(
                () => CartScreen(
                  token: activeToken,
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

  Future<void> loadVendorsByService(
    int serviceId, {
    bool propagateConnectivity = false,
  }) async {
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
      vendors.clear();
      if (propagateConnectivity && e.isConnectivityIssue) {
        rethrow;
      }
      if (e.isConnectivityIssue) {
        errorMessage.value = AppErrorMessages.noInternet;
        AppSnackbar.show(
          'offline.title'.tr,
          'home.waitingForNetworkHint'.tr,
          duration: const Duration(seconds: 3),
          icon: const Icon(Icons.wifi_off_rounded, color: AppColors.primary),
        );
      } else {
        errorMessage.value = e.message;
      }
    } catch (_) {
      errorMessage.value = 'home_ctrl.restaurantsFailed'.tr;
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

  void onOfferTap(OfferModel offer) {
    final serviceId = _resolveOfferServiceId(offer);
    final vendorId = offer.vendor?.id ?? offer.vendorId;

    if (serviceId == 5) {
      Get.to(() => TaxiBookingScreen(token: activeToken));
      return;
    }

    if (vendorId != null && vendorId > 0 && serviceId != 5) {
      Get.to(
        () => RestaurantVendorProductsScreen(
          token: activeToken,
          vendorId: vendorId,
          serviceId: serviceId,
        ),
      );
      return;
    }

    if (serviceId == 3) {
      Get.to(() => RestaurantProductsScreen(token: activeToken, serviceId: 3));
      return;
    }

    if (serviceId != null) {
      Get.to(
        () => RestaurantProductsScreen(token: activeToken, serviceId: serviceId),
      );
      return;
    }

    final orderedServices = services.toList(growable: false);
    if (orderedServices.isNotEmpty) {
      onServiceTap(orderedServices.first);
    }
  }

  void openNotifications() {
    Get.to(() => const NotificationsScreen());
  }

  void openSupportChat() {
    AuthGuardService.runOrRequestLogin(
      onAuthenticated: (token) async {
        Get.to(() => SupportChatScreen(token: token));
      },
      message: 'home_ctrl.loginForSupport'.tr,
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

  int? _resolveOfferServiceId(OfferModel offer) {
    final explicit = offer.serviceId ?? offer.vendor?.serviceId;
    if (explicit != null) return explicit;

    final hint = [
      offer.serviceType,
      offer.vendor?.type,
      offer.name,
      offer.vendor?.name,
    ].whereType<String>().join(' ').toLowerCase();

    if (hint.contains('taxi') || hint.contains('تكسي')) return 5;
    if (hint.contains('store') ||
        hint.contains('shop') ||
        hint.contains('market') ||
        hint.contains('متجر')) {
      return 3;
    }
    if (hint.contains('restaurant') ||
        hint.contains('food') ||
        hint.contains('مطعم') ||
        hint.contains('مطاعم')) {
      return 1;
    }

    return null;
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
