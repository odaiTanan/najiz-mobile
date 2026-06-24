import 'package:get/get.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/features/restaurant/errors/restaurant_api_exception.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_products_model.dart';
import 'package:najiz_go_express/features/restaurant/repositories/restaurant_repository.dart';

class RestaurantVendorProductsController extends GetxController {
  RestaurantVendorProductsController({
    required this.token,
    required this.vendorId,
    RestaurantRepository? repository,
  }) : _repository = repository ?? RestaurantRepository();

  final String? token;
  final int vendorId;
  final RestaurantRepository _repository;

  final isLoading = false.obs;
  final errorMessage = RxnString();

  final vendorProducts = Rxn<VendorProductsModel>();
  final selectedCategoryId = RxnInt();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool gateRetry = false}) async {
    errorMessage.value = null;
    isLoading.value = true;
    try {
      vendorProducts.value = await _repository.getVendorProducts(
        token: token,
        vendorId: vendorId,
      );
      selectedCategoryId.value = null; // Default "All"
    } on RestaurantApiException catch (e) {
      if (gateRetry) {
        rethrow;
      }
      if (e.isConnectivityIssue) {
        showNoInternetGateIfNeededFeature(
          e,
          retry: () => load(gateRetry: true),
        );
        errorMessage.value = null;
        vendorProducts.value = null;
      } else {
        errorMessage.value = e.message;
        vendorProducts.value = null;
      }
    } catch (_) {
      if (gateRetry) {
        rethrow;
      }
      errorMessage.value = 'فشل تحميل المنيو';
      vendorProducts.value = null;
    } finally {
      isLoading.value = false;
    }
  }

  void selectCategory(int? categoryId) {
    selectedCategoryId.value = categoryId;
  }

  List<VendorProductsCategory> get regularCategories {
    final data = vendorProducts.value;
    if (data == null) return const [];
    return data.categories
        .where((category) => category.type == 'regular')
        .toList(growable: false);
  }

  List<VendorProductItem> get filteredRegularProducts {
    final data = vendorProducts.value;
    if (data == null) return const [];

    final regularCategoryIds = regularCategories.map((c) => c.id).toSet();
    final regularProducts = data.products.where((product) {
      final byCategoryId = product.categoryId != null &&
          regularCategoryIds.contains(product.categoryId);
      final byInlineCategoryType = product.categoryType == 'regular';
      return byCategoryId || byInlineCategoryType;
    });

    final categoryId = selectedCategoryId.value;
    if (categoryId == null) return regularProducts.toList(growable: false);

    return regularProducts
        .where((product) => product.categoryId == categoryId)
        .toList(growable: false);
  }

  List<VendorProductItem> get offerProducts {
    final data = vendorProducts.value;
    if (data == null) return const [];

    final offerCategoryIds = data.categories
        .where((category) => category.type == 'offers')
        .map((category) => category.id)
        .toSet();

    return data.products.where((product) {
      final byCategoryId = product.categoryId != null &&
          offerCategoryIds.contains(product.categoryId);
      final byInlineCategoryType = product.categoryType == 'offers';
      return byCategoryId || byInlineCategoryType;
    }).toList(growable: false);
  }

  List<VendorProductItem> get filteredProducts {
    final regular = filteredRegularProducts;
    final offers = offerProducts;
    return [...regular, ...offers];
  }
}

