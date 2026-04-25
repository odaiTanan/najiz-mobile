import 'package:get/get.dart';
import 'package:najiz_go_express/data/models/vendor_products_model.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';

class RestaurantVendorProductsController extends GetxController {
  RestaurantVendorProductsController({
    required this.token,
    required this.vendorId,
    HomeRepository? repository,
  }) : _repository = repository ?? HomeRepository();

  final String? token;
  final int vendorId;
  final HomeRepository _repository;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  final vendorProducts = Rxn<VendorProductsModel>();
  final selectedCategoryId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      vendorProducts.value = await _repository.getVendorProducts(
        token: token,
        vendorId: vendorId,
      );
      selectedCategoryId.value = null; // Default "All"
    } on HomeApiException catch (e) {
      errorMessage.value = e.message;
      vendorProducts.value = null;
    } catch (_) {
      errorMessage.value = 'فشل تحميل المنيو';
      vendorProducts.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  void selectCategory(int? categoryId) {
    selectedCategoryId.value = categoryId;
  }

  List<VendorProductItem> get filteredProducts {
    final data = vendorProducts.value;
    if (data == null) return const [];

    final categoryId = selectedCategoryId.value;
    if (categoryId == null) return data.products;

    return data.products
        .where((product) => product.categoryId == categoryId)
        .toList(growable: false);
  }
}

