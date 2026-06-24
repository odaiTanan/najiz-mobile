import 'package:najiz_go_express/features/home/models/offer_model.dart';

class OfferNavigationService {
  const OfferNavigationService();

  OfferServiceKind resolveServiceKind(OfferModel offer) {
    return OfferModel.resolveServiceKind(offer.service);
  }

  bool shouldOpenVendor(OfferModel offer) {
    final vendorId = offer.vendorId;
    return vendorId != null && vendorId > 0;
  }

  int resolveVendorServiceId(OfferModel offer) {
    return offer.vendor?.serviceId ?? offer.serviceId ?? 1;
  }
}
