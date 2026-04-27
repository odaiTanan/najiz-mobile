import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/app_cart_service.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/controllers/order_checkout_controller.dart';
import 'package:najiz_go_express/features/home/models/checkout_cart_item.dart';
import 'package:najiz_go_express/features/home/views/order_tracking_screen.dart';
import 'package:najiz_go_express/features/home/widgets/network_image_with_fallback.dart';

class OrderCheckoutScreen extends StatelessWidget {
  final String? token;
  final int vendorId;
  final List<CheckoutCartItem> items;

  const OrderCheckoutScreen({
    super.key,
    required this.token,
    required this.vendorId,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      OrderCheckoutController(token: token, vendorId: vendorId, items: items),
      tag: 'checkout-$vendorId',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
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
                  const Expanded(
                    child: Text(
                      'طلبي',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
              const SizedBox(height: 10),
              _SectionCard(
                title: 'عنوان التوصيل',
                actionText: 'تعديل',
                onActionTap: () => _openLocationPicker(context, controller),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E8),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${controller.lat.value}, ${controller.lng.value}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'عناصر الطلب',
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    if (item.description != null &&
                                        item.description!.trim().isNotEmpty)
                                      Text(
                                        item.description!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _price(item.lineTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
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
                title: 'طريقة الدفع',
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments_outlined,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الدفع نقداً',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'الدفع عند الاستلام',
                            style: TextStyle(
                              color: AppColors.textSecondary,
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
                                    Get.find<AppCartService>().clear();
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
                                  Get.snackbar('خطأ', e.message);
                                } catch (_) {
                                  Get.snackbar('خطأ', 'فشل تأكيد الطلب');
                                }
                              },
                              message: 'يرجى تسجيل الدخول لإكمال الطلب',
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
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'تأكيد الطلب',
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
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            ],
          );
        }),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (actionText != null)
                GestureDetector(
                  onTap: onActionTap,
                  child: Text(
                    actionText!,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        children: [
          _row(
            'المجموع الفرعي',
            _priceOrPlaceholder(
              value: controller.subtotal.value,
              hasCalculatedPricing: controller.hasCalculatedPricing.value,
            ),
          ),
          const SizedBox(height: 8),
          _row(
            'رسوم التوصيل',
            _priceOrPlaceholder(
              value: controller.deliveryFee.value,
              hasCalculatedPricing: controller.hasCalculatedPricing.value,
            ),
          ),
          const SizedBox(height: 8),
          _row(
            'رسوم الخدمة',
            _priceOrPlaceholder(
              value: controller.serviceFee.value,
              hasCalculatedPricing: controller.hasCalculatedPricing.value,
            ),
          ),
          const Divider(height: 22),
          _row(
            'الإجمالي',
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

  Widget _row(String title, String value, {bool isTotal = false}) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            fontSize: isTotal ? 22 : 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
            fontSize: isTotal ? 22 : 14,
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

Future<void> _openLocationPicker(
  BuildContext context,
  OrderCheckoutController controller,
) async {
  final lat = double.tryParse(controller.lat.value) ?? 33.5138;
  final lng = double.tryParse(controller.lng.value) ?? 36.2765;
  final selected = await showDialog<ll.LatLng>(
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
    return Dialog(
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
                  const Expanded(
                    child: Text(
                      'حدد موقع التوصيل',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
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
                  child: const Text('تأكيد الموقع'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
