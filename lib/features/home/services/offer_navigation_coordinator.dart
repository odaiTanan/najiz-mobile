import 'package:get/get.dart';
import 'package:najiz_go_express/features/home/models/offer_model.dart';
import 'package:najiz_go_express/features/home/services/offer_navigation_service.dart';
import 'package:najiz_go_express/features/restaurant/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/features/shipping/views/shipping_screen.dart';
import 'package:najiz_go_express/features/taxi/views/taxi_booking_screen.dart';

class OfferNavigationCoordinator {
  OfferNavigationCoordinator({
    OfferNavigationService? navigationService,
  }) : _navigationService = navigationService ?? const OfferNavigationService();

  final OfferNavigationService _navigationService;

  void openOffer({
    required OfferModel offer,
    required String? token,
  }) {
    if (_navigationService.shouldOpenVendor(offer)) {
      Get.to(
        () => RestaurantVendorProductsScreen(
          token: token,
          vendorId: offer.vendorId!,
          serviceId: _navigationService.resolveVendorServiceId(offer),
        ),
      );
      return;
    }

    switch (_navigationService.resolveServiceKind(offer)) {
      case OfferServiceKind.shipping:
        Get.to(() => ShippingScreen(token: token));
      case OfferServiceKind.taxi:
        Get.to(() => TaxiBookingScreen(token: token));
    }
  }
}
