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
  // Local cart state (UI-only). Doesn't affect API/repository logic.
  final Map<int, int> _cartQtyByProductId = <int, int>{};
  List<VendorProductItem> _latestProducts = const [];
  late final AppCartService _cartService;
  bool _hydratedFromSharedCart = false;

  @override
  void initState() {
    super.initState();
    _cartService = Get.find<AppCartService>();
  }

  void _addToCart(VendorProductItem product) {
    setState(() {
      _cartQtyByProductId.update(product.id, (v) => v + 1, ifAbsent: () => 1);
    });
    _syncSharedCart();
  }

  void _removeFromCart(VendorProductItem product) {
    setState(() {
      final current = _cartQtyByProductId[product.id] ?? 0;
      if (current <= 1) {
        _cartQtyByProductId.remove(product.id);
      } else {
        _cartQtyByProductId[product.id] = current - 1;
      }
    });
    _syncSharedCart();
  }

  int get _cartCount =>
      _cartQtyByProductId.values.fold<int>(0, (sum, v) => sum + v);

  double _cartTotal(List<VendorProductItem> allProducts) {
    final priceById = <int, double>{};
    for (final p in allProducts) {
      if (p.price != null) priceById[p.id] = p.price!;
    }

    double total = 0;
    _cartQtyByProductId.forEach((id, qty) {
      total += (priceById[id] ?? 0) * qty;
    });
    return total;
  }

  List<CheckoutCartItem> _buildCheckoutItems(
    List<VendorProductItem> allProducts,
  ) {
    final byId = <int, VendorProductItem>{for (final p in allProducts) p.id: p};
    final list = <CheckoutCartItem>[];

    _cartQtyByProductId.forEach((productId, qty) {
      final product = byId[productId];
      if (product == null || qty <= 0) return;
      list.add(
        CheckoutCartItem(
          productId: product.id,
          name: product.name,
          image: product.image,
          description: product.description,
          unitPrice: product.price,
          quantity: qty,
        ),
      );
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
      _cartQtyByProductId[item.productId] = item.quantity;
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
            return const Center(child: Text('لا توجد قائمة'));
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
                      onShare: () {},
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
                            label: 'التقييم',
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: _InfoStatCard(
                            icon: Icons.access_time_rounded,
                            iconColor: AppColors.primary,
                            value: '20-30',
                            label: 'دقيقة للتوصيل',
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
                      const Text(
                        'لا توجد منتجات',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    else
                      ...products.map(
                        (p) => _MenuProductTile(
                          product: p,
                          qty: _cartQtyByProductId[p.id] ?? 0,
                          onAdd: () => _addToCart(p),
                          onRemove: () => _removeFromCart(p),
                        ),
                      ),
                  ],
                ),
              ),
              if (_cartCount > 0)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: _CartBar(
                    count: _cartCount,
                    total: total,
                    onTap: () {
                      final checkoutItems = _buildCheckoutItems(data.products);
                      if (checkoutItems.isEmpty) return;
                      _cartService.setCart(
                        vendorId: widget.vendorId,
                        items: checkoutItems,
                      );
                      Get.to(
                        () => OrderCheckoutScreen(
                          token: widget.token,
                          vendorId: widget.vendorId,
                          items: checkoutItems,
                        ),
                      );
                    },
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
            child: const Icon(Icons.ios_share_outlined, size: 18),
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
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _MenuProductTile({
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Row(
                  children: [
                    Text(
                      product.price == null
                          ? '-'
                          : '\$${product.price!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (qty == 0)
                      InkWell(
                        onTap: onAdd,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x22000000),
                                blurRadius: 10,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFD8B0)),
                        ),
                        child: Row(
                          children: [
                            _QtyActionButton(
                              icon: Icons.remove,
                              onTap: onRemove,
                            ),
                            SizedBox(
                              width: 26,
                              child: Text(
                                '$qty',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            _QtyActionButton(icon: Icons.add, onTap: onAdd),
                          ],
                        ),
                      ),
                  ],
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
    );
  }
}

class _QtyActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int count;
  final double total;
  final VoidCallback onTap;

  const _CartBar({
    required this.count,
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
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'عرض السلة',
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

String _sectionTitleForSelectedCategory({
  required List<VendorProductsCategory> categories,
  required int? selectedCategoryId,
}) {
  if (selectedCategoryId == null) return 'الأطباق الأكثر طلباً';
  final match = categories.firstWhereOrNull((c) => c.id == selectedCategoryId);
  if (match == null) return 'الأطباق';
  return match.name;
}
