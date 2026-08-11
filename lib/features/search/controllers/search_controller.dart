import 'dart:async';

import 'package:get/get.dart';
import 'package:najiz_go_express/core/models/paginated_page.dart';
import 'package:najiz_go_express/features/search/errors/search_api_exception.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_model.dart';
import 'package:najiz_go_express/features/profile/models/user_address.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';
import 'package:najiz_go_express/features/profile/services/profile_dependencies.dart';
import 'package:najiz_go_express/features/restaurant/repositories/restaurant_repository.dart';
import 'package:najiz_go_express/features/restaurant/services/restaurant_dependencies.dart';
import 'package:najiz_go_express/features/search/models/search_models.dart';
import 'package:najiz_go_express/features/search/repositories/search_repository.dart';
import 'package:najiz_go_express/features/search/search_meta_cache.dart';
import 'package:najiz_go_express/features/search/services/search_dependencies.dart';
class SearchController extends GetxController {
  SearchController({
    this.initialToken,
    SearchRepository? searchRepository,
    RestaurantRepository? restaurantRepository,
    ProfileRepository? profileRepository,
  })  : _repository = searchRepository ?? resolveSearchRepository(),
        _restaurantRepository =
            restaurantRepository ?? resolveRestaurantRepository(),
        _profileRepository = profileRepository ?? resolveProfileRepository();

  final String? initialToken;
  final SearchRepository _repository;
  final RestaurantRepository _restaurantRepository;
  final ProfileRepository _profileRepository;

  late final AuthStateManager _auth;

  Timer? _debounce;

  final isLoading = false.obs;
  final isLoadingMeta = false.obs;
  final error = RxnString();
  final selectedType = RxnString();
  final selectedSort = SearchSortOption.bestMatch.obs;
  final preSearchActiveFilter = RxnBool();
  final preSearchCuisineFilter = RxnString();
  final results = Rxn<SearchResultModel>();
  final preSearchVendors = <VendorModel>[].obs;
  final suggestions = <String>[].obs;
  final trending = <SearchTrendingItem>[].obs;
  final history = <SearchHistoryItem>[].obs;
  final locationLabel = RxString('search.myLocation'.tr);
  final searchInputText = ''.obs;

  String? get activeToken {
    final authToken = _auth.token.value?.trim();
    if (authToken != null && authToken.isNotEmpty) return authToken;
    if (_auth.isGuest) return null;
    final legacy = initialToken?.trim();
    if (legacy == null || legacy.isEmpty) return null;
    return legacy;
  }
  bool get isGuest => _auth.isGuest;

  @override
  void onInit() {
    super.onInit();
    _auth = Get.find<AuthStateManager>();
    if (!SearchMetaCache.isFresh || trending.isEmpty) {
      loadMeta();
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  Future<void> loadMeta({bool force = false}) async {
    if (!force && SearchMetaCache.isFresh && trending.isNotEmpty) {
      return;
    }

    isLoadingMeta.value = true;
    try {
      final trendingFuture =
          _repository.getTrendingSearches(limit: 10, days: 7);
      final token = activeToken;
      if (!isGuest && token != null && token.trim().isNotEmpty) {
        final results = await Future.wait<dynamic>([
          trendingFuture,
          _repository.getSearchHistory(token: token, limit: 20),
          _profileRepository.getMyAddresses(token: token),
          _restaurantRepository.getVendorsByService(
            token: token,
            serviceId: 1,
          ),
          _restaurantRepository.getVendorsByService(
            token: token,
            serviceId: 3,
          ),
        ]);
        final trendingItems = results[0] as List<SearchTrendingItem>;
        final historyItems = results[1] as List<SearchHistoryItem>;
        final addresses = results[2] as List<UserAddress>;
        final restaurantsPage =
            results[3] as PaginatedPage<VendorModel>;
        final storesPage = results[4] as PaginatedPage<VendorModel>;

        var label = 'search.myLocation'.tr;
        if (addresses.isNotEmpty) {
          final sortedAddresses = [...addresses];
          sortedAddresses.sort((a, b) {
            final ad = DateTime.tryParse(a.updatedAt ?? a.createdAt ?? '');
            final bd = DateTime.tryParse(b.updatedAt ?? b.createdAt ?? '');
            if (ad == null && bd == null) return b.id.compareTo(a.id);
            if (ad == null) return 1;
            if (bd == null) return -1;
            return bd.compareTo(ad);
          });
          label = sortedAddresses.first.toShortLabel();
        }

        final merged = <int, VendorModel>{};
        for (final v in [...restaurantsPage.items, ...storesPage.items]) {
          merged[v.id] = v;
        }
        trending.assignAll(trendingItems);
        history.assignAll(historyItems);
        locationLabel.value = label;
        preSearchVendors.assignAll(merged.values.toList(growable: false));
      } else {
        final trendingItems = await trendingFuture;
        trending.assignAll(trendingItems);
        history.clear();
        locationLabel.value = 'search.myLocation'.tr;
        preSearchVendors.clear();
      }
      SearchMetaCache.markLoaded();
    } catch (_) {
      // Keep UI usable even if meta endpoints fail.
    } finally {
      isLoadingMeta.value = false;
    }
  }

  Future<void> refreshSearchHistoryOnly() async {
    final token = activeToken;
    if (isGuest || token == null || token.trim().isEmpty) return;
    try {
      final historyItems =
          await _repository.getSearchHistory(token: token, limit: 20);
      history.assignAll(historyItems);
    } catch (_) {}
  }

  void onSearchChanged(String value) {
    searchInputText.value = value;
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      suggestions.clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final items =
            await _repository.searchSuggestions(query: query, limit: 6);
        suggestions.assignAll(items);
      } catch (_) {}
    });
  }

  Future<void> performSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return;
    isLoading.value = true;
    error.value = null;
    suggestions.clear();
    try {
      final result = await _repository.search(
        token: activeToken,
        query: query,
        type: selectedType.value,
        limit: 12,
      );
      results.value = result;
      await refreshSearchHistoryOnly();
    } on SearchApiException catch (e) {
      error.value = e.message;
    } catch (_) {
      error.value = 'search.searchFailed'.tr;
    } finally {
      isLoading.value = false;
    }
  }

  void clearSearchResults() {
    results.value = null;
    suggestions.clear();
    searchInputText.value = '';
  }

  void setSelectedType(String? type) {
    selectedType.value = type;
  }

  void setSelectedSort(SearchSortOption sort) {
    selectedSort.value = sort;
  }

  void togglePreSearchActiveFilter(bool active) {
    preSearchActiveFilter.value =
        preSearchActiveFilter.value == active ? null : active;
  }

  void togglePreSearchCuisineFilter(String cuisine) {
    preSearchCuisineFilter.value =
        preSearchCuisineFilter.value == cuisine ? null : cuisine;
  }

  Future<bool> clearHistory() async {
    final token = activeToken;
    if (isGuest || token == null || token.trim().isEmpty) return false;
    try {
      await _repository.clearSearchHistory(token: token);
      history.clear();
      return true;
    } catch (_) {
      return false;
    }
  }

  List<SearchVendorModel> sortedVendors(List<SearchVendorModel> source) {
    final items = [...source];
    switch (selectedSort.value) {
      case SearchSortOption.bestMatch:
        return items;
      case SearchSortOption.online:
        items.sort((a, b) => (b.isOpened ? 1 : 0).compareTo(a.isOpened ? 1 : 0));
        return items;
      case SearchSortOption.freeDelivery:
        items.sort(
          (a, b) =>
              (b.hasFreeDelivery ? 1 : 0).compareTo(a.hasFreeDelivery ? 1 : 0),
        );
        return items;
      case SearchSortOption.topRated:
        items.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
        return items;
      case SearchSortOption.active:
        items.sort((a, b) => (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0));
        return items;
    }
  }

  List<VendorModel> filteredPreSearchVendors(List<VendorModel> source) {
    if (preSearchActiveFilter.value == null &&
        preSearchCuisineFilter.value == null) {
      return const [];
    }
    final items = [...source];
    final filtered = items.where((v) {
      final activeFilter = preSearchActiveFilter.value;
      final statusOk = activeFilter == null
          ? true
          : (activeFilter ? v.isOpened : !v.isOpened);
      final cuisine = preSearchCuisineFilter.value;
      final cuisineOk =
          cuisine == null ? true : vendorMatchesCuisine(v, cuisine);
      return statusOk && cuisineOk;
    }).toList(growable: false);
    filtered.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
    return filtered;
  }

  bool vendorMatchesCuisine(VendorModel vendor, String cuisine) {
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

  static int serviceIdFromVendorType(String? type) {
    final normalized = (type ?? '').trim().toLowerCase();
    if (normalized == 'store' || normalized == 'stores' || normalized == 'متجر') {
      return 3;
    }
    return 1;
  }
}
