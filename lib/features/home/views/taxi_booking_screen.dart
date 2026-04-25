import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/data/models/taxi_pricing_model.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/controllers/taxi_booking_controller.dart';
import 'package:najiz_go_express/features/home/views/transport_order_tracking_screen.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';

class TaxiBookingScreen extends StatelessWidget {
  final String? token;

  const TaxiBookingScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      TaxiBookingController(token: token),
      tag: 'taxi-booking',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F7),
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 0,
        serviceText: 'تكسي',
        serviceIcon: Icons.local_taxi_outlined,
        serviceActive: true,
        onServiceTap: () {},
        onTap: (index) =>
            MainBottomNav.onTap(index: index, currentIndex: -1, token: token),
      ),
      body: SafeArea(
        child: Obx(() {
          final pricing = controller.pricing.value;

          return Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    _OpenStreetMap(
                      pickupLat: controller.pickupLat.value,
                      pickupLng: controller.pickupLng.value,
                      dropoffLat: controller.dropoffLat.value,
                      dropoffLng: controller.dropoffLng.value,
                      selectingPickup: controller.selectingPickupOnMap.value,
                      onMapTap: (lat, lng) =>
                          controller.applyMapSelection(lat: lat, lng: lng),
                    ),
                    Positioned(
                      top: 10,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          _CircleAction(
                            icon: Icons.arrow_back,
                            onTap: () => Get.back(),
                          ),
                          const SizedBox(width: 10),
                          const Spacer(),
                          _CircleAction(
                            icon: Icons.person_outline,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 62,
                      left: 14,
                      right: 14,
                      child: Column(
                        children: [
                          _LocationCard(
                            title: 'موقع الانطلاق',
                            subtitle: controller.pickupAddress.value,
                            selected: controller.selectingPickupOnMap.value,
                            onTap: () => _showLocationActionSheet(
                              context: context,
                              controller: controller,
                              isPickup: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _LocationCard(
                            title: 'الوجهة',
                            subtitle:
                                controller.dropoffAddress.value ??
                                'اضغط ثم اختر الوجهة من الخريطة',
                            selected: !controller.selectingPickupOnMap.value,
                            onTap: () => _showLocationActionSheet(
                              context: context,
                              controller: controller,
                              isPickup: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3E6EB),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'اختر الرحلة',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (controller.isLoading.value)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: CircularProgressIndicator(),
                      )
                    else if (controller.errorMessage.value != null)
                      Text(
                        controller.errorMessage.value!,
                        style: const TextStyle(color: AppColors.error),
                      )
                    else if (pricing == null || pricing.categories.isEmpty)
                      const Text(
                        'لا توجد فئات تاكسي متاحة',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    else
                      ...pricing.categories.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaxiCategoryCard(
                            category: category,
                            selected:
                                controller.selectedCategoryId.value ==
                                category.vehicleCategory.id,
                            onTap: () => controller.selectCategory(
                              category.vehicleCategory.id,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'الدفع: نقداً',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Obx(
                        () => ElevatedButton(
                          onPressed: controller.isPlacingOrder.value
                              ? null
                              : () async {
                                  try {
                                    await AuthGuardService.runOrRequestLogin(
                                      onAuthenticated: (token) async {
                                        controller.setAuthToken(token);
                                        final order = await controller
                                            .confirmTaxiOrder();
                                        if (!context.mounted) return;
                                        _showFindingDriverPopup(
                                          context: context,
                                          message: 'تم إنشاء طلب التاكسي بنجاح',
                                          onTrackNow: () {
                                            Get.to(
                                              () =>
                                                  TransportOrderTrackingScreen(
                                                    token: token,
                                                    orderId: order.orderId,
                                                    orderNumber:
                                                        order.orderNumber,
                                                    initialStatus: order.status,
                                                    initialDispatchStatus:
                                                        order.dispatchStatus,
                                                    pickupLat: order.pickupLat,
                                                    pickupLng: order.pickupLng,
                                                    destinationLat:
                                                        order.destinationLat,
                                                    destinationLng:
                                                        order.destinationLng,
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } on HomeApiException catch (e) {
                                    Get.snackbar('خطأ', e.message);
                                  } catch (_) {
                                    Get.snackbar(
                                      'خطأ',
                                      'فشل تأكيد طلب التاكسي',
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: controller.isPlacingOrder.value
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'تأكيد ${controller.selectedCategory?.vehicleCategory.name ?? 'الرحلة'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 19,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

Future<void> _showLocationActionSheet({
  required BuildContext context,
  required TaxiBookingController controller,
  required bool isPickup,
}) async {
  final targetName = isPickup ? 'موقع الانطلاق' : 'الوجهة';
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 52,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.inputBorder,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  targetName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                _SheetActionTile(
                  icon: Icons.map_outlined,
                  title: 'حدد الموقع على الخريطة',
                  subtitle: 'اضغط على الخريطة لتحديد النقطة',
                  onTap: () {
                    controller.setMapSelectionMode(isPickup);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                const SizedBox(height: 10),
                _SheetActionTile(
                  icon: Icons.search,
                  title: 'ابحث عن موقع',
                  subtitle: 'بحث بالاسم داخل سوريا',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSearchLocationDialog(
                      context: context,
                      controller: controller,
                      asPickup: isPickup,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showSearchLocationDialog({
  required BuildContext context,
  required TaxiBookingController controller,
  required bool asPickup,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _TaxiSearchLocationDialog(controller: controller, asPickup: asPickup),
  );
}

class _TaxiSearchLocationDialog extends StatefulWidget {
  final TaxiBookingController controller;
  final bool asPickup;

  const _TaxiSearchLocationDialog({
    required this.controller,
    required this.asPickup,
  });

  @override
  State<_TaxiSearchLocationDialog> createState() =>
      _TaxiSearchLocationDialogState();
}

class _TaxiSearchLocationDialogState extends State<_TaxiSearchLocationDialog> {
  late final TextEditingController _textController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final query = _textController.text.trim();
    if (query.isEmpty) {
      Get.snackbar(
        'تنبيه',
        'اكتب اسم المنطقة أو الشارع أولًا',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final success = await widget.controller.searchAndSelectLocation(
      query: query,
      asPickup: widget.asPickup,
    );
    if (success) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final targetName = widget.asPickup ? 'موقع الانطلاق' : 'الوجهة';
      Get.snackbar(
        'تم تحديد $targetName',
        'تم العثور على الموقع وتثبيته بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } else {
      Get.snackbar(
        'خطأ',
        widget.controller.errorMessage.value ?? 'تعذر العثور على الموقع',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 150),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.search, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.asPickup ? 'ابحث عن موقع الانطلاق' : 'ابحث عن الوجهة',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'اكتب اسم المنطقة أو الشارع',
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: AppColors.inputBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'بحث',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenStreetMap extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final bool selectingPickup;
  final void Function(double lat, double lng) onMapTap;

  const _OpenStreetMap({
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.selectingPickup,
    required this.onMapTap,
  });

  @override
  State<_OpenStreetMap> createState() => _OpenStreetMapState();
}

class _OpenStreetMapState extends State<_OpenStreetMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant _OpenStreetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasPickupChanged =
        oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng;
    final hasDropoffChanged =
        oldWidget.dropoffLat != widget.dropoffLat ||
        oldWidget.dropoffLng != widget.dropoffLng;
    if (hasPickupChanged || hasDropoffChanged) {
      final target =
          widget.selectingPickup ||
              widget.dropoffLat == null ||
              widget.dropoffLng == null
          ? LatLng(widget.pickupLat, widget.pickupLng)
          : LatLng(widget.dropoffLat!, widget.dropoffLng!);
      _mapController.move(target, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = LatLng(widget.pickupLat, widget.pickupLng);
    final markers = <Marker>[
      Marker(
        point: LatLng(widget.pickupLat, widget.pickupLng),
        width: 42,
        height: 42,
        child: const _PinDot(color: Color(0xFF3B82F6), label: 'A'),
      ),
    ];
    if (widget.dropoffLat != null && widget.dropoffLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.dropoffLat!, widget.dropoffLng!),
          width: 42,
          height: 42,
          child: const _PinDot(color: Color(0xFFF97316), label: 'B'),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: mapCenter,
            initialZoom: 14,
            onTap: (_, point) =>
                widget.onMapTap(point.latitude, point.longitude),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.najiz_go_express',
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              widget.selectingPickup
                  ? 'اختر نقطة الانطلاق بالضغط على الخريطة'
                  : 'اختر الوجهة بالضغط على الخريطة',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PinDot extends StatelessWidget {
  final Color color;
  final String label;

  const _PinDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LocationCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE3E6EB),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapSearchCard extends StatefulWidget {
  final TaxiBookingController controller;
  final bool asPickup;
  final String hint;

  const _MapSearchCard({
    required this.controller,
    required this.asPickup,
    required this.hint,
  });

  @override
  State<_MapSearchCard> createState() => _MapSearchCardState();
}

class _MapSearchCardState extends State<_MapSearchCard> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E8EE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: (value) => widget.controller.searchAndSelectLocation(
                query: value,
                asPickup: widget.asPickup,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                border: InputBorder.none,
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            onPressed: () => widget.controller.searchAndSelectLocation(
              query: _textController.text,
              asPickup: widget.asPickup,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(36, 36),
              padding: EdgeInsets.zero,
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _TaxiCategoryCard extends StatelessWidget {
  final TaxiPricingCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _TaxiCategoryCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mins = (category.pricing.distanceKm * 1.5 + 2).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE6EAF0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.local_taxi_outlined,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.vehicleCategory.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$mins دقيقة • ${category.pricing.distanceKm.toStringAsFixed(2)} كم',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\$${category.pricing.estimatedPrice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: AppColors.textPrimary),
      ),
    );
  }
}

void _showFindingDriverPopup({
  required BuildContext context,
  required String message,
  required VoidCallback onTrackNow,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.radar, color: AppColors.primary, size: 34),
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'جاري البحث عن سائق',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Get.back();
                        Get.back();
                      },
                      child: const Text('لاحقًا'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        onTrackNow();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('تتبع الطلب'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
