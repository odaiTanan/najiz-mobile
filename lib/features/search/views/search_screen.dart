import 'dart:async';

import 'package:flutter/material.dart';
import 'package:najiz_go_express/features/search/errors/search_api_exception.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/models/paginated_page.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/features/restaurant/models/vendor_model.dart';
import 'package:najiz_go_express/features/profile/repositories/profile_repository.dart';
import 'package:najiz_go_express/features/restaurant/repositories/restaurant_repository.dart';
import 'package:najiz_go_express/features/search/repositories/search_repository.dart';
import 'package:najiz_go_express/features/profile/models/user_address.dart';
import 'package:najiz_go_express/features/profile/services/profile_dependencies.dart';
import 'package:najiz_go_express/features/restaurant/services/restaurant_dependencies.dart';
import 'package:najiz_go_express/features/search/search_meta_cache.dart';
import 'package:najiz_go_express/features/search/services/search_dependencies.dart';
import 'package:najiz_go_express/features/search/models/search_models.dart';
import 'package:najiz_go_express/features/restaurant/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/core/navigation/home_bottom_bar.dart';
import 'package:najiz_go_express/core/navigation/main_bottom_nav.dart';
import 'package:najiz_go_express/core/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/core/widgets/network_image_with_fallback.dart';
import 'package:najiz_go_express/features/orders/widgets/vendor_order_status.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.token});

  final String? token;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final SearchRepository _repository = resolveSearchRepository();
  final RestaurantRepository _restaurantRepository = resolveRestaurantRepository();
  final ProfileRepository _profileRepository = resolveProfileRepository();
  final TextEditingController _searchController = TextEditingController();

  Timer? _debounce;
  bool _isLoading = false;
  bool _isLoadingMeta = false;
  String? _error;
  String? _selectedType; // null=all, product, vendor
  SearchSortOption _selectedSort = SearchSortOption.bestMatch;
  bool? _preSearchActiveFilter; // null = all, true = active, false = inactive
  String? _preSearchCuisineFilter; // fastfood, western, eastern
  SearchResultModel? _results;
  List<VendorModel> _preSearchVendors = const [];
  List<String> _suggestions = const [];
  List<SearchTrendingItem> _trending = const [];
  List<SearchHistoryItem> _history = const [];
  late String _locationLabel = 'search.myLocation'.tr;

  String? get _activeToken {
    final auth = Get.find<AuthStateManager>();
    return auth.token.value ?? widget.token;
  }

  bool get _isGuest => Get.find<AuthStateManager>().isGuest;

  @override
  void initState() {
    super.initState();
    if (!SearchMetaCache.isFresh || _trending.isEmpty) {
      _loadMeta();
    }
  }

  Future<void> _loadMeta({bool force = false}) async {
    if (!force && SearchMetaCache.isFresh && _trending.isNotEmpty) {
      return;
    }

    setState(() => _isLoadingMeta = true);
    try {
      final trendingFuture =
          _repository.getTrendingSearches(limit: 10, days: 7);
      List<SearchHistoryItem> history = const [];
      String locationLabel = 'search.myLocation'.tr;
      List<VendorModel> preSearchVendors = const [];
      final token = _activeToken;
      if (!_isGuest && token != null && token.trim().isNotEmpty) {
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
        final trending = results[0] as List<SearchTrendingItem>;
        history = results[1] as List<SearchHistoryItem>;
        final addresses = results[2] as List<UserAddress>;
        final restaurants = results[3] as PaginatedPage<VendorModel>;
        final stores = results[4] as PaginatedPage<VendorModel>;

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
          locationLabel = sortedAddresses.first.toShortLabel();
        }

        final merged = <int, VendorModel>{};
        for (final v in [...restaurants.items, ...stores.items]) {
          merged[v.id] = v;
        }
        preSearchVendors = merged.values.toList(growable: false);

        if (!mounted) return;
        setState(() {
          _trending = trending;
          _history = history;
          _locationLabel = locationLabel;
          _preSearchVendors = preSearchVendors;
        });
      } else {
        final trending = await trendingFuture;
        if (!mounted) return;
        setState(() {
          _trending = trending;
          _history = history;
          _locationLabel = locationLabel;
          _preSearchVendors = preSearchVendors;
        });
      }
      SearchMetaCache.markLoaded();
    } catch (_) {
      // Keep UI usable even if meta endpoints fail.
    } finally {
      if (mounted) setState(() => _isLoadingMeta = false);
    }
  }

  Future<void> _refreshSearchHistoryOnly() async {
    final token = _activeToken;
    if (_isGuest || token == null || token.trim().isEmpty) return;
    try {
      final history =
          await _repository.getSearchHistory(token: token, limit: 20);
      if (!mounted) return;
      setState(() => _history = history);
    } catch (_) {}
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final suggestions = await _repository.searchSuggestions(query: query, limit: 6);
        if (!mounted) return;
        setState(() => _suggestions = suggestions);
      } catch (_) {}
    });
  }

  Future<void> _performSearch(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.length < 2) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _suggestions = const [];
    });
    try {
      final result = await _repository.search(
        token: _activeToken,
        query: query,
        type: _selectedType,
        limit: 12,
      );
      if (!mounted) return;
      setState(() => _results = result);
      await _refreshSearchHistoryOnly();
    } on SearchApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'search.searchFailed'.tr);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    final token = _activeToken;
    if (_isGuest || token == null || token.trim().isEmpty) return;
    try {
      await _repository.clearSearchHistory(token: token);
      if (!mounted) return;
      setState(() => _history = const []);
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.surface,
          content: Text(
            'search.historyCleared'.tr,
            style: TextStyle(color: cs.onSurface),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: cs.surface,
          content: Text(
            'search.clearHistoryFailed'.tr,
            style: TextStyle(color: cs.onSurface),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 3,
        onTap: (index) => MainBottomNav.onTap(
          index: index,
          currentIndex: 3,
          token: _activeToken,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildSearchBar(),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      _locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.location_on_rounded, size: 13, color: cs.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: 6),
            _buildTypeFilters(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // Runtime decoration — do not use const with .tr
  InputDecoration _searchInputDecoration() => InputDecoration(
        hintText: 'search.placeholder'.tr,
        border: InputBorder.none,
        isDense: true,
      );

  Widget _buildSearchBar() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
            splashRadius: 20,
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) {
                _onSearchChanged(value);
                setState(() {});
              },
              onSubmitted: _performSearch,
              decoration: _searchInputDecoration(),
            ),
          ),
          if (_searchController.text.trim().isNotEmpty)
            IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _results = null;
                  _suggestions = const [];
                });
              },
              icon: const Icon(Icons.clear_rounded, size: 20),
            )
          else
            Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _buildTypeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      child: Row(
        children: [
          _TopTabItem(
            label: 'search.filterAll'.tr,
            selected: _selectedType == null,
            onTap: () {
              setState(() => _selectedType = null);
              final text = _searchController.text.trim();
              if (text.length >= 2) _performSearch(text);
            },
          ),
          _TopTabItem(
            label: 'search.filterProducts'.tr,
            selected: _selectedType == 'product',
            onTap: () {
              setState(() => _selectedType = 'product');
              final text = _searchController.text.trim();
              if (text.length >= 2) _performSearch(text);
            },
          ),
          _TopTabItem(
            label: 'search.filterVendors'.tr,
            selected: _selectedType == 'vendor',
            onTap: () {
              setState(() => _selectedType = 'vendor');
              final text = _searchController.text.trim();
              if (text.length >= 2) _performSearch(text);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: const TextStyle(color: AppColors.error)),
      );
    }
    if (_results != null) return _buildResults();
    if (_suggestions.isNotEmpty) return _buildSuggestions();
    return _buildDiscovery();
  }

  Widget _buildSuggestions() {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _suggestions.length,
      itemBuilder: (_, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          dense: true,
          leading: Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
          title: Text(suggestion),
          onTap: () {
            _searchController.text = suggestion;
            _performSearch(suggestion);
          },
        );
      },
    );
  }

  Widget _buildDiscovery() {
    final cs = Theme.of(context).colorScheme;
    final filteredPreSearch = _filteredPreSearchVendors(_preSearchVendors);
    return RefreshIndicator(
      onRefresh: () => _loadMeta(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          if (_isLoadingMeta) const LinearProgressIndicator(minHeight: 2),
          if (_selectedType != 'product') ...[
            const SizedBox(height: 4),
            _buildPreSearchIconFilters(),
            if (_preSearchActiveFilter == null && _preSearchCuisineFilter == null) ...[
              const SizedBox(height: 10),
              Text(
                'search.selectFilter'.tr,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              if (filteredPreSearch.isEmpty)
                Text(
                  'search.noResultsForFilter'.tr,
                  style: TextStyle(color: cs.onSurfaceVariant),
                )
              else
                ...filteredPreSearch
                    .take(12)
                    .map((v) => _PreSearchVendorRow(item: v, token: _activeToken)),
            ],
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 6),
          Text(
            'search.mostSearched'.tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          if (_trending.isEmpty)
            Text(
              'search.noData'.tr,
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _trending
                  .map(
                    (item) => _KeywordChip(
                      text: item.query,
                      onTap: () {
                        _searchController.text = item.query;
                        _performSearch(item.query);
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child:                   Text(
                  'search.previouslySearched'.tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (!_isGuest && _history.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: Text(
                    'search.clearAll'.tr,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isGuest)
            Text(
              'search.loginForHistory'.tr,
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else if (_history.isEmpty)
            Text(
              'search.noHistory'.tr,
              style: TextStyle(color: cs.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _history
                  .map(
                    (item) => _KeywordChip(
                      text: item.query,
                      onTap: () {
                        _searchController.text = item.query;
                        _performSearch(item.query);
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildPreSearchIconFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _IconToggleChip(
            label: 'search.filterActive'.tr,
            icon: Icons.wifi_tethering_rounded,
            selected: _preSearchActiveFilter == true,
            onTap: () => setState(
              () => _preSearchActiveFilter = _preSearchActiveFilter == true ? null : true,
            ),
          ),
          _IconToggleChip(
            label: 'search.filterInactive'.tr,
            icon: Icons.do_not_disturb_alt_rounded,
            selected: _preSearchActiveFilter == false,
            onTap: () => setState(
              () => _preSearchActiveFilter = _preSearchActiveFilter == false ? null : false,
            ),
          ),
          _IconToggleChip(
            label: 'search.filterFastFood'.tr,
            icon: Icons.fastfood_rounded,
            selected: _preSearchCuisineFilter == 'fastfood',
            onTap: () => setState(
              () => _preSearchCuisineFilter = _preSearchCuisineFilter == 'fastfood'
                  ? null
                  : 'fastfood',
            ),
          ),
          _IconToggleChip(
            label: 'search.filterWestern'.tr,
            icon: Icons.restaurant_rounded,
            selected: _preSearchCuisineFilter == 'western',
            onTap: () => setState(
              () => _preSearchCuisineFilter = _preSearchCuisineFilter == 'western'
                  ? null
                  : 'western',
            ),
          ),
          _IconToggleChip(
            label: 'search.filterEastern'.tr,
            icon: Icons.ramen_dining_rounded,
            selected: _preSearchCuisineFilter == 'eastern',
            onTap: () => setState(
              () => _preSearchCuisineFilter = _preSearchCuisineFilter == 'eastern'
                  ? null
                  : 'eastern',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final results = _results!;
    final sortedVendors = _sortedVendors(results.vendors);
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      children: [
        const SizedBox(height: 2),
        Text(
          'search.resultsCount'.trParams({'count': results.totalResults.toString()}),
          style: TextStyle(
            color: cs.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _buildSortFilters(hasVendorResults: sortedVendors.isNotEmpty),
        const SizedBox(height: 12),
        if (results.products.isNotEmpty) ...[
          Text(
            'search.tabProducts'.tr,
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          ...results.products.map((p) => _ProductRow(item: p, token: _activeToken)),
          const SizedBox(height: 12),
        ],
        if (sortedVendors.isNotEmpty) ...[
          Text(
            'search.tabVendors'.tr,
            style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          ...sortedVendors.map((v) => _VendorRow(item: v, token: _activeToken)),
        ],
        if (results.products.isEmpty && results.vendors.isEmpty)
          Text(
            'search.noMatchingResults'.tr,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildSortFilters({required bool hasVendorResults}) {
    if (!hasVendorResults) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SortPill(
            label: 'search.sortBestMatch'.tr,
            selected: _selectedSort == SearchSortOption.bestMatch,
            onTap: () => setState(() => _selectedSort = SearchSortOption.bestMatch),
          ),
          _SortPill(
            label: 'search.sortOnline'.tr,
            selected: _selectedSort == SearchSortOption.online,
            onTap: () => setState(() => _selectedSort = SearchSortOption.online),
          ),
          _SortPill(
            label: 'search.sortFreeDelivery'.tr,
            selected: _selectedSort == SearchSortOption.freeDelivery,
            onTap: () => setState(() => _selectedSort = SearchSortOption.freeDelivery),
          ),
          _SortPill(
            label: 'search.sortTopRated'.tr,
            selected: _selectedSort == SearchSortOption.topRated,
            onTap: () => setState(() => _selectedSort = SearchSortOption.topRated),
          ),
          _SortPill(
            label: 'search.sortActive'.tr,
            selected: _selectedSort == SearchSortOption.active,
            onTap: () => setState(() => _selectedSort = SearchSortOption.active),
          ),
        ],
      ),
    );
  }

  List<SearchVendorModel> _sortedVendors(List<SearchVendorModel> source) {
    final items = [...source];
    switch (_selectedSort) {
      case SearchSortOption.bestMatch:
        return items;
      case SearchSortOption.online:
        items.sort((a, b) => (b.isOpened ? 1 : 0).compareTo(a.isOpened ? 1 : 0));
        return items;
      case SearchSortOption.freeDelivery:
        items.sort((a, b) => (b.hasFreeDelivery ? 1 : 0).compareTo(a.hasFreeDelivery ? 1 : 0));
        return items;
      case SearchSortOption.topRated:
        items.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
        return items;
      case SearchSortOption.active:
        items.sort((a, b) => (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0));
        return items;
    }
  }

  // ignore: unused_element — candidate for future pre-search sorting feature
  List<VendorModel> _sortedPreSearchVendors(List<VendorModel> source) {
    final items = [...source];
    switch (_selectedSort) {
      case SearchSortOption.bestMatch:
        return items;
      case SearchSortOption.online:
        items.sort((a, b) => (b.isOpened ? 1 : 0).compareTo(a.isOpened ? 1 : 0));
        return items;
      case SearchSortOption.topRated:
        items.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
        return items;
      case SearchSortOption.active:
        items.sort((a, b) => (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0));
        return items;
      case SearchSortOption.freeDelivery:
        return items;
    }
  }

  List<VendorModel> _filteredPreSearchVendors(List<VendorModel> source) {
    if (_preSearchActiveFilter == null && _preSearchCuisineFilter == null) {
      return const [];
    }
    final items = [...source];
    final filtered = items.where((v) {
      final statusOk = _preSearchActiveFilter == null
          ? true
          : (_preSearchActiveFilter! ? v.isOpened : !v.isOpened);
      final cuisineOk = _preSearchCuisineFilter == null
          ? true
          : _vendorMatchesCuisine(v, _preSearchCuisineFilter!);
      return statusOk && cuisineOk;
    }).toList(growable: false);
    filtered.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
    return filtered;
  }

  bool _vendorMatchesCuisine(VendorModel vendor, String cuisine) {
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

class _TopTabItem extends StatelessWidget {
  const _TopTabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 2.2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.primary : cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SortPill extends StatelessWidget {
  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : cs.outlineVariant,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconToggleChip extends StatelessWidget {
  const _IconToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : cs.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.item, required this.token});

  final SearchProductModel item;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = Color.alphaBlend(
      const Color(0x26FF8A00),
      cs.surfaceContainerHigh,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        dense: true,
        minVerticalPadding: 8,
        leading: Icon(Icons.fastfood_rounded, color: cs.onSurfaceVariant),
        title: Text(
          item.name,
          style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface),
        ),
        subtitle: Text(
          'search.priceLabel'.trParams({'price': item.price.toStringAsFixed(0)}),
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        trailing: SizedBox(
          width: 110,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  item.vendorName ?? '',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                ),
              ),
              FavoriteHeartButton(
                favoriteType: 'product',
                entityId: item.id,
                variant: FavoriteHeartVariant.onLightCard,
                size: 22,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        onTap: () {
          final vendorId = item.vendorId;
          if (vendorId == null) return;
          Get.to(
            () => RestaurantVendorProductsScreen(
              token: token,
              vendorId: vendorId,
              serviceId: _serviceIdFromVendorType(item.vendorType),
            ),
          );
        },
      ),
    );
  }
}

class _VendorRow extends StatelessWidget {
  const _VendorRow({required this.item, required this.token});

  final SearchVendorModel item;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStore = item.type == 'store' || item.type == 'stores';
    return InkWell(
      onTap: () {
        Get.to(
          () => RestaurantVendorProductsScreen(
            token: token,
            vendorId: item.id,
            serviceId: _serviceIdFromVendorType(item.type),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 58,
                child: NetworkImageWithFallback(
                  url: item.image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.type == 'restaurant' ? 'search.typeRestaurant'.tr : 'search.typeStore'.tr,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.isOpened ? 'search.statusOpen'.tr : 'search.statusClosed'.tr,
              style: TextStyle(
                color: item.isOpened ? const Color(0xFF0A8F48) : cs.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 4),
            FavoriteHeartButton(
              favoriteType: 'vendor',
              entityId: item.id,
              variant: FavoriteHeartVariant.onLightCard,
              size: 22,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

class _PreSearchVendorRow extends StatelessWidget {
  const _PreSearchVendorRow({required this.item, required this.token});

  final VendorModel item;
  final String? token;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isStore = item.serviceId == 3;
    return InkWell(
      onTap: () {
        Get.to(
          () => RestaurantVendorProductsScreen(
            token: token,
            vendorId: item.id,
            serviceId: item.serviceId,
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 58,
                height: 58,
                child: NetworkImageWithFallback(
                  url: item.image ?? item.logo,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (!item.isOpened ||
                      VendorOrderStatus.normalized(item.vendorStatus) != null)
                    VendorOrderStatusPill(
                      vendorStatus: item.vendorStatus,
                      isActive: item.isActive,
                      isOpened: item.isOpened,
                      isStore: isStore,
                    )
                  else
                    Text(
                      item.isOpened ? 'search.statusOnline'.tr : 'search.statusOffline'.tr,
                      style: TextStyle(
                        color: item.isOpened
                            ? const Color(0xFF0A8F48)
                            : cs.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            if (item.rating != null)
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
                  Text(
                    item.rating!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 4),
            FavoriteHeartButton(
              favoriteType: 'vendor',
              entityId: item.id,
              variant: FavoriteHeartVariant.onLightCard,
              size: 22,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

int _serviceIdFromVendorType(String? type) {
  final normalized = (type ?? '').trim().toLowerCase();
  if (normalized == 'store' || normalized == 'stores' || normalized == 'متجر') {
    return 3;
  }
  return 1;
}

enum SearchSortOption {
  bestMatch,
  online,
  freeDelivery,
  topRated,
  active,
}
