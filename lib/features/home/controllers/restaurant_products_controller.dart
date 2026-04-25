import 'package:get/get.dart';
import 'package:najiz_go_express/data/models/classification_model.dart';
import 'package:najiz_go_express/data/models/vendor_model.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/views/restaurant_vendor_products_screen.dart';

class RestaurantProductsController extends GetxController {
  RestaurantProductsController({
    required this.token,
    required this.serviceId,
    HomeRepository? repository,
  }) : _repository = repository ?? HomeRepository();

  final String? token;
  final int serviceId;
  final HomeRepository _repository;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  final classifications = <ClassificationModel>[].obs;
  final selectedClassificationId = RxnInt();

  final allVendors = <VendorModel>[].obs;
  final vendors = <VendorModel>[].obs;
  final selectedVendorId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      final loadedClassifications = await _repository
          .getClassificationsByService(token: token, serviceId: serviceId);

      classifications.assignAll(loadedClassifications);

      // Default "All" tab.
      selectedClassificationId.value = null;

      await loadVendorsByService();
      _applyClassificationFilter();
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
      classifications.clear();
      allVendors.clear();
      vendors.clear();
    } catch (_) {
      errorMessage.value = 'فشل تحميل المطاعم';
      classifications.clear();
      allVendors.clear();
      vendors.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadVendorsByService() async {
    final loaded = await _repository.getVendorsByService(
      token: token,
      serviceId: serviceId,
    );
    final sorted = _sortVendors(loaded);
    allVendors.assignAll(sorted);
  }

  Future<void> selectClassification(int? classificationId) async {
    selectedClassificationId.value = classificationId;
    _applyClassificationFilter();
  }

  Future<void> openVendorProducts(int vendorId) async {
    selectedVendorId.value = vendorId;
    await Get.to(
      () => RestaurantVendorProductsScreen(token: token, vendorId: vendorId),
    );
  }

  List<VendorModel> _sortVendors(List<VendorModel> list) {
    final sorted = [...list];
    sorted.sort((a, b) {
      final ar = a.rating ?? -1;
      final br = b.rating ?? -1;
      final byRating = br.compareTo(ar);
      if (byRating != 0) return byRating;
      return a.id.compareTo(b.id);
    });
    return sorted;
  }

  void _applyClassificationFilter() {
    final selected = selectedClassificationId.value;
    if (selected == null) {
      vendors.assignAll(allVendors);
      selectedVendorId.value = vendors.isNotEmpty ? vendors.first.id : null;
      return;
    }

    final filtered = allVendors.where((vendor) {
      return vendor.classificationId == selected;
    }).toList();
    vendors.assignAll(filtered);
    selectedVendorId.value = vendors.isNotEmpty ? vendors.first.id : null;
  }
}
