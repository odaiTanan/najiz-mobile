import 'dart:async';

import 'package:flutter/material.dart';
import 'package:najiz_go_express/features/taxi/errors/taxi_api_exception.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/core/widgets/disconnect_dialog.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/features/taxi/models/taxi_pricing_model.dart';
import 'package:najiz_go_express/features/orders/repositories/orders_repository.dart';
import 'package:najiz_go_express/features/taxi/controllers/taxi_booking_controller.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/features/orders/views/transport_order_tracking_screen.dart';
import 'package:najiz_go_express/features/orders/widgets/coupon_picker_sheet.dart';
import 'package:najiz_go_express/core/navigation/home_bottom_bar.dart';
import 'package:najiz_go_express/core/navigation/main_bottom_nav.dart';
import 'package:najiz_go_express/features/orders/services/orders_dependencies.dart';
import 'package:najiz_go_express/core/services/order_dispatch_watcher.dart';
import 'package:najiz_go_express/core/utils/order_dispatch_utils.dart';
import 'package:najiz_go_express/core/widgets/no_driver_assigned_dialog.dart';
import 'package:najiz_go_express/core/peak_hour/widgets/peak_hour_price_notice.dart';

class TaxiBookingScreen extends StatelessWidget {
  final String? token;

  const TaxiBookingScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = Get.put(
      TaxiBookingController(token: token),
      tag: 'taxi-booking',
    );

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 0,
        serviceText: 'taxi.title'.tr,
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
                            icon: Icons.notifications_none_rounded,
                            onTap: AppRoutes.openNotifications,
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
                            title: 'taxi.departureLabel'.tr,
                            subtitle: controller.pickupAddress.value.isEmpty ? 'location.determining'.tr : controller.pickupAddress.value,
                            selected: controller.selectingPickupOnMap.value,
                            onTap: () => _showLocationActionSheet(
                              context: context,
                              controller: controller,
                              isPickup: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _LocationCard(
                            title: 'taxi.destinationLabel'.tr,
                            subtitle:
                                controller.dropoffAddress.value ??
                                'taxi.destinationHint'.tr,
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
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 54,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'taxi.chooseTripTitle'.tr,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: cs.onSurface,
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
                        style: TextStyle(color: cs.error),
                      )
                    else if (pricing == null || pricing.categories.isEmpty)
                      Text(
                        'taxi.setTripPrompt'.tr,
                        style: TextStyle(color: cs.onSurfaceVariant),
                      )
                    else
                      Obx(() {
                        final selectedId = controller.selectedCategoryId.value;
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: pricing.categories.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, index) {
                              final category = pricing.categories[index];
                              return _TaxiCategoryCard(
                                category: category,
                                selected:
                                    selectedId == category.vehicleCategory.id,
                                onTap: () => controller.selectCategory(
                                  category.vehicleCategory.id,
                                ),
                              );
                            },
                          ),
                        );
                      }),
                    Obx(
                      () => PeakHourPriceNotice(
                        visible: controller.selectedCategoryId.value != null,
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_offer_outlined,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controller.appliedCouponCode.value == null
                                    ? 'checkout.addCouponForTrip'.tr
                                    : 'checkout.couponLabel'.trParams({
                                        'code':
                                            controller.appliedCouponCode.value!,
                                      }),
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final selected = await showCouponPickerSheet(
                                  context: context,
                                  coupons: controller.availableCoupons,
                                  initialCode: controller.appliedCouponCode.value,
                                );
                                if (selected == null ||
                                    selected.trim().isEmpty) {
                                  return;
                                }
                                try {
                                  await controller.applyCoupon(selected);
                                } on TaxiApiException catch (e) {
                                  AppSnackbar.show('common.error'.tr, e.message);
                                }
                              },
                              child: Text('checkout.addCoupon'.tr),
                            ),
                            if (controller.appliedCouponCode.value != null)
                              IconButton(
                                onPressed: () => controller.clearCoupon(),
                                icon: const Icon(Icons.close, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'checkout.cashPaymentLabel'.tr,
                          style: TextStyle(
                            color: cs.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Obx(() {
                      final selected = controller.selectedCategory;
                      if (selected == null ||
                          controller.appliedCouponCode.value == null) {
                        return const SizedBox.shrink();
                      }
                      final discountedPrice =
                          selected.pricing.estimatedPrice -
                          controller.couponDiscount.value;
                      final discountAmount =
                          controller.couponDiscount.value.toStringAsFixed(2);
                      final discountedTotal =
                          discountedPrice.toStringAsFixed(2);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'checkout.couponDiscount'.tr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '-$discountAmount',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'checkout.totalAfterDiscount'.trParams({
                                  'amount': discountedTotal,
                                }),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
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
                                          token: token,
                                          orderId: order.orderId,
                                          initialStatus: order.status,
                                          initialDispatchStatus:
                                              order.dispatchStatus,
                                          onTrackNow: () {
                                            Get.to(
                                              () =>
                                                  TransportOrderTrackingScreen(
                                                    token: token,
                                                    orderId: order.orderId,
                                                    orderNumber:
                                                        order.orderNumber,
                                                    orderType: 'taxi',
                                                    initialStatus: order.status,
                                                    initialDispatchStatus:
                                                        order.dispatchStatus,
                                                    pickupLat: order.pickupLat,
                                                    pickupLng: order.pickupLng,
                                                    destinationLat:
                                                        order.destinationLat,
                                                    destinationLng:
                                                        order.destinationLng,
                                                    initialTripDistanceKm:
                                                        order.estimatedDistanceKm,
                                                  ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } on TaxiApiException catch (e) {
                                    AppSnackbar.show('errors.generic'.tr, e.message);
                                  } catch (e) {
                                    AppSnackbar.show(
                                      'errors.generic'.tr,
                                      'taxi.confirmOrderFailed'.trParams({'error': e.toString()}),
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
                                  'taxi.confirmBooking'.trParams({'name': controller.selectedCategory?.vehicleCategory.name ?? 'taxi.tripLabel'.tr}),
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
  final targetName = isPickup ? 'taxi.departureLabel'.tr : 'taxi.destinationLabel'.tr;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      final sheetCs = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: sheetCs.surface,
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
                      color: sheetCs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  targetName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: sheetCs.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                _SheetActionTile(
                  icon: Icons.map_outlined,
                  title: 'taxi.pickOnMap'.tr,
                  subtitle: 'taxi.tapMapHint'.tr,
                  onTap: () {
                    controller.setMapSelectionMode(isPickup);
                    Navigator.of(sheetContext).pop();
                  },
                ),
                const SizedBox(height: 10),
                _SheetActionTile(
                  icon: Icons.search,
                  title: 'location.searchPlaceholder'.tr,
                  subtitle: 'location.searchHint'.tr,
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: cs.onSurfaceVariant,
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
  await AppPopupDialog.show<void>(
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
  Timer? _debounceTimer;
  bool _isSubmitting = false;
  bool _isLoadingSuggestions = false;
  List<PlaceSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final query = _textController.text.trim();
    if (query.isEmpty) {
      AppSnackbar.show(
        'تنبيه',
        'اكتب اسم المنطقة أو الشارع أولًا',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final success = await _selectByQuery(query);
    if (success) {
      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      final targetName = widget.asPickup ? 'موقع الانطلاق' : 'الوجهة';
      AppSnackbar.show(
        'تم تحديد $targetName',
        'تم العثور على الموقع وتثبيته بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } else {
      AppSnackbar.show(
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

  Future<bool> _selectByQuery(String query) async {
    final suggestions = await widget.controller.fetchLocationSuggestions(
      query: query,
    );
    if (suggestions.isNotEmpty) {
      return widget.controller.selectSuggestion(
        suggestion: suggestions.first,
        asPickup: widget.asPickup,
      );
    }
    return widget.controller.searchAndSelectLocation(
      query: query,
      asPickup: widget.asPickup,
    );
  }

  Future<void> _onQueryChanged(String value) async {
    _debounceTimer?.cancel();
    final query = value.trim();
    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _isLoadingSuggestions = false;
          _suggestions = const [];
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = true);
      final results = await widget.controller.fetchLocationSuggestions(
        query: query,
      );
      if (!mounted) return;
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = results;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final success = await widget.controller.selectSuggestion(
      suggestion: suggestion,
      asPickup: widget.asPickup,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context, rootNavigator: true).pop();
      final targetName = widget.asPickup ? 'موقع الانطلاق' : 'الوجهة';
      AppSnackbar.show(
        'تم تحديد $targetName',
        'تم العثور على الموقع وتثبيته بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } else {
      AppSnackbar.show(
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
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
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
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.search, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.asPickup ? 'ابحث عن موقع الانطلاق' : 'ابحث عن الوجهة',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'اكتب اسم المنطقة أو الشارع',
                prefixIcon: const Icon(Icons.location_on_outlined),
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
              ),
            ),
            if (_isLoadingSuggestions) ...[
              const SizedBox(height: 10),
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (_suggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: cs.outlineVariant),
                  itemBuilder: (listContext, index) {
                    final suggestion = _suggestions[index];
                    final detailText = suggestion.secondaryText.isNotEmpty
                        ? suggestion.secondaryText
                        : suggestion.description;
                    final distanceKm = suggestion.distanceMeters == null
                        ? null
                        : suggestion.distanceMeters! / 1000.0;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: cs.onSurfaceVariant,
                      ),
                      title: Text(
                        suggestion.primaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      trailing: distanceKm == null
                          ? null
                          : Text(
                              '${distanceKm.toStringAsFixed(distanceKm >= 10 ? 0 : 1)} كم',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      onTap: _isSubmitting
                          ? null
                          : () => _selectSuggestion(suggestion),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: BorderSide(color: cs.outlineVariant),
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
  GoogleMapController? _mapController;
  bool _showSelectionPin = false;
  Timer? _pinHintTimer;

  void _showSelectionPinHint() {
    _pinHintTimer?.cancel();
    if (!mounted) return;
    setState(() => _showSelectionPin = true);
    _pinHintTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showSelectionPin = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _showSelectionPinHint();
  }

  @override
  void didUpdateWidget(covariant _OpenStreetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectingPickup != widget.selectingPickup) {
      _showSelectionPinHint();
    }
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
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
    }
  }

  @override
  void dispose() {
    _pinHintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mapCenter = LatLng(widget.pickupLat, widget.pickupLng);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickupLat, widget.pickupLng),
        infoWindow: const InfoWindow(title: 'A'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
    };
    if (widget.dropoffLat != null && widget.dropoffLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(widget.dropoffLat!, widget.dropoffLng!),
          infoWindow: const InfoWindow(title: 'B'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }
    final polylines = <Polyline>{
      if (widget.dropoffLat != null && widget.dropoffLng != null)
        Polyline(
          polylineId: const PolylineId('route'),
          points: [
            LatLng(widget.pickupLat, widget.pickupLng),
            LatLng(widget.dropoffLat!, widget.dropoffLng!),
          ],
          width: 4,
          color: cs.outline,
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: mapCenter, zoom: 14),
          onMapCreated: (controller) => _mapController = controller,
          myLocationButtonEnabled: false,
          compassEnabled: false,
          zoomControlsEnabled: false,
          markers: markers,
          polylines: polylines,
          onTap: (point) => widget.onMapTap(point.latitude, point.longitude),
        ),
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _showSelectionPin ? 1 : 0,
            duration: const Duration(milliseconds: 250),
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.95, end: 1.08),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const Icon(
                  Icons.location_on,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              widget.selectingPickup
                  ? 'اختر نقطة الانطلاق بالضغط على الخريطة'
                  : 'اختر الوجهة بالضغط على الخريطة',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
        ),
      ],
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : cs.outlineVariant,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: cs.onSurfaceVariant,
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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: cs.onSurface),
              onSubmitted: (value) => widget.controller.searchAndSelectLocation(
                query: value,
                asPickup: widget.asPickup,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                border: InputBorder.none,
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20, color: cs.onSurfaceVariant),
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
    final cs = Theme.of(context).colorScheme;
    final mins = (category.pricing.distanceKm * 1.5 + 2).round();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : cs.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.local_taxi_outlined,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.vehicleCategory.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$mins دقيقة • ${category.pricing.distanceKm.toStringAsFixed(2)} كم',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\$${category.pricing.estimatedPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: cs.onSurface,
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
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Icon(icon, color: cs.onSurface),
      ),
    );
  }
}

void _showFindingDriverPopup({
  required BuildContext context,
  required String token,
  required int orderId,
  required String initialStatus,
  required String initialDispatchStatus,
  required VoidCallback onTrackNow,
}) {
  AppPopupDialog.show<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FindingDriverDialog(
      token: token,
      orderId: orderId,
      initialStatus: initialStatus,
      initialDispatchStatus: initialDispatchStatus,
      onTrackNow: onTrackNow,
    ),
  );
}

class _FindingDriverDialog extends StatefulWidget {
  final String token;
  final int orderId;
  final String initialStatus;
  final String initialDispatchStatus;
  final VoidCallback onTrackNow;

  const _FindingDriverDialog({
    required this.token,
    required this.orderId,
    required this.initialStatus,
    required this.initialDispatchStatus,
    required this.onTrackNow,
  });

  @override
  State<_FindingDriverDialog> createState() => _FindingDriverDialogState();
}

class _FindingDriverDialogState extends State<_FindingDriverDialog> {
  final OrdersRepository _repository = OrdersRepository();
  OrderDispatchWatcher? _dispatchWatcher;
  bool _isAssigned = false;
  bool _isCancelling = false;
  bool _handledNoDriver = false;
  final OrderDispatchTransitionTracker _noDriverTracker =
      OrderDispatchTransitionTracker();
  DateTime? _lastTimeoutPopupAt;

  String? _driverName;
  String? _driverVehicleType;
  String? _driverPlate;
  String? _driverRating;

  String? _firstNonEmpty(List<dynamic> candidates) {
    for (final raw in candidates) {
      final value = raw?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _isAssigned = OrderDispatchUtils.isDriverAssigned(
      kind: OrderDispatchServiceKind.taxi,
      status: widget.initialStatus,
      dispatchStatus: widget.initialDispatchStatus,
    );
    _noDriverTracker.shouldHandleNoDriver(
      status: widget.initialStatus,
      dispatchStatus: widget.initialDispatchStatus,
    );
    _startWatching();
  }

  @override
  void dispose() {
    unawaited(_dispatchWatcher?.dispose());
    super.dispose();
  }

  void _startWatching() {
    _dispatchWatcher?.dispose();
    _dispatchWatcher = OrderDispatchWatcher(
      token: widget.token,
      orderId: widget.orderId,
      initialStatus: widget.initialStatus,
      initialDispatchStatus: widget.initialDispatchStatus,
      onUpdate: _handleDispatchUpdate,
    );
    unawaited(_dispatchWatcher!.start());
  }

  Future<void> _handleNoDriver() async {
    if (!mounted || _handledNoDriver) return;
    _handledNoDriver = true;
    await _dispatchWatcher?.dispose();
    _dispatchWatcher = null;
    if (!mounted) return;
    Get.back();
    await showNoDriverAssignedDialog(context);
  }

  Future<void> _handleDispatchUpdate(
    String status,
    String dispatchStatus,
    Map<String, dynamic> payload,
  ) async {
    if (!mounted || _handledNoDriver) return;

    if (_noDriverTracker.shouldHandleNoDriver(
      status: status,
      dispatchStatus: dispatchStatus,
    )) {
      await _handleNoDriver();
      return;
    }

    final accepted = OrderDispatchUtils.isDriverAssigned(
      kind: OrderDispatchServiceKind.taxi,
      status: status,
      dispatchStatus: dispatchStatus,
    );

    final latest = payload.isNotEmpty
        ? payload
        : await _repository.getOrderById(
            token: widget.token,
            orderId: widget.orderId,
          );
    if (!mounted || latest.isEmpty) return;

    final deliveryMan = _asMap(latest['delivery_man'] ?? latest['deliveryMan']);
      if (deliveryMan != null) {
        _driverVehicleType = _firstNonEmpty([
          deliveryMan['vehicle_type'],
          deliveryMan['vehicleType'],
          deliveryMan['vehicle'],
        ]);
        _driverPlate = _firstNonEmpty([
          deliveryMan['license_plate'],
          deliveryMan['plate_number'],
          deliveryMan['plate'],
        ]);
        _driverRating = _firstNonEmpty([deliveryMan['rating'], deliveryMan['rate']]);
        final driverUser = _asMap(
          deliveryMan['user'] ??
              deliveryMan['driver_user'] ??
              deliveryMan['driverUser'] ??
              deliveryMan['account'],
        );
        if (driverUser != null) {
          _driverName = _firstNonEmpty([
            driverUser['name'],
            driverUser['full_name'],
            driverUser['username'],
          ]);
        }
        _driverName ??= _firstNonEmpty([
          deliveryMan['name'],
          deliveryMan['full_name'],
          deliveryMan['driver_name'],
        ]);
      }
      final flatDriverUser = _asMap(
        latest['delivery_man_user'] ?? latest['driver_user'] ?? latest['deliveryManUser'],
      );
      if (flatDriverUser != null) {
        _driverName ??= _firstNonEmpty([
          flatDriverUser['name'],
          flatDriverUser['full_name'],
          flatDriverUser['username'],
        ]);
      }
      _driverName ??= _firstNonEmpty([
        latest['delivery_man_name'],
        latest['driver_name'],
        latest['captain_name'],
        latest['deliveryManName'],
      ]);

      // Fallback: some responses don't include full driver user details.
      // Pull driver profile directly from dedicated endpoint.
      if (accepted &&
          ((_driverName ?? '').isEmpty ||
              (_driverVehicleType ?? '').isEmpty ||
              (_driverPlate ?? '').isEmpty)) {
        await _loadDriverDetailsFromDriverEndpoint();
      }

      if (accepted && !_isAssigned) {
        _isAssigned = true;
        if (mounted) {
          setState(() {});
        }
      } else if (mounted) {
        setState(() {});
      }
  }

  Future<void> _refreshAfterTimeout() async {
    if (!mounted || _handledNoDriver) return;
    try {
      final latest = await _repository.getOrderById(
        token: widget.token,
        orderId: widget.orderId,
      );
      if (!mounted || latest.isEmpty) return;
      final status = (latest['status'] ?? '').toString();
      final dispatchStatus = (latest['dispatch_status'] ?? '').toString();
      await _handleDispatchUpdate(status, dispatchStatus, latest);
    } on TaxiApiException catch (e) {
      if (_isTimeoutMessage(e.message)) {
        _showTimeoutPopup();
      }
    } catch (_) {
      // Ignore transient polling failures in modal state.
    }
  }

  bool _isTimeoutMessage(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized.contains('timeout') ||
        normalized.contains('timed out') ||
        normalized.contains('مهلة');
  }

  Future<void> _showTimeoutPopup() async {
    if (!mounted) return;
    final now = DateTime.now();
    final previous = _lastTimeoutPopupAt;
    if (previous != null && now.difference(previous) < const Duration(seconds: 20)) {
      return;
    }
    _lastTimeoutPopupAt = now;

    showDisconnectDialog(context, onRetry: _refreshAfterTimeout);
  }

  Future<void> _loadDriverDetailsFromDriverEndpoint() async {
    try {
      final driver = await _repository.getOrderDriverByOrderId(
        token: widget.token,
        orderId: widget.orderId,
      );
      if (driver.isEmpty) return;

      _driverName = driver.name ?? _driverName;
      _driverVehicleType = driver.vehicleType ?? _driverVehicleType;
      _driverPlate = driver.plate ?? _driverPlate;
      _driverRating = driver.rating ?? _driverRating;
    } catch (_) {
      // keep popup stable if driver endpoint is temporarily unavailable
    }
  }

  Future<void> _cancelOrder() async {
    if (_isCancelling) return;
    final reason = await _showTaxiCancelReasonSheet(context);
    if (reason == null) return;
    if (!mounted) return;

    setState(() => _isCancelling = true);
    try {
      await _repository.cancelOrder(
        token: widget.token,
        orderId: widget.orderId,
        cancellationReason: reason,
      );
      if (!mounted) return;
      final restricted = await resolveOrderCancellationLimitService()
          .onOrderCancelledSuccessfully(context);
      if (restricted || !mounted) return;
      Get.back();
      AppSnackbar.show(
        'تم الإلغاء',
        'تم إلغاء طلب التاكسي بنجاح',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } on TaxiApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.show('خطأ', e.message, snackPosition: SnackPosition.BOTTOM);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        'خطأ',
        'تعذر إلغاء الطلب حالياً',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 290,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _isAssigned
                    ? Color.alphaBlend(
                        const Color(0xFF16A34A).withValues(alpha: 0.18),
                        cs.surface,
                      )
                    : Color.alphaBlend(
                        AppColors.primary.withValues(alpha: 0.14),
                        cs.surface,
                      ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _isAssigned
                      ? const Color(0xFFBBF7D0)
                      : AppColors.primary.withValues(alpha: 0.45),
                ),
              ),
              child: _isAssigned
                  ? const Icon(
                      Icons.check_circle,
                      color: Color(0xFF16A34A),
                      size: 44,
                    )
                  : const Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.directions_car_filled_rounded,
                          color: AppColors.primary,
                          size: 34,
                        ),
                        SizedBox(
                          width: 62,
                          height: 62,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              _isAssigned ? 'تم تعيين السائق' : 'جاري البحث عن سائق',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isAssigned
                  ? 'تم قبول طلبك، يمكنك متابعة الرحلة الآن'
                  : 'تم إنشاء طلب التاكسي بنجاح',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 16,
              ),
            ),
            if (_isAssigned) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    _driverInfoRow(cs, 'اسم السائق', _driverName ?? 'غير متاح'),
                    _driverInfoRow(
                      cs,
                      'نوع المركبة',
                      _driverVehicleType ?? 'غير متاح',
                    ),
                    _driverInfoRow(cs, 'اللوحة', _driverPlate ?? 'غير متاح'),
                    _driverInfoRow(cs, 'التقييم', _driverRating ?? 'غير متاح'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isAssigned || _isCancelling ? null : _cancelOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: cs.surface,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'إلغاء الطلب',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _isAssigned
                        ? () {
                            Get.back();
                            widget.onTrackNow();
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_isAssigned ? 'عرض الرحلة' : 'بانتظار التعيين'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverInfoRow(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showTaxiCancelReasonSheet(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _TaxiCancelReasonSheet(),
  );
}

class _TaxiCancelReasonSheet extends StatefulWidget {
  const _TaxiCancelReasonSheet();

  @override
  State<_TaxiCancelReasonSheet> createState() => _TaxiCancelReasonSheetState();
}

class _TaxiCancelReasonSheetState extends State<_TaxiCancelReasonSheet> {
  static const List<String> _reasons = [
    'الأجرة مرتفعة للغاية',
    'السائق بعيد جدًا',
    'غيرت رأيي',
    'سبب مخصص',
  ];
  String? _selectedReason;
  late final TextEditingController _customReasonController;

  bool get _isCustomReason => _selectedReason == 'سبب مخصص';

  @override
  void initState() {
    super.initState();
    _customReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == null) {
      AppSnackbar.show('orders.warning'.tr, 'orders.selectCancelReason'.tr);
      return;
    }
    final customReason = _customReasonController.text.trim();
    final reason = _isCustomReason ? customReason : _selectedReason!;
    if (reason.isEmpty) {
      AppSnackbar.show('orders.warning'.tr, 'orders.writeCancelReason'.tr);
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'حدد سببك للإلغاء',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              ..._reasons.map(
                (reason) => InkWell(
                  onTap: () => setState(() => _selectedReason = reason),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedReason == reason
                            ? AppColors.primary
                            : cs.outlineVariant,
                      ),
                      color: _selectedReason == reason
                          ? cs.primaryContainer
                          : cs.surface,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          _selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: _selectedReason == reason
                              ? AppColors.primary
                              : cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isCustomReason) ...[
                TextField(
                  controller: _customReasonController,
                  maxLines: 2,
                  style: TextStyle(color: cs.onSurface),
                  decoration: InputDecoration(
                    hintText: 'السبب',
                    hintStyle: TextStyle(color: cs.onSurfaceVariant),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        foregroundColor: AppColors.primary,
                        backgroundColor: cs.surface,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('عدم الإلغاء'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'إلغاء الطلب',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
