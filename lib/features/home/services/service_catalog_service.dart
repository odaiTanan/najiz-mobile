import 'package:najiz_go_express/features/home/config/local_service_catalog.dart';
import 'package:najiz_go_express/features/home/models/service_kind.dart';
import 'package:najiz_go_express/features/home/models/service_model.dart';

class ServiceCatalogService {
  const ServiceCatalogService();

  static const Set<int> hiddenServiceIds = {7};

  ServiceModel applyLocalPresentation(ServiceModel raw) {
    final definition = LocalServiceCatalog.find(raw.id);
    if (definition == null) {
      return raw.copyWith(kind: ServiceKind.unknown);
    }
    return raw.copyWith(
      nameKey: definition.nameKey,
      kind: definition.kind,
      iconData: definition.iconData,
      iconColor: definition.iconColor,
      iconAsset: definition.iconAsset,
    );
  }

  List<ServiceModel> applyAll(Iterable<ServiceModel> services) {
    return services
        .where((service) => !hiddenServiceIds.contains(service.id))
        .map(applyLocalPresentation)
        .toList(growable: false);
  }

  List<ServiceModel> sortForHome(List<ServiceModel> services) {
    final sorted = [...services];
    sorted.sort(
      (a, b) => LocalServiceCatalog.sortOrderFor(a.id)
          .compareTo(LocalServiceCatalog.sortOrderFor(b.id)),
    );
    return sorted;
  }

  bool isRestaurant(ServiceModel service) {
    return service.kind == ServiceKind.restaurant ||
        service.kind == ServiceKind.store;
  }

  List<ServiceModel> buildCatalogServices() {
    final models = LocalServiceCatalog.byId.keys
        .map((id) => ServiceModel(id: id))
        .toList(growable: false);
    return sortForHome(applyAll(models));
  }
}
