import 'package:najiz_go_express/features/home/config/local_service_catalog.dart';
import 'package:najiz_go_express/features/home/models/offer_model.dart';
import 'package:najiz_go_express/features/home/models/service_kind.dart';

class OfferNavigationService {
  const OfferNavigationService();

  ServiceKind resolveServiceKind(OfferModel offer) => offer.serviceKind;

  bool hasVendor(OfferModel offer) {
    final vendorId = offer.vendorId;
    return vendorId != null && vendorId > 0;
  }

  /// Catalog service id for restaurant/store screens.
  /// Prefer API ids; never infer kind from vendorId alone.
  int resolveCatalogServiceId(OfferModel offer) {
    final fromOffer = offer.serviceId;
    if (fromOffer != null && fromOffer > 0) return fromOffer;

    final fromVendor = offer.vendor?.serviceId;
    if (fromVendor != null && fromVendor > 0) return fromVendor;

    for (final definition in LocalServiceCatalog.byId.values) {
      if (definition.kind == offer.serviceKind) return definition.id;
    }

    // Should not be reached for restaurant/store navigation paths.
    return LocalServiceCatalog.byId.values
        .firstWhere((d) => d.kind == ServiceKind.restaurant)
        .id;
  }
}
