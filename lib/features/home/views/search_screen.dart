import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_state_manager.dart';
import 'package:najiz_go_express/data/models/vendor_model.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/models/search_models.dart';
import 'package:najiz_go_express/features/home/views/restaurant_vendor_products_screen.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';
import 'package:najiz_go_express/features/home/widgets/favorite_heart_button.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.token});

  final String? token;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final HomeRepository _repository = HomeRepository();
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
  String _locationLabel = 'موقعي';

  String? get _activeToken {
    final auth = Get.find<AuthStateManager>();
    return auth.token.value ?? widget.token;
  }

  bool get _isGuest => Get.find<AuthStateManager>().isGuest;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    setState(() => _isLoadingMeta = true);
    try {
      final trending = await _repository.getTrendingSearches(limit: 10, days: 7);
      List<SearchHistoryItem> history = const [];
      String locationLabel = 'موقعي';
      List<VendorModel> preSearchVendors = const [];
      final token = _activeToken;
      if (!_isGuest && token != null && token.trim().isNotEmpty) {
        history = await _repository.getSearchHistory(token: token, limit: 20);
        final addresses = await _repository.getMyAddresses(token: token);
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

        final restaurants = await _repository.getVendorsByService(
          token: token,
          serviceId: 1,
        );
        final stores = await _repository.getVendorsByService(
          token: token,
          serviceId: 3,
        );
        final merged = <int, VendorModel>{};
        for (final v in [...restaurants, ...stores]) {
          merged[v.id] = v;
        }
        preSearchVendors = merged.values.toList(growable: false);
      }
      if (!mounted) return;
      setState(() {
        _trending = trending;
        _history = history;
        _locationLabel = locationLabel;
        _preSearchVendors = preSearchVendors;
      });
    } catch (_) {
      // Keep UI usable even if meta endpoints fail.
    } finally {
      if (mounted) setState(() => _isLoadingMeta = false);
    }
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
      await _loadMeta();
    } on HomeApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذر تنفيذ البحث');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم مسح سجل البحث')),
      );
      await _loadMeta();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر مسح السجل: $e')),
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
    return Scaffold(
      backgroundColor: AppColors.background,
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
                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9AA8BC)),
                  const SizedBox(width: 2),
                  Text(
                    _locationLabel,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.location_on_rounded, size: 13, color: Color(0xFF6C7E99)),
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

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Get.back(),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF607086)),
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
              decoration: const InputDecoration(
                hintText: 'ابحث عن وجبتك المفضلة',
                border: InputBorder.none,
                isDense: true,
              ),
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
            const Icon(Icons.search_rounded, color: Color(0xFF6E7E95)),
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
            label: 'الكل',
            selected: _selectedType == null,
            onTap: () {
              setState(() => _selectedType = null);
              final text = _searchController.text.trim();
              if (text.length >= 2) _performSearch(text);
            },
          ),
          _TopTabItem(
            label: 'المنتجات',
            selected: _selectedType == 'product',
            onTap: () {
              setState(() => _selectedType = 'product');
              final text = _searchController.text.trim();
              if (text.length >= 2) _performSearch(text);
            },
          ),
          _TopTabItem(
            label: 'المطاعم والمتاجر',
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
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _suggestions.length,
      itemBuilder: (_, index) {
        final suggestion = _suggestions[index];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.search_rounded, color: Color(0xFF7A8BA3)),
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
    final filteredPreSearch = _filteredPreSearchVendors(_preSearchVendors);
    return RefreshIndicator(
      onRefresh: _loadMeta,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: [
          if (_isLoadingMeta) const LinearProgressIndicator(minHeight: 2),
          if (_selectedType != 'product') ...[
            const SizedBox(height: 4),
            _buildPreSearchIconFilters(),
            if (_preSearchActiveFilter == null && _preSearchCuisineFilter == null) ...[
              const SizedBox(height: 10),
              const Text(
                'اختر فلتر لعرض النتائج',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              if (filteredPreSearch.isEmpty)
                const Text(
                  'لا توجد نتائج لهذا الفلتر حالياً',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...filteredPreSearch
                    .take(12)
                    .map((v) => _PreSearchVendorRow(item: v, token: _activeToken)),
            ],
            const SizedBox(height: 14),
          ],
          const SizedBox(height: 6),
          const Text(
            'الأكثر بحثاً من قبل المستخدمين',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (_trending.isEmpty)
            const Text(
              'لا توجد بيانات حالياً',
              style: TextStyle(color: AppColors.textSecondary),
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
              const Expanded(
                child: Text(
                  'بحثت مسبقاً عن',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (!_isGuest && _history.isNotEmpty)
                TextButton(
                  onPressed: _clearHistory,
                  child: const Text(
                    'مسح الكل',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isGuest)
            const Text(
              'سجل البحث يظهر بعد تسجيل الدخول',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else if (_history.isEmpty)
            const Text(
              'لا يوجد سجل بحث',
              style: TextStyle(color: AppColors.textSecondary),
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
            label: 'نشط',
            icon: Icons.wifi_tethering_rounded,
            selected: _preSearchActiveFilter == true,
            onTap: () => setState(
              () => _preSearchActiveFilter = _preSearchActiveFilter == true ? null : true,
            ),
          ),
          _IconToggleChip(
            label: 'غير نشط',
            icon: Icons.do_not_disturb_alt_rounded,
            selected: _preSearchActiveFilter == false,
            onTap: () => setState(
              () => _preSearchActiveFilter = _preSearchActiveFilter == false ? null : false,
            ),
          ),
          _IconToggleChip(
            label: 'وجبات سريعة',
            icon: Icons.fastfood_rounded,
            selected: _preSearchCuisineFilter == 'fastfood',
            onTap: () => setState(
              () => _preSearchCuisineFilter = _preSearchCuisineFilter == 'fastfood'
                  ? null
                  : 'fastfood',
            ),
          ),
          _IconToggleChip(
            label: 'غربي',
            icon: Icons.restaurant_rounded,
            selected: _preSearchCuisineFilter == 'western',
            onTap: () => setState(
              () => _preSearchCuisineFilter = _preSearchCuisineFilter == 'western'
                  ? null
                  : 'western',
            ),
          ),
          _IconToggleChip(
            label: 'شرقي',
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      children: [
        const SizedBox(height: 2),
        Text(
          'تم العثور على ${results.totalResults} نتيجة',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        _buildSortFilters(hasVendorResults: sortedVendors.isNotEmpty),
        const SizedBox(height: 12),
        if (results.products.isNotEmpty) ...[
          const Text(
            'المنتجات',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...results.products.map((p) => _ProductRow(item: p, token: _activeToken)),
          const SizedBox(height: 12),
        ],
        if (sortedVendors.isNotEmpty) ...[
          const Text(
            'المطاعم والمتاجر',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...sortedVendors.map((v) => _VendorRow(item: v, token: _activeToken)),
        ],
        if (results.products.isEmpty && results.vendors.isEmpty)
          const Text(
            'لا توجد نتائج مطابقة',
            style: TextStyle(color: AppColors.textSecondary),
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
            label: 'الأكثر مطابقة',
            selected: _selectedSort == SearchSortOption.bestMatch,
            onTap: () => setState(() => _selectedSort = SearchSortOption.bestMatch),
          ),
          _SortPill(
            label: 'متصل',
            selected: _selectedSort == SearchSortOption.online,
            onTap: () => setState(() => _selectedSort = SearchSortOption.online),
          ),
          _SortPill(
            label: 'توصيل مجاني',
            selected: _selectedSort == SearchSortOption.freeDelivery,
            onTap: () => setState(() => _selectedSort = SearchSortOption.freeDelivery),
          ),
          _SortPill(
            label: 'الأعلى تقييماً',
            selected: _selectedSort == SearchSortOption.topRated,
            onTap: () => setState(() => _selectedSort = SearchSortOption.topRated),
          ),
          _SortPill(
            label: 'نشط',
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
              color: selected ? AppColors.primary : AppColors.textPrimary,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFF3E8) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE3E8F0),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : const Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE3E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : const Color(0xFF90A0B5),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF7A8BA3),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EDE7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        dense: true,
        minVerticalPadding: 8,
        leading: const Icon(Icons.fastfood_rounded, color: Color(0xFF624B3F)),
        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '${item.price.toStringAsFixed(0)} ل.س',
          style: const TextStyle(
            color: Color(0xFF7A6052),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                item.vendorName ?? '',
                style: const TextStyle(color: Color(0xFF7A6052), fontSize: 11),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EBF2)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.type == 'restaurant' ? 'مطعم' : 'متجر',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.isOpened ? 'مفتوح' : 'مغلق',
              style: TextStyle(
                color: item.isOpened ? const Color(0xFF0A8F48) : AppColors.textSecondary,
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE6EBF2)),
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.isOpened ? 'متصل' : 'غير متصل',
                    style: TextStyle(
                      color: item.isOpened ? const Color(0xFF0A8F48) : AppColors.textSecondary,
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
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
