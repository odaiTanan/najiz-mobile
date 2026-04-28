import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/data/models/vendor_products_model.dart';
import 'package:najiz_go_express/features/home/controllers/restaurant_vendor_products_controller.dart';
import 'package:najiz_go_express/features/home/models/checkout_cart_item.dart';
import 'package:najiz_go_express/features/home/views/order_checkout_screen.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

class RestaurantVendorProductsScreen extends StatefulWidget {
  final String? token;
  final int vendorId;

  const RestaurantVendorProductsScreen({
    super.key,
    required this.token,
    required this.vendorId,
  });

  @override
  State<RestaurantVendorProductsScreen> createState() =>
      _RestaurantVendorProductsScreenState();
}

class _RestaurantVendorProductsScreenState
    extends State<RestaurantVendorProductsScreen> {
  final Map<int, CheckoutCartItem> _cartItemsByProductId =
      <int, CheckoutCartItem>{};
  List<VendorProductItem> _latestProducts = const [];
  late final AppCartService _cartService;
  bool _hydratedFromSharedCart = false;

  @override
  void initState() {
    super.initState();
    _cartService = Get.find<AppCartService>();
  }

  double _cartTotal(List<VendorProductItem> allProducts) {
    final items = _buildCheckoutItems(allProducts);
    return items.fold<double>(0, (sum, item) => sum + item.lineTotal);
  }

  List<CheckoutCartItem> _buildCheckoutItems(
    List<VendorProductItem> allProducts,
  ) {
    final byId = <int, VendorProductItem>{for (final p in allProducts) p.id: p};
    final list = <CheckoutCartItem>[];

    _cartItemsByProductId.forEach((productId, cartItem) {
      if (!byId.containsKey(productId)) return;
      list.add(cartItem);
    });

    return list;
  }

  void _hydrateFromSharedCartIfNeeded(List<VendorProductItem> allProducts) {
    if (_hydratedFromSharedCart) return;
    _hydratedFromSharedCart = true;
    if (_cartService.vendorId.value != widget.vendorId ||
        _cartService.items.isEmpty) {
      return;
    }

    final validProducts = {for (final p in allProducts) p.id: p};
    for (final item in _cartService.items) {
      if (!validProducts.containsKey(item.productId)) continue;
      _cartItemsByProductId[item.productId] = item;
    }
  }

  void _syncSharedCart() {
    final items = _buildCheckoutItems(_latestProducts);
    if (items.isEmpty) {
      _cartService.clear();
      return;
    }
    _cartService.setCart(vendorId: widget.vendorId, items: items);
  }

  Future<void> _openProductCustomizationSheet(VendorProductItem product) async {
    final selected = await showModalBottomSheet<_SelectedProductPayload>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductCustomizationSheet(product: product),
    );
    if (selected == null) return;

    setState(() {
      _cartItemsByProductId[product.id] = CheckoutCartItem(
        productId: product.id,
        name: product.name,
        image: product.image,
        description: product.description,
        unitPrice: product.price,
        quantity: selected.productQuantity,
        note: selected.note,
        extras: selected.extras
            .map(
              (extra) => CheckoutCartExtraItem(
                extraId: extra.id,
                name: extra.name,
                price: extra.price,
                quantity: 1,
              ),
            )
            .toList(growable: false),
      );
    });
    _syncSharedCart();
    Get.snackbar('تمت الإضافة', '${product.name} أضيف إلى السلة');
  }

  void _openCheckout(List<VendorProductItem> allProducts) {
    final checkoutItems = _buildCheckoutItems(allProducts);
    if (checkoutItems.isEmpty) return;
    _cartService.setCart(vendorId: widget.vendorId, items: checkoutItems);
    Get.to(
      () => OrderCheckoutScreen(
        token: widget.token,
        vendorId: widget.vendorId,
        items: checkoutItems,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authHeaders = widget.token == null || widget.token!.trim().isEmpty
        ? <String, String>{}
        : <String, String>{'Authorization': 'Bearer ${widget.token}'};

    final controller = Get.put(
      RestaurantVendorProductsController(
        token: widget.token,
        vendorId: widget.vendorId,
      ),
      tag: 'vendor-menu-${widget.vendorId}',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value &&
              controller.vendorProducts.value == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (controller.errorMessage.value != null &&
              controller.vendorProducts.value == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  controller.errorMessage.value!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = controller.vendorProducts.value;
          if (data == null) {
            return Center(child: Text('services.noMenu'.tr));
          }

          final products = controller.filteredProducts;
          _latestProducts = data.products;
          final total = _cartTotal(data.products);
          _hydrateFromSharedCartIfNeeded(data.products);

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  children: [
                    _TopBarTitle(
                      title: data.vendor.name,
                      onBack: () => Get.back(),
                      onShare: () => _openCheckout(data.products),
                    ),
                    const SizedBox(height: 12),
                    _HeroImageCard(
                      imageUrl: data.vendor.image ?? data.vendor.logo,
                      headers: authHeaders,
                      title: data.vendor.name,
                      subtitle: data.vendor.description ?? '',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _InfoStatCard(
                            icon: Icons.star_rounded,
                            iconColor: AppColors.primary,
                            value: (data.vendor.rating ?? 0).toStringAsFixed(1),
                            label: 'services.rating'.tr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoStatCard(
                            icon: Icons.access_time_rounded,
                            iconColor: AppColors.primary,
                            value: '20-30',
                            label: 'services.minutesDelivery'.tr,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _MenuCategoryPills(
                      categories: data.categories,
                      selectedCategoryId: controller.selectedCategoryId.value,
                      onSelectCategory: controller.selectCategory,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _sectionTitleForSelectedCategory(
                        categories: data.categories,
                        selectedCategoryId: controller.selectedCategoryId.value,
                      ),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (products.isEmpty)
                      Text(
                        'services.noProducts'.tr,
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    else
                      ...products.map(
                        (p) => _MenuProductTile(
                          product: p,
                          onTap: () => _openProductCustomizationSheet(p),
                        ),
                      ),
                  ],
                ),
              ),
              if (_cartItemsByProductId.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _CartBar(
                    total: total,
                    onTap: () => _openCheckout(data.products),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _TopBarTitle extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;

  const _TopBarTitle({
    required this.title,
    required this.onBack,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: onShare,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEDEDED)),
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 18),
          ),
        ),
      ],
    );
  }
}

class _HeroImageCard extends StatelessWidget {
  final String? imageUrl;
  final Map<String, String> headers;
  final String title;
  final String subtitle;

  const _HeroImageCard({
    required this.imageUrl,
    required this.headers,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          SizedBox(
            height: 210,
            width: double.infinity,
            child: NetworkImageWithFallback(
              url: imageUrl,
              fit: BoxFit.cover,
              headers: headers,
            ),
          ),
          Container(
            height: 210,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xB20D253C), Color(0x220D253C)],
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFEDEDED),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _InfoStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuCategoryPills extends StatelessWidget {
  final List<VendorProductsCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<int?> onSelectCategory;

  const _MenuCategoryPills({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill({
      required String text,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFFFE4CC) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFC38A)
                  : const Color(0xFFEDEDED),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      );
    }

    final items = <Widget>[
      pill(
        text: 'الكل',
        selected: selectedCategoryId == null,
        onTap: () => onSelectCategory(null),
      ),
      ...categories.map((c) {
        return pill(
          text: c.name,
          selected: selectedCategoryId == c.id,
          onTap: () => onSelectCategory(c.id),
        );
      }),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => items[i],
      ),
    );
  }
}

class _MenuProductTile extends StatelessWidget {
  final VendorProductItem product;
  final VoidCallback onTap;

  const _MenuProductTile({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEDED)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (product.description != null &&
                      product.description!.trim().isNotEmpty)
                    Text(
                      product.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    product.price == null ? '-' : '\$${product.price!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 74,
                height: 74,
                child: NetworkImageWithFallback(
                  url: product.image,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final double total;
  final VoidCallback onTap;

  const _CartBar({
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              'متابعة الطلب',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              '\$${total.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedProductPayload {
  final int productQuantity;
  final List<VendorProductExtra> extras;
  final String? note;

  const _SelectedProductPayload({
    required this.productQuantity,
    required this.extras,
    this.note,
  });
}

class _ProductCustomizationSheet extends StatefulWidget {
  final VendorProductItem product;

  const _ProductCustomizationSheet({required this.product});

  @override
  State<_ProductCustomizationSheet> createState() => _ProductCustomizationSheetState();
}

class _ProductCustomizationSheetState extends State<_ProductCustomizationSheet> {
  int _quantity = 1;
  final Set<int> _selectedExtraIds = <int>{};
  late final List<VendorProductExtra> _extras;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _extras = [...widget.product.activeExtras]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final extra in _extras.where((e) => e.isRequired)) {
      _selectedExtraIds.add(extra.id);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double get _basePrice => widget.product.price ?? 0;
  double get _extrasPrice => _extras
      .where((e) => _selectedExtraIds.contains(e.id))
      .fold<double>(0, (sum, e) => sum + e.price);
  double get _total => (_basePrice * _quantity) + _extrasPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFFF6F6F6),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD0D5DD),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 210,
                    child: NetworkImageWithFallback(
                      url: widget.product.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.1,
                  ),
                ),
                if ((widget.product.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    widget.product.description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '\$${_total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFEDEDED)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                            icon: const Icon(Icons.remove, color: AppColors.primary),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            onPressed: () => setState(() => _quantity++),
                            icon: const Icon(Icons.add, color: AppColors.primary),
                            iconSize: 18,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 26,
                              minHeight: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_extras.isNotEmpty) ...[
                  const Text(
                    'إضافات الصنف',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._extras.map((extra) {
                    final selected = _selectedExtraIds.contains(extra.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? const Color(0xFFFFC38A) : const Color(0xFFEDEDED),
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: selected,
                            onChanged: extra.isRequired
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedExtraIds.add(extra.id);
                                      } else {
                                        _selectedExtraIds.remove(extra.id);
                                      }
                                    });
                                  },
                          ),
                          Expanded(
                            child: Text(
                              extra.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '\$${extra.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                const Text(
                  'ملاحظات إضافية',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLength: 100,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'اكتب ملاحظتك هنا (اختياري)',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEDEDED)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFEDEDED)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final selectedExtras = _extras
                            .where((e) => _selectedExtraIds.contains(e.id))
                            .toList(growable: false);
                        Navigator.of(context).pop(
                          _SelectedProductPayload(
                            productQuantity: _quantity,
                            extras: selectedExtras,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.96, end: 1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'أضف إلى السلة  \$${_total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _sectionTitleForSelectedCategory({
  required List<VendorProductsCategory> categories,
  required int? selectedCategoryId,
}) {
  if (selectedCategoryId == null) return 'services.topDishes'.tr;
  final match = categories.firstWhereOrNull((c) => c.id == selectedCategoryId);
  if (match == null) return 'services.dishes'.tr;
  return match.name;
}
