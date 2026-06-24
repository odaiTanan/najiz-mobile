import 'dart:async';

import 'package:flutter/material.dart';
import 'package:najiz_go_express/features/restaurant/errors/restaurant_api_exception.dart';
import 'package:najiz_go_express/features/home/errors/home_api_exception.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/constants/app_error_messages.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/core/utils/remote_image_cache_warmer.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/push_notification_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/features/home/models/offer_model.dart';
import 'package:najiz_go_express/features/home/models/service_kind.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_model.dart';
import 'package:najiz_go_express/features/auth/repositories/auth_repository.dart';
import 'package:najiz_go_express/features/auth/services/auth_dependencies.dart';
import 'package:najiz_go_express/features/home/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/services/home_bootstrap_cache.dart';
import 'package:najiz_go_express/features/home/services/home_dependencies.dart';
import 'package:najiz_go_express/features/home/services/offer_navigation_coordinator.dart';
import 'package:najiz_go_express/features/home/services/service_catalog_service.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/orders/services/orders_dependencies.dart';
import 'package:najiz_go_express/features/restaurant/repositories/restaurant_repository.dart';
import 'package:najiz_go_express/features/restaurant/services/restaurant_dependencies.dart';
import 'package:najiz_go_express/features/orders/models/user_order.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/features/orders/views/order_tracking_screen.dart';
import 'package:najiz_go_express/features/orders/views/cart_screen.dart';
import 'package:najiz_go_express/features/restaurant/views/restaurant_products_screen.dart';
import 'package:najiz_go_express/features/restaurant/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/features/shipping/views/shipping_screen.dart';
import 'package:najiz_go_express/features/taxi/views/taxi_booking_screen.dart';
import 'package:najiz_go_express/features/orders/views/my_orders_screen.dart';
import 'package:najiz_go_express/features/orders/views/transport_order_tracking_screen.dart';

class HomeController extends GetxController {
  HomeController({
    this.token,
    HomeRepository? repository,
    RestaurantRepository? restaurantRepository,
    OrdersRepository? ordersRepository,
    AuthRepository? authRepository,
    OfferNavigationCoordinator? offerNavigationCoordinator,
    ServiceCatalogService? serviceCatalogService,
  })  : _repository = repository ?? resolveHomeRepository(),
        _restaurantRepository =
            restaurantRepository ?? resolveRestaurantRepository(),
        _ordersRepository = ordersRepository ?? resolveOrdersRepository(),
        _authRepository = authRepository ?? resolveAuthRepository(),
        _offerNavigationCoordinator =
            offerNavigationCoordinator ?? resolveOfferNavigationCoordinator(),
        _serviceCatalogService =
            serviceCatalogService ?? resolveServiceCatalogService();

  final String? token;
  final HomeRepository _repository;
  final RestaurantRepository _restaurantRepository;
  final OrdersRepository _ordersRepository;
  final AuthRepository _authRepository;
  final OfferNavigationCoordinator _offerNavigationCoordinator;
  final ServiceCatalogService _serviceCatalogService;
  late final AuthStateManager _authStateManager;
  late final PushNotificationService _pushNotificationService;

  final isLoading = false.obs;
  final isVendorsLoading = false.obs;
  final isLoadingMoreVendors = false.obs;
  final vendorCurrentPage = 1.obs;
  final vendorLastPage = 1.obs;
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
  Future<void>? _homeLoadFuture;

  bool get isGuest => _authStateManager.isGuest;
  String? get activeToken => _authStateManager.token.value ?? token;
  RxInt get unreadNotifications => _pushNotificationService.unreadCount;
  UserOrder? get primaryActiveOrder =>
      activeOrders.isEmpty ? null : activeOrders.first;
  bool get hasMoreActiveOrders => activeOrders.length > 1;
  bool get hasMoreVendors => vendorCurrentPage.value < vendorLastPage.value;
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
    primeInstantShell();
    unawaited(_applyCachedDisplayName());
    _initSavedCartIfAny();
    unawaited(loadHomeData());
    unawaited(_deferIdentitySync());
  }

  /// Instant paint: disk cache, else local service catalog (no network wait).
  void primeInstantShell() {
    final snapshot = HomeBootstrapCache.memory;
    if (snapshot != null) {
      _applySnapshot(snapshot);
      isLoading.value = false;
      return;
    }

    if (services.isEmpty) {
      services.assignAll(_serviceCatalogService.buildCatalogServices());
    }
    isLoading.value = false;
  }

  void _applySnapshot(HomeBootstrapSnapshot snapshot) {
    offers.assignAll(snapshot.offers);
    services.assignAll(
      _serviceCatalogService.applyAll(snapshot.services),
    );
    if (snapshot.vendors.isNotEmpty) {
      vendors.assignAll(snapshot.vendors);
    }
    if (snapshot.vendorServiceId != null) {
      restaurantServiceId.value = snapshot.vendorServiceId;
      selectedServiceId.value = snapshot.vendorServiceId;
    }
  }

  Future<void> _deferIdentitySync() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (isClosed) return;
    await _loadIdentity();
  }

  Future<void> _applyCachedDisplayName() async {
    final identity = await SessionService.getUserIdentity();
    final resolved = (identity['name'] ?? identity['phone'] ?? '').trim();
    if (resolved.isNotEmpty) {
      displayName.value = resolved;
    }
  }

  Future<void> _loadIdentity() async {
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

  Future<void> _fetchHomePayload({
    required bool propagateConnectivity,
    bool forceRefresh = false,
  }) async {
    final token = activeToken;

    if (services.isEmpty) {
      services.assignAll(_serviceCatalogService.buildCatalogServices());
    }
    final currentServices = services.toList(growable: false);
    final vendorServiceId = currentServices.isNotEmpty
        ? _pickDefaultRestaurantServiceId(currentServices)
        : null;

    if (vendorServiceId != null) {
      restaurantServiceId.value = vendorServiceId;
      selectedServiceId.value = vendorServiceId;
    } else {
      restaurantServiceId.value = null;
    }

    final loadedOffers = await _repository.getOffers(
      token: token,
      forceRefresh: forceRefresh,
    );

    offers.assignAll(loadedOffers);
    isLoading.value = false;
    unawaited(
      RemoteImageCacheWarmer.warmUrls(
        loadedOffers.map((offer) => offer.image),
        maxCount: 8,
      ),
    );

    unawaited(
      HomeBootstrapCache.save(
        offers: loadedOffers,
        services: currentServices,
        vendors: vendors.toList(growable: false),
        vendorServiceId: vendorServiceId,
      ),
    );

    if (vendorServiceId != null) {
      unawaited(
        _refreshVendorsInBackground(
          vendorServiceId,
          propagateConnectivity: propagateConnectivity,
          forceRefresh: forceRefresh,
        ),
      );
    } else {
      vendors.clear();
    }

    unawaited(_syncServicesInBackground(forceRefresh: forceRefresh));
    unawaited(_deferActiveOrders());
  }

  Future<void> _syncServicesInBackground({bool forceRefresh = false}) async {
    try {
      final loadedServices = await _repository.getServices(
        token: activeToken,
        forceRefresh: forceRefresh,
      );
      if (isClosed || loadedServices.isEmpty) return;

      services.assignAll(loadedServices);
      final vendorServiceId = _pickDefaultRestaurantServiceId(loadedServices);
      final previousVendorServiceId = restaurantServiceId.value;
      restaurantServiceId.value = vendorServiceId;
      selectedServiceId.value = vendorServiceId;

      unawaited(
        HomeBootstrapCache.save(
          offers: offers.toList(growable: false),
          services: loadedServices,
          vendors: vendors.toList(growable: false),
          vendorServiceId: vendorServiceId,
        ),
      );

      if (previousVendorServiceId != vendorServiceId) {
        unawaited(
          loadVendorsByService(
            vendorServiceId,
            propagateConnectivity: false,
            persistCache: true,
            forceRefresh: forceRefresh,
          ),
        );
      }
    } catch (_) {
      // Catalog is already visible; ignore background sync failures.
    }
  }

  Future<void> _deferActiveOrders() async {
    await Future<void>.delayed(const Duration(seconds: 5));
    if (isClosed) return;
    await _loadActiveOrders();
  }

  Future<void> _refreshVendorsInBackground(
    int serviceId, {
    required bool propagateConnectivity,
    bool forceRefresh = false,
  }) {
    return loadVendorsByService(
      serviceId,
      propagateConnectivity: propagateConnectivity,
      persistCache: true,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> loadHomeData({bool forceRefresh = false}) {
    if (forceRefresh) {
      return _loadHomeDataImpl(forceRefresh: true);
    }
    return _homeLoadFuture ??= _loadHomeDataImpl(forceRefresh: false).whenComplete(() {
      _homeLoadFuture = null;
    });
  }

  Future<void> refreshHomeData() => loadHomeData(forceRefresh: true);

  Future<void> _loadHomeDataImpl({bool forceRefresh = false}) async {
    errorMessage.value = null;
    homeWaitingNetwork.value = false;

    try {
      while (!isClosed) {
        try {
          await _fetchHomePayload(
            propagateConnectivity: true,
            forceRefresh: forceRefresh,
          );
          errorMessage.value = null;
          _homeOfflineSnackShown = false;
          homeWaitingNetwork.value = false;
          break;
        } on HomeFeatureApiException catch (e) {
          if (e.isConnectivityIssue) {
            homeWaitingNetwork.value = true;
            if (!_homeOfflineSnackShown && !isClosed) {
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
      final page = await _ordersRepository.getMyOrdersPage(token: authToken);
      final active = page.items.where(_isActiveOrder).toList(growable: false);
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
    bool persistCache = false,
    bool forceRefresh = false,
    bool showConnectivitySnackbar = true,
  }) async {
    selectedServiceId.value = serviceId;
    final hadVendors = vendors.isNotEmpty;
    if (!hadVendors) {
      isVendorsLoading.value = true;
    }
    try {
      final result = await _restaurantRepository.getVendorsByService(
        token: activeToken,
        serviceId: serviceId,
        forceRefresh: forceRefresh,
      );
      vendors.assignAll(result.items);
      vendorCurrentPage.value = result.currentPage;
      vendorLastPage.value = result.lastPage;
      vendorActiveFilter.value = null;
      vendorCuisineFilter.value = null;
      unawaited(
        RemoteImageCacheWarmer.warmUrls(
          result.items.map((vendor) => vendor.image ?? vendor.logo),
          maxCount: 12,
        ),
      );
      if (persistCache) {
        unawaited(
          HomeBootstrapCache.save(
            offers: offers.toList(growable: false),
            services: services.toList(growable: false),
            vendors: result.items,
            vendorServiceId: serviceId,
          ),
        );
      }
    } on RestaurantApiException catch (e) {
      if (!hadVendors) vendors.clear();
      if (propagateConnectivity && e.isConnectivityIssue) {
        rethrow;
      }
      if (e.isConnectivityIssue) {
        errorMessage.value = AppErrorMessages.noInternet;
        if (showConnectivitySnackbar && !isClosed) {
          AppSnackbar.show(
            'offline.title'.tr,
            'home.waitingForNetworkHint'.tr,
            duration: const Duration(seconds: 3),
            icon: const Icon(Icons.wifi_off_rounded, color: AppColors.primary),
          );
        }
      } else {
        errorMessage.value = e.message;
      }
    } catch (_) {
      if (!hadVendors) {
        errorMessage.value = 'home_ctrl.restaurantsFailed'.tr;
        vendors.clear();
      }
    } finally {
      isVendorsLoading.value = false;
    }
  }

  Future<void> loadMoreVendorsIfNeeded() async {
    if (isLoadingMoreVendors.value || !hasMoreVendors) return;
    final serviceId =
        restaurantServiceId.value ?? selectedServiceId.value;
    if (serviceId == null) return;

    isLoadingMoreVendors.value = true;
    try {
      final result = await _restaurantRepository.getVendorsByService(
        token: activeToken,
        serviceId: serviceId,
        page: vendorCurrentPage.value + 1,
      );
      vendors.addAll(result.items);
      vendorCurrentPage.value = result.currentPage;
      vendorLastPage.value = result.lastPage;
    } catch (_) {
      // Keep already loaded vendors visible.
    } finally {
      isLoadingMoreVendors.value = false;
    }
  }

  void onServiceTap(ServiceModel service) {
    switch (service.kind) {
      case ServiceKind.shipping:
        Get.to(() => ShippingScreen(token: activeToken));
        return;
      case ServiceKind.taxi:
        Get.to(() => TaxiBookingScreen(token: activeToken));
        return;
      case ServiceKind.restaurant:
      case ServiceKind.store:
        selectedServiceId.value = service.id;
        Get.to(
          () => RestaurantProductsScreen(
            token: activeToken,
            serviceId: service.id,
          ),
        );
        return;
      case ServiceKind.supermarket:
        return;
      case ServiceKind.unknown:
        if (service.id == 2) {
          Get.to(() => ShippingScreen(token: activeToken));
          return;
        }
        if (service.id == 5) {
          Get.to(() => TaxiBookingScreen(token: activeToken));
          return;
        }
        if (_serviceCatalogService.isRestaurant(service)) {
          selectedServiceId.value = service.id;
          Get.to(
            () => RestaurantProductsScreen(
              token: activeToken,
              serviceId: service.id,
            ),
          );
        }
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
    _offerNavigationCoordinator.openOffer(
      offer: offer,
      token: activeToken,
    );
  }

  void openNotifications() {
    AppRoutes.openNotifications();
  }

  void openSupportChat() {
    AuthGuardService.runOrRequestLogin(
      onAuthenticated: (token) async {
        AppRoutes.openSupportChat(token: token);
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
        isStoreOrder: _isStoreOrder(order),
      ),
    );
  }

  bool _isStoreOrder(UserOrder order) {
    final type = order.type.trim().toLowerCase();
    if (type == 'store' || type == 'stores') return true;
    return order.vendor?.serviceId == 3;
  }

  int _pickDefaultRestaurantServiceId(List<ServiceModel> loadedServices) {
    final restaurantService = loadedServices.firstWhereOrNull(
      (service) => service.kind == ServiceKind.restaurant,
    );
    if (restaurantService != null) return restaurantService.id;

    final serviceOne = loadedServices.firstWhereOrNull(
      (service) => service.id == 1,
    );
    if (serviceOne != null) return serviceOne.id;

    final catalogRestaurant = loadedServices.firstWhereOrNull(
      (service) => _serviceCatalogService.isRestaurant(service),
    );
    if (catalogRestaurant != null) return catalogRestaurant.id;

    return loadedServices.first.id;
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
