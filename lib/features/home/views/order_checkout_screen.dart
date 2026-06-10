import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/core/network/home_api_connectivity.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/core/widgets/save_cart_dialog.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/controllers/order_checkout_controller.dart';
import 'package:najiz_go_express/features/home/models/checkout_cart_item.dart';
import 'package:najiz_go_express/features/home/views/order_tracking_screen.dart';
import 'package:najiz_go_express/features/home/widgets/coupon_picker_sheet.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

class OrderCheckoutScreen extends StatelessWidget {
  final String? token;
  final int vendorId;
  final List<CheckoutCartItem> items;
  final int? serviceId;

  const OrderCheckoutScreen({
    super.key,
    required this.token,
    required this.vendorId,
    required this.items,
    this.serviceId,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = Get.put(
      OrderCheckoutController(token: token, vendorId: vendorId, items: items),
      tag: 'checkout-$vendorId',
    );

    Future<bool> _confirmLeaveCheckoutIfNeeded() async {
      if (controller.isPlacingOrder.value) return false;
      if (controller.orderPlaced.value) return true;

      if (!Get.isRegistered<AppCartService>()) return true;
      final cart = Get.find<AppCartService>();
      if (cart.vendorId.value != vendorId || !cart.hasItems) return true;

      final shouldSave = await showSaveCartDialog(context);
      if (shouldSave == null) return false;

      if (shouldSave) {
        await cart.persistCurrentCart();
        cart.clear();
      } else {
        await cart.clearSavedCart();
      }

      return true;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) {
          final shouldPop = await _confirmLeaveCheckoutIfNeeded();
          if (shouldPop) Get.back();
        }
      },
      child: Scaffold(
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  Expanded(
                    child: Text(
                      'checkout.title'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'checkout.deliveryAddress'.tr,
                actionText: 'checkout.edit'.tr,
                onActionTap: () => _openLocationPicker(context, controller),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.customAddressName.value,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'checkout.orderItems'.tr,
                child: Column(
                  children: items
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SizedBox(
                                  width: 56,
                                  height: 56,
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
                                      '${item.quantity}x ${item.name}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    if (item.description != null &&
                                        item.description!.trim().isNotEmpty)
                                      Text(
                                        item.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 12,
                                        ),
                                      ),
                                    if (item.extras.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      ...item.extras.map(
                                        (extra) => Text(
                                          '+ ${extra.name} (${_price(extra.price)})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                    if ((item.note ?? '').trim().isNotEmpty)
                                      Text(
                                        'checkout.itemNote'.trParams({'note': item.note ?? ''}),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: cs.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _price(item.lineTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'checkout.addCoupon'.tr,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Color.alphaBlend(
                          const Color(0x33FF8A00),
                          cs.surface,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'checkout.saveOnOrder'.tr,
                              style: TextStyle(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'checkout.selectCoupon'.tr,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                            onSelected: (selectedCode) async {
                              try {
                                await controller.applyCoupon(selectedCode);
                              } on HomeApiException catch (e) {
                                AppSnackbar.show('common.error'.tr, e.message);
                              }
                            },
                            itemBuilder: (menuContext) {
                              final menuCs = Theme.of(menuContext).colorScheme;
                              final coupons = controller.availableCoupons;
                              if (coupons.isEmpty) {
                                return [
                                  PopupMenuItem<String>(
                                    enabled: false,
                                    value: '',
                                    child: Text(
                                      'checkout.noActiveCoupons'.tr,
                                      style: TextStyle(
                                        color: menuCs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ];
                              }
                              return coupons
                                  .map(
                                    (coupon) => PopupMenuItem<String>(
                                      value: coupon.code,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              coupon.code,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: menuCs.onSurface,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            coupon.valueLabel,
                                            style: TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false);
                            },
                          ),
                          Flexible(
                            child: TextButton(
                              onPressed: () async {
                                final selected = await showCouponPickerSheet(
                                  context: context,
                                  coupons: controller.availableCoupons,
                                  initialCode: controller.appliedCouponCode.value,
                                );
                                if (selected == null || selected.trim().isEmpty) {
                                  return;
                                }
                                try {
                                  await controller.applyCoupon(selected);
                                } on HomeApiException catch (e) {
                                  AppSnackbar.show('errors.generic'.tr, e.message);
                                }
                              },
                              child: Text('checkout.writeManually'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (controller.appliedCouponCode.value != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.discount_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controller.appliedCouponCode.value!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => controller.clearCoupon(),
                              icon: const Icon(Icons.close, size: 18),
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'checkout.paymentMethod'.tr,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.payments_outlined,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'checkout.cashPayment'.tr,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            'checkout.payOnDelivery'.tr,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () => controller.unavailabilityOptions.isEmpty
                    ? const SizedBox.shrink()
                    : _SectionCard(
                        title: 'checkout.unavailabilityTitle'.tr,
                        child: RadioGroup<String>(
                          groupValue: controller.selectedUnavailabilityAction.value,
                          onChanged: (value) {
                            if (value == null) return;
                            controller.selectUnavailabilityAction(value);
                          },
                          child: Column(
                            children: controller.unavailabilityOptions
                                .map(
                                  (option) => RadioListTile<String>(
                                    value: option.value,
                                    contentPadding: EdgeInsets.zero,
                                    activeColor: AppColors.primary,
                                    title: Text(
                                      option.label,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _resolveUnavailabilityDescription(
                                        original: option.description,
                                        serviceId: serviceId,
                                      ),
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              _InvoiceCard(controller: controller),
              const SizedBox(height: 16),
              Obx(
                () => SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed:
                        controller.isPlacingOrder.value ||
                            !controller.hasCalculatedPricing.value
                        ? null
                        : () async {
                            await AuthGuardService.runOrRequestLogin(
                              onAuthenticated: (authToken) async {
                                controller.setAuthToken(authToken);
                                try {
                                  final placed = await controller.placeOrder();
                                  if (Get.isRegistered<AppCartService>()) {
                                    await Get.find<AppCartService>()
                                        .clearSavedCart();
                                  }
                                  Get.off(
                                    () => OrderTrackingScreen(
                                      token: authToken,
                                      orderId: placed.orderId,
                                      orderNumber: placed.orderNumber,
                                      initialStatus: placed.status,
                                      initialDispatchStatus:
                                          placed.dispatchStatus,
                                    ),
                                  );
                                } on HomeApiException catch (e) {
                                  if (e.isConnectivityIssue) {
                                    showNoInternetGateIfNeeded(
                                      e,
                                      retry: () async {
                                        final placed =
                                            await controller.placeOrder();
                                        if (Get.isRegistered<AppCartService>()) {
                                          await Get.find<AppCartService>()
                                              .clearSavedCart();
                                        }
                                        Get.off(
                                          () => OrderTrackingScreen(
                                            token: authToken,
                                            orderId: placed.orderId,
                                            orderNumber: placed.orderNumber,
                                            initialStatus: placed.status,
                                            initialDispatchStatus:
                                                placed.dispatchStatus,
                                          ),
                                        );
                                      },
                                    );
                                    return;
                                  }
                                  AppSnackbar.show('orders.error'.tr, e.message);
                                } catch (_) {
                                  AppSnackbar.show(
                                    'orders.error'.tr,
                                    'checkout.confirmOrderFailed'.tr,
                                  );
                                }
                              },
                              message: 'checkout.loginRequired'.tr,
                            );
                          },
                    child: controller.isPlacingOrder.value
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'checkout.confirmOrder'.tr,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.shopping_bag_outlined, size: 18),
                            ],
                          ),
                  ),
                ),
              ),
              if (controller.errorMessage.value != null) ...[
                const SizedBox(height: 10),
                Text(
                  controller.errorMessage.value!,
                  style: TextStyle(color: cs.error),
                ),
              ],
            ],
          );
        }),
      ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
    this.actionText,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (actionText != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onActionTap,
                  child: Text(
                    actionText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final OrderCheckoutController controller;

  const _InvoiceCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          _row(
            context,
            'checkout.subtotal'.tr,
            _priceOrPlaceholder(
              value: controller.subtotal.value,
              hasCalculatedPricing: controller.hasCalculatedPricing.value,
            ),
          ),
          const SizedBox(height: 8),
          _row(
            context,
            'checkout.deliveryFee'.tr,
            _priceOrPlaceholder(
              value: controller.deliveryFee.value,
              hasCalculatedPricing: controller.hasCalculatedPricing.value,
            ),
          ),
          const SizedBox(height: 8),
          _row(
            context,
            'checkout.serviceFee'.tr,
            _priceOrPlaceholder(
              value: controller.serviceFee.value,
              hasCalculatedPricing: controller.hasCalculatedPricing.value,
            ),
          ),
          const SizedBox(height: 8),
          if (controller.appliedCouponCode.value != null)
            _row(
              context,
              'checkout.couponDiscount'.tr,
              controller.hasCalculatedPricing.value
                  ? '-${_price(controller.couponDiscount.value)}'
                  : '--',
            ),
          const Divider(height: 22),
          _row(
            context,
            'checkout.total'.tr,
            _priceOrPlaceholder(
              value: controller.total.value,
              hasCalculatedPricing: controller.hasCalculatedPricing.value,
            ),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String title, String value,
      {bool isTotal = false}) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isTotal ? cs.onSurface : cs.onSurfaceVariant,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
              fontSize: isTotal ? 22 : 14,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: isTotal ? AppColors.primary : cs.onSurface,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
              fontSize: isTotal ? 22 : 14,
            ),
          ),
        ),
      ],
    );
  }
}

String _price(double value) => '\$${value.toStringAsFixed(2)}';
String _priceOrPlaceholder({
  required double value,
  required bool hasCalculatedPricing,
}) => hasCalculatedPricing ? _price(value) : '--';

String _resolveUnavailabilityDescription({
  required String original,
  required int? serviceId,
}) {
  final normalized = original.trim();
  if (normalized.isEmpty) return normalized;
  if (serviceId != 1 && serviceId != 3) {
    if (normalized.contains('المطعم/المتجر')) return 'checkout.willContactYou'.tr;
    return normalized;
  }

  final entity = serviceId == 3 ? 'checkout.store'.tr : 'checkout.restaurant'.tr;
  var result = normalized;
  result = result.replaceAll(RegExp(r'المطعم\s*/\s*المتجر'), entity);
  result = result.replaceAll(RegExp(r'المطعم\s*-\s*المتجر'), entity);
  result = result.replaceAll(RegExp(r'المتجر\s*/\s*المطعم'), entity);
  result = result.replaceAll(RegExp(r'المتجر\s*-\s*المطعم'), entity);
  return result;
}

Future<void> _openLocationPicker(
  BuildContext context,
  OrderCheckoutController controller,
) async {
  final lat = double.tryParse(controller.lat.value) ?? 33.5138;
  final lng = double.tryParse(controller.lng.value) ?? 36.2765;
  final selected = await AppPopupDialog.show<ll.LatLng>(
    context: context,
    builder: (_) => _MapPickerDialog(initialPoint: ll.LatLng(lat, lng)),
  );
  if (selected == null) return;
  await controller.updateDeliveryLocation(
    latitude: selected.latitude,
    longitude: selected.longitude,
  );
}

class _MapPickerDialog extends StatefulWidget {
  final ll.LatLng initialPoint;

  const _MapPickerDialog({required this.initialPoint});

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late ll.LatLng _selectedPoint;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        height: 420,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'checkout.selectDeliveryLocation'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.initialPoint.latitude, widget.initialPoint.longitude),
                  zoom: 14,
                ),
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (point) {
                  setState(() {
                    _selectedPoint = ll.LatLng(point.latitude, point.longitude);
                  });
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('selected'),
                    position: LatLng(_selectedPoint.latitude, _selectedPoint.longitude),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                  ),
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedPoint),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text('checkout.confirmLocation'.tr),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
