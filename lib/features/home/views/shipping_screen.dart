import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/data/repositories/home_repository.dart';
import 'package:najiz_go_express/features/home/controllers/shipping_controller.dart';
import 'package:najiz_go_express/features/home/views/transport_order_tracking_screen.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';

class ShippingScreen extends StatefulWidget {
  final String? token;

  const ShippingScreen({super.key, required this.token});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  late final ShippingController controller;

  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderPhoneController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  static const _packageTypes = <String>[
    'مستندات',
    'طرود صغيرة',
    'ملابس',
    'إلكترونيات',
    'هدايا',
    'مواد غذائية',
  ];

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      ShippingController(token: widget.token),
      tag: 'shipping-screen',
    );
    _weightController.addListener(_onShippingInputsChanged);
    _lengthController.addListener(_onShippingInputsChanged);
    _widthController.addListener(_onShippingInputsChanged);
    _heightController.addListener(_onShippingInputsChanged);
    _senderNameController.addListener(_onContactsChanged);
    _senderPhoneController.addListener(_onContactsChanged);
    _receiverNameController.addListener(_onContactsChanged);
    _receiverPhoneController.addListener(_onContactsChanged);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    super.dispose();
  }

  void _onShippingInputsChanged() {
    controller.onShippingInputsChanged(
      weight: _weightController.text,
      length: _lengthController.text,
      width: _widthController.text,
      height: _heightController.text,
    );
  }

  void _onContactsChanged() {
    controller.onContactsChanged(
      senderName: _senderNameController.text,
      senderPhone: _senderPhoneController.text,
      receiverName: _receiverNameController.text,
      receiverPhone: _receiverPhoneController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 0,
        serviceText: 'شحن',
        serviceIcon: Icons.local_shipping_outlined,
        serviceActive: true,
        onServiceTap: () {},
        onTap: (index) => MainBottomNav.onTap(
          index: index,
          currentIndex: -1,
          token: widget.token,
        ),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'إنشاء طلب شحن',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Obx(
          () => ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            children: [
              _StepCard(
                title: 'الخطوة 1: مكان الاستلام',
                child: _LocationRow(
                  title: 'موقع الاستلام',
                  subtitle: controller.pickupAddress.value,
                  addressName: controller.pickupAddressName.value,
                  icon: Icons.my_location_outlined,
                  onChangeTap: () => _openLocationPicker(isPickup: true),
                  manualButtonText: 'أضف عنوان الاستلام يدوي',
                  onManualTap: () => _openManualAddressSheet(isPickup: true),
                ),
              ),
              const SizedBox(height: 10),
              _StepCard(
                title: 'الخطوة 2: مكان التسليم',
                child: _LocationRow(
                  title: 'موقع التسليم',
                  subtitle:
                      controller.destinationAddress.value ??
                      'اختر موقع التسليم من الخريطة',
                  addressName: controller.destinationAddressName.value,
                  icon: Icons.location_on_outlined,
                  onChangeTap: () => _openLocationPicker(isPickup: false),
                  manualButtonText: 'أضف عنوان المستلم يدوي',
                  onManualTap: () => _openManualAddressSheet(isPickup: false),
                ),
              ),
              const SizedBox(height: 10),
              _StepCard(
                title: 'معاينة المسار على الخريطة',
                child: _ShippingRoutePreviewMap(
                  pickupLat: controller.pickupLat.value,
                  pickupLng: controller.pickupLng.value,
                  destLat: controller.destLat.value,
                  destLng: controller.destLng.value,
                ),
              ),
              const SizedBox(height: 10),
              _StepCard(
                title: 'الخطوة 3: بيانات الطرد',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InputField(
                            controller: _weightController,
                            label: 'الوزن (كغ)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InputField(
                            controller: _lengthController,
                            label: 'الطول (سم)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _InputField(
                            controller: _widthController,
                            label: 'العرض (سم)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InputField(
                            controller: _heightController,
                            label: 'الارتفاع (سم)',
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'نوع الشحنة',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _packageTypes
                          .map(
                            (type) => Obx(
                              () => _PackageTypeChip(
                                label: type,
                                selected: controller.packageType.value == type,
                                onTap: () => controller.setPackageType(type),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 10),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: controller.isBreakable.value
                                    ? const Color(0xFFFFF1F2)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: controller.isBreakable.value
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'الشحنة قابلة للكسر',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'فعّلها إذا كانت تحتاج تعامل خاص',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: controller.isBreakable.value,
                              activeThumbColor: AppColors.primary,
                              onChanged: controller.setBreakable,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _StepCard(
                title: 'بيانات المرسل',
                child: Column(
                  children: [
                    _InputField(
                      controller: _senderNameController,
                      label: 'اسم المرسل',
                      errorText: controller.liveNameError(
                        _senderNameController.text,
                        label: 'اسم المرسل',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _senderPhoneController,
                      label: 'رقم المرسل',
                      keyboardType: TextInputType.phone,
                      errorText: controller.livePhoneError(
                        _senderPhoneController.text,
                        label: 'رقم المرسل',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _StepCard(
                title: 'بيانات المستلم',
                child: Column(
                  children: [
                    _InputField(
                      controller: _receiverNameController,
                      label: 'اسم المستلم',
                      errorText: controller.liveNameError(
                        _receiverNameController.text,
                        label: 'اسم المستلم',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _receiverPhoneController,
                      label: 'رقم المستلم',
                      keyboardType: TextInputType.phone,
                      errorText: controller.livePhoneError(
                        _receiverPhoneController.text,
                        label: 'رقم المستلم',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (controller.errorMessage.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    controller.errorMessage.value!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              _PriceCard(
                isCalculating: controller.isCalculating.value,
                total: controller.total.value,
                deliveryFee: controller.deliveryFee.value,
                distance: controller.distance.value,
                parcelCategory: controller.parcelCategory.value,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed:
                      controller.isCreatingOrder.value ||
                          controller.isCalculating.value ||
                          !controller.canConfirmOrder
                      ? null
                      : () async {
                          await AuthGuardService.runOrRequestLogin(
                            onAuthenticated: (token) async {
                              controller.setAuthToken(token);
                              try {
                                final order = await controller
                                    .createShippingOrder();
                                if (!context.mounted) return;
                                _showFindingDriverPopup(
                                  context: context,
                                  token: token,
                                  orderId: order.orderId,
                                  initialStatus: order.status,
                                  initialDispatchStatus: order.dispatchStatus,
                                  onTrackNow: () {
                                    Get.to(
                                      () => TransportOrderTrackingScreen(
                                        token: token,
                                        orderId: order.orderId,
                                        orderNumber: order.orderNumber,
                                        orderType: 'shipping',
                                        initialStatus: order.status,
                                        initialDispatchStatus:
                                            order.dispatchStatus,
                                        pickupLat: order.pickupLat,
                                        pickupLng: order.pickupLng,
                                        destinationLat: order.destinationLat,
                                        destinationLng: order.destinationLng,
                                      ),
                                    );
                                  },
                                );
                              } on HomeApiException catch (e) {
                                Get.snackbar('خطأ', e.message);
                              } catch (_) {
                                Get.snackbar('خطأ', 'تعذر إنشاء طلب الشحن');
                              }
                            },
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF94A3B8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: controller.isCreatingOrder.value
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'تأكيد الطلب',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLocationPicker({required bool isPickup}) async {
    final initialLat = isPickup
        ? (controller.pickupLat.value ?? 33.5138)
        : (controller.destLat.value ?? controller.pickupLat.value ?? 33.5138);
    final initialLng = isPickup
        ? (controller.pickupLng.value ?? 36.2765)
        : (controller.destLng.value ?? controller.pickupLng.value ?? 36.2765);

    final selected = await showDialog<ll.LatLng>(
      context: context,
      builder: (context) => _MapPickerDialog(
        initialPoint: ll.LatLng(initialLat, initialLng),
        title: isPickup ? 'حدد موقع الاستلام' : 'حدد موقع التسليم',
        onSuggestions: (query) => controller.fetchLocationSuggestions(query: query),
        onSelectSuggestion: (suggestion) =>
            controller.selectSuggestionLocation(suggestion: suggestion),
      ),
    );

    if (selected == null) return;
    if (isPickup) {
      await controller.setPickupLocation(
        lat: selected.latitude,
        lng: selected.longitude,
      );
      return;
    }
    await controller.setDestinationLocation(
      lat: selected.latitude,
      lng: selected.longitude,
    );
  }

  Future<void> _openManualAddressSheet({required bool isPickup}) async {
    final selected = await showModalBottomSheet<_AddressSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddressDetailsSheet(
        controller: controller,
        isPickup: isPickup,
      ),
    );

    if (selected == null) return;
    if (isPickup) {
      await controller.applyPickupAddressSelection(
        lat: selected.lat,
        lng: selected.lng,
        mapLabel: selected.mapLabel,
        addressName: selected.addressName,
        area: selected.area,
        street: selected.street,
        building: selected.building,
        details: selected.details,
      );
      return;
    }
    await controller.applyDestinationAddressSelection(
      lat: selected.lat,
      lng: selected.lng,
      mapLabel: selected.mapLabel,
      addressName: selected.addressName,
      area: selected.area,
      street: selected.street,
      building: selected.building,
      details: selected.details,
    );
  }
}

class _MapPickerDialog extends StatefulWidget {
  final ll.LatLng initialPoint;
  final String title;
  final Future<List<ShippingPlaceSuggestion>> Function(String query)
  onSuggestions;
  final Future<({double lat, double lng, String? label})?> Function(
    ShippingPlaceSuggestion suggestion,
  )
  onSelectSuggestion;

  const _MapPickerDialog({
    required this.initialPoint,
    required this.title,
    required this.onSuggestions,
    required this.onSelectSuggestion,
  });

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late ll.LatLng _selectedPoint;
  GoogleMapController? _mapController;
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isSearching = false;
  bool _isLoadingSuggestions = false;
  List<ShippingPlaceSuggestion> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final suggestions = await widget.onSuggestions(query);
    if (suggestions.isEmpty) {
      if (!mounted) return;
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد نتائج داخل سوريا')));
      return;
    }
    final result = await widget.onSelectSuggestion(suggestions.first);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد نتائج داخل سوريا')));
      return;
    }
    setState(() {
      _selectedPoint = ll.LatLng(result.lat, result.lng);
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_selectedPoint.latitude, _selectedPoint.longitude),
        14,
      ),
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
      final results = await widget.onSuggestions(query);
      if (!mounted) return;
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = results;
      });
    });
  }

  Future<void> _pickSuggestion(ShippingPlaceSuggestion suggestion) async {
    if (_isSearching) return;
    setState(() => _isSearching = true);
    final result = await widget.onSelectSuggestion(suggestion);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر تحديد هذا الموقع')));
      return;
    }
    setState(() {
      _selectedPoint = ll.LatLng(result.lat, result.lng);
      _searchController.text = result.label ?? suggestion.description;
      _suggestions = const [];
    });
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_selectedPoint.latitude, _selectedPoint.longitude),
        14,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SizedBox(
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF5F7FA),
                    ),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: 'ابحث باقتراحات Google داخل سوريا',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF64748B),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _isSearching ? null : _runSearch,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : const Text(
                            'بحث',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
            if (_isLoadingSuggestions) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ] else if (_suggestions.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    final detailText = suggestion.secondaryText.isNotEmpty
                        ? suggestion.secondaryText
                        : suggestion.description;
                    final distanceKm = suggestion.distanceMeters == null
                        ? null
                        : suggestion.distanceMeters! / 1000.0;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.textSecondary,
                      ),
                      title: Text(
                        suggestion.primaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        detailText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      trailing: distanceKm == null
                          ? null
                          : Text(
                              '${distanceKm.toStringAsFixed(distanceKm >= 10 ? 0 : 1)} كم',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      onTap: () => _pickSuggestion(suggestion),
                    );
                  },
                ),
              ),
            ],
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    widget.initialPoint.latitude,
                    widget.initialPoint.longitude,
                  ),
                  zoom: 14,
                ),
                onMapCreated: (controller) => _mapController = controller,
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
                    position: LatLng(
                      _selectedPoint.latitude,
                      _selectedPoint.longitude,
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ),
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
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'تأكيد الموقع',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _StepCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? addressName;
  final IconData icon;
  final VoidCallback onChangeTap;
  final String? manualButtonText;
  final VoidCallback? onManualTap;

  const _LocationRow({
    required this.title,
    required this.subtitle,
    this.addressName,
    required this.icon,
    required this.onChangeTap,
    this.manualButtonText,
    this.onManualTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (addressName != null && addressName!.trim().isNotEmpty)
                          Text(
                            'العنوان: ${addressName!.trim()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(onPressed: onChangeTap, child: const Text('تغيير')),
            ],
          ),
        ),
        if (manualButtonText != null && onManualTap != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onManualTap,
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: Text(manualButtonText!),
          ),
        ],
      ],
    );
  }
}

class _AddressSelectionResult {
  final double lat;
  final double lng;
  final String mapLabel;
  final String addressName;
  final String area;
  final String street;
  final String building;
  final String details;

  const _AddressSelectionResult({
    required this.lat,
    required this.lng,
    required this.mapLabel,
    required this.addressName,
    required this.area,
    required this.street,
    required this.building,
    required this.details,
  });
}

class _AddressDetailsSheet extends StatefulWidget {
  final ShippingController controller;
  final bool isPickup;

  const _AddressDetailsSheet({
    required this.controller,
    required this.isPickup,
  });

  @override
  State<_AddressDetailsSheet> createState() => _AddressDetailsSheetState();
}

class _AddressDetailsSheetState extends State<_AddressDetailsSheet> {
  final _searchController = TextEditingController();
  final _addressNameController = TextEditingController();
  final _areaController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();
  final _detailsController = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoadingSuggestions = false;
  ShippingPlaceSuggestion? _selectedSuggestion;
  ({double lat, double lng, String? label})? _selectedLocation;
  List<ShippingPlaceSuggestion> _suggestions = const [];

  bool get _canSubmit =>
      _selectedLocation != null && _addressNameController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _addressNameController.text = widget.isPickup
        ? widget.controller.pickupAddressName.value
        : widget.controller.destinationAddressName.value;
    _areaController.text = widget.isPickup
        ? widget.controller.pickupArea.value
        : widget.controller.destinationArea.value;
    _streetController.text = widget.isPickup
        ? widget.controller.pickupStreet.value
        : widget.controller.destinationStreet.value;
    _buildingController.text = widget.isPickup
        ? widget.controller.pickupBuilding.value
        : widget.controller.destinationBuilding.value;
    _detailsController.text = widget.isPickup
        ? widget.controller.pickupDetails.value
        : widget.controller.destinationDetails.value;
    _addressNameController.addListener(_refresh);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _addressNameController.dispose();
    _areaController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _onQueryChanged(String value) async {
    _debounceTimer?.cancel();
    _selectedLocation = null;
    _selectedSuggestion = null;
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = const [];
      });
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

  Future<void> _selectSuggestion(ShippingPlaceSuggestion suggestion) async {
    setState(() => _isLoadingSuggestions = true);
    final result = await widget.controller.selectSuggestionLocation(
      suggestion: suggestion,
    );
    if (!mounted) return;
    setState(() => _isLoadingSuggestions = false);
    if (result == null) {
      Get.snackbar('خطأ', 'يرجى اختيار موقع صحيح من الاقتراحات');
      return;
    }
    final label = (result.label ?? suggestion.description).trim();
    setState(() {
      _selectedSuggestion = suggestion;
      _selectedLocation = result;
      _searchController.text = label;
      _suggestions = const [];
      if (_areaController.text.trim().isEmpty &&
          suggestion.secondaryText.trim().isNotEmpty) {
        _areaController.text = suggestion.secondaryText.trim();
      }
      if (_streetController.text.trim().isEmpty &&
          suggestion.primaryText.trim().isNotEmpty) {
        _streetController.text = suggestion.primaryText.trim();
      }
    });
  }

  void _submit() {
    if (!_canSubmit || _selectedLocation == null) return;
    final location = _selectedLocation!;
    Navigator.of(context).pop(
      _AddressSelectionResult(
        lat: location.lat,
        lng: location.lng,
        mapLabel: (location.label ?? _searchController.text).trim(),
        addressName: _addressNameController.text,
        area: _areaController.text,
        street: _streetController.text,
        building: _buildingController.text,
        details: _detailsController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isPickup ? 'مكان الاستلام' : 'مكان التسليم',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    labelText: 'ابحث عن الموقع',
                    hintText: 'اختر من اقتراحات الخريطة فقط',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_isLoadingSuggestions)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_suggestions.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        final isSelected =
                            _selectedSuggestion?.placeId == suggestion.placeId;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isSelected
                                ? Icons.check_circle
                                : Icons.location_on_outlined,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          title: Text(
                            suggestion.primaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            suggestion.secondaryText.isNotEmpty
                                ? suggestion.secondaryText
                                : suggestion.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _selectSuggestion(suggestion),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                _InputField(
                  controller: _addressNameController,
                  label: 'اسم العنوان (منزل/شركة/عمل...)',
                ),
                const SizedBox(height: 8),
                _InputField(
                  controller: _areaController,
                  label: 'المنطقة',
                ),
                const SizedBox(height: 8),
                _InputField(
                  controller: _streetController,
                  label: 'الشارع',
                ),
                const SizedBox(height: 8),
                _InputField(
                  controller: _buildingController,
                  label: 'البناء',
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _detailsController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'تفاصيل العنوان',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('تم الاضافة'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final String? errorText;

  const _InputField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}

class _PackageTypeChip extends StatelessWidget {
  const _PackageTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
          color: selected ? const Color(0xFFFFF3E8) : Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 14,
              color: selected ? AppColors.primary : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.textPrimary : const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final bool isCalculating;
  final double? total;
  final double? deliveryFee;
  final double? distance;
  final String? parcelCategory;

  const _PriceCard({
    required this.isCalculating,
    required this.total,
    required this.deliveryFee,
    required this.distance,
    required this.parcelCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: isCalculating
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('جاري حساب سعر الشحن...'),
                ],
              ),
            )
          : total == null
          ? const Text(
              'أكمل الإدخالات المطلوبة ليتم حساب السعر',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parcelCategory != null)
                  Text(
                    'فئة الطرد: $parcelCategory',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (distance != null)
                  Text(
                    'المسافة: ${distance!.toStringAsFixed(2)} كم',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 6),
                if (deliveryFee != null)
                  Text(
                    'رسوم التوصيل: ${deliveryFee!.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  'السعر الإجمالي: ${total!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
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
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ShippingFindingDriverDialog(
      token: token,
      orderId: orderId,
      initialStatus: initialStatus,
      initialDispatchStatus: initialDispatchStatus,
      onTrackNow: onTrackNow,
    ),
  );
}

class _ShippingRoutePreviewMap extends StatelessWidget {
  const _ShippingRoutePreviewMap({
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
  });

  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  @override
  Widget build(BuildContext context) {
    if (pickupLat == null || pickupLng == null) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'جاري تحميل موقع الاستلام...',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final pickup = LatLng(pickupLat!, pickupLng!);
    final hasDest = destLat != null && destLng != null;
    final destination = hasDest ? LatLng(destLat!, destLng!) : null;

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: pickup, zoom: 12.8),
        zoomControlsEnabled: false,
        myLocationButtonEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickup,
            infoWindow: const InfoWindow(title: 'الاستلام'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
          if (destination != null)
            Marker(
              markerId: const MarkerId('dest'),
              position: destination,
              infoWindow: const InfoWindow(title: 'التسليم'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            ),
        },
        polylines: {
          if (destination != null)
            Polyline(
              polylineId: const PolylineId('shipping_preview'),
              points: [pickup, destination],
              width: 4,
              color: const Color(0xFF475569),
            ),
        },
      ),
    );
  }
}

class _ShippingFindingDriverDialog extends StatefulWidget {
  const _ShippingFindingDriverDialog({
    required this.token,
    required this.orderId,
    required this.initialStatus,
    required this.initialDispatchStatus,
    required this.onTrackNow,
  });

  final String token;
  final int orderId;
  final String initialStatus;
  final String initialDispatchStatus;
  final VoidCallback onTrackNow;

  @override
  State<_ShippingFindingDriverDialog> createState() =>
      _ShippingFindingDriverDialogState();
}

class _ShippingFindingDriverDialogState extends State<_ShippingFindingDriverDialog> {
  final HomeRepository _repository = HomeRepository();
  Timer? _pollTimer;
  bool _isAssigned = false;
  bool _isCancelling = false;
  String _latestStatus = '';
  String _latestDispatchStatus = '';

  String? _driverName;
  String? _driverVehicleType;
  String? _driverPlate;
  String? _driverRating;

  @override
  void initState() {
    super.initState();
    _latestStatus = widget.initialStatus;
    _latestDispatchStatus = widget.initialDispatchStatus;
    _isAssigned = _isAccepted(
      status: widget.initialStatus,
      dispatchStatus: widget.initialDispatchStatus,
    );
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool _isAccepted({required String status, required String dispatchStatus}) {
    final s = status.toLowerCase();
    final d = dispatchStatus.toLowerCase();
    return s == 'accepted' ||
        d == 'accepted' ||
        d == 'assigned' ||
        s == 'on_the_way_to_pickup' ||
        s == 'picked_up' ||
        s == 'on_way' ||
        s == 'delivered';
  }

  bool get _canCancelOrder {
    final status = _latestStatus.toLowerCase();
    return !_isCancellationLocked(status);
  }

  bool _isCancellationLocked(String status) {
    return status == 'picked_up' ||
        status == 'on_way' ||
        status == 'delivered' ||
        status == 'cancelled';
  }

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
    if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final latest = await _repository.getOrderById(
          token: widget.token,
          orderId: widget.orderId,
        );
        if (!mounted || latest.isEmpty) return;

        final status = (latest['status'] ?? '').toString();
        final dispatchStatus = (latest['dispatch_status'] ?? '').toString();
        _latestStatus = status;
        _latestDispatchStatus = dispatchStatus;
        final accepted = _isAccepted(status: status, dispatchStatus: dispatchStatus);

        final deliveryMan = _asMap(latest['delivery_man'] ?? latest['deliveryMan']);
        if (deliveryMan != null) {
          _driverVehicleType = _firstNonEmpty([
            deliveryMan['vehicle_type'],
            deliveryMan['vehicleType'],
            deliveryMan['vehicle'],
            _driverVehicleType,
          ]);
          _driverPlate = _firstNonEmpty([
            deliveryMan['license_plate'],
            deliveryMan['plate_number'],
            deliveryMan['plate'],
            _driverPlate,
          ]);
          _driverRating = _firstNonEmpty([
            deliveryMan['rating'],
            deliveryMan['rate'],
            _driverRating,
          ]);
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
              _driverName,
            ]);
          }
          _driverName ??= _firstNonEmpty([
            deliveryMan['name'],
            deliveryMan['full_name'],
            deliveryMan['driver_name'],
          ]);
        }

        if ((_driverName ?? '').isEmpty) {
          final driver = await _repository.getOrderDriverByOrderId(
            token: widget.token,
            orderId: widget.orderId,
          );
          if (driver.isNotEmpty) {
            _driverName = _firstNonEmpty([
              driver['driver_name'],
              driver['name'],
              _driverName,
            ]);
            _driverVehicleType = _firstNonEmpty([
              driver['vehicle_type'],
              driver['vehicle'],
              _driverVehicleType,
            ]);
            _driverPlate = _firstNonEmpty([
              driver['license_plate'],
              driver['plate_number'],
              _driverPlate,
            ]);
            _driverRating = _firstNonEmpty([
              driver['rating'],
              driver['rate'],
              _driverRating,
            ]);
          }
        }

        if (accepted && !_isAssigned) {
          _isAssigned = true;
          if (mounted) {
            setState(() {});
            Get.snackbar(
              'تم تعيين السائق',
              'تم قبول طلب الشحن من قبل السائق',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
            );
          }
        } else if (mounted) {
          setState(() {});
        }
      } catch (_) {
        // Keep popup stable on transient errors.
      }
    });
  }

  Future<void> _cancelOrder() async {
    if (_isCancelling) return;
    if (!_canCancelOrder) {
      Get.snackbar('تنبيه', 'لا يمكن إلغاء الطلب بعد استلام السائق للشحنة');
      return;
    }
    final reason = await _showShippingCancelReasonSheet(context);
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
      _pollTimer?.cancel();
      await _showCancelSuccessAndGoHome();
    } on HomeApiException catch (e) {
      if (!mounted) return;
      Get.snackbar('خطأ', e.message);
    } catch (_) {
      if (!mounted) return;
      Get.snackbar('خطأ', 'تعذر إلغاء الطلب حالياً');
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _showCancelSuccessAndGoHome() async {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final quarterHeight = MediaQuery.of(context).size.height * 0.25;
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: SizedBox(
            height: quarterHeight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.82, end: 1.0),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Icon(
                        Icons.cancel_rounded,
                        color: Color(0xFFDC2626),
                        size: 38,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'تم إلغاء طلبك بنجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await MainBottomNav.onTap(index: 0, currentIndex: -1, token: widget.token);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _isAssigned
                    ? const Color(0xFFE9F9EE)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: _isAssigned
                      ? const Color(0xFFBBF7D0)
                      : const Color(0xFFFCD9B6),
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
                          Icons.local_shipping_outlined,
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
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _isAssigned
                  ? 'تم قبول طلب الشحن، يمكنك متابعة الرحلة الآن'
                  : 'تم إنشاء طلب الشحن بنجاح',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            if (_isAssigned) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8ECF2)),
                ),
                child: Column(
                  children: [
                    _driverInfoRow('اسم السائق', _driverName ?? 'غير متاح'),
                    _driverInfoRow('نوع المركبة', _driverVehicleType ?? 'غير متاح'),
                    _driverInfoRow('اللوحة', _driverPlate ?? 'غير متاح'),
                    _driverInfoRow('التقييم', _driverRating ?? 'غير متاح'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: !_canCancelOrder || _isCancelling ? null : _cancelOrder,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFD6DCE5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('إلغاء الطلب'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isAssigned
                        ? () {
                            Get.back();
                            widget.onTrackNow();
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
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

  Widget _driverInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _showShippingCancelReasonSheet(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ShippingCancelReasonSheet(),
  );
}

class _ShippingCancelReasonSheet extends StatefulWidget {
  const _ShippingCancelReasonSheet();

  @override
  State<_ShippingCancelReasonSheet> createState() => _ShippingCancelReasonSheetState();
}

class _ShippingCancelReasonSheetState extends State<_ShippingCancelReasonSheet> {
  static const _reasons = [
    'غيرت رأيي',
    'تأخر التعيين',
    'سبب مخصص',
  ];
  String? _selectedReason;
  final TextEditingController _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _selectedReason == 'سبب مخصص';
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
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'حدد سبب الإلغاء',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 10),
              ..._reasons.map(
                (reason) => InkWell(
                  onTap: () => setState(() => _selectedReason = reason),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedReason == reason
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                      ),
                      color: _selectedReason == reason
                          ? const Color(0xFFFFF3E8)
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(reason)),
                        Icon(
                          _selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _selectedReason == reason
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isCustom)
                TextField(
                  controller: _customController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'اكتب السبب',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedReason == null) return;
                    final reason = isCustom
                        ? _customController.text.trim()
                        : _selectedReason!;
                    if (reason.isEmpty) return;
                    Navigator.of(context).pop(reason);
                  },
                  child: const Text('تأكيد الإلغاء'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
