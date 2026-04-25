import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
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
                  icon: Icons.my_location_outlined,
                  onChangeTap: () => _openLocationPicker(isPickup: true),
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
                  icon: Icons.location_on_outlined,
                  onChangeTap: () => _openLocationPicker(isPickup: false),
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
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _senderPhoneController,
                      label: 'رقم المرسل',
                      keyboardType: TextInputType.phone,
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
                    ),
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _receiverPhoneController,
                      label: 'رقم المستلم',
                      keyboardType: TextInputType.phone,
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
                                if (!mounted) return;
                                _showFindingDriverPopup(
                                  context: context,
                                  message: 'تم إنشاء طلب الشحن بنجاح',
                                  onTrackNow: () {
                                    Get.to(
                                      () => TransportOrderTrackingScreen(
                                        token: token,
                                        orderId: order.orderId,
                                        orderNumber: order.orderNumber,
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

    final selected = await showDialog<LatLng>(
      context: context,
      builder: (context) => _MapPickerDialog(
        initialPoint: LatLng(initialLat, initialLng),
        title: isPickup ? 'حدد موقع الاستلام' : 'حدد موقع التسليم',
        onSearch: (query) => controller.searchLocationInSyria(query),
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
}

class _MapPickerDialog extends StatefulWidget {
  final LatLng initialPoint;
  final String title;
  final Future<({double lat, double lng})?> Function(String query) onSearch;

  const _MapPickerDialog({
    required this.initialPoint,
    required this.title,
    required this.onSearch,
  });

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late LatLng _selectedPoint;
  final MapController _mapController = MapController();
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final result = await widget.onSearch(query);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد نتائج داخل سوريا')));
      return;
    }
    setState(() {
      _selectedPoint = LatLng(result.lat, result.lng);
    });
    _mapController.move(_selectedPoint, 14);
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
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _runSearch(),
                      decoration: InputDecoration(
                        hintText: 'ابحث عن موقع داخل سوريا',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSearching ? null : _runSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('بحث'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: widget.initialPoint,
                  initialZoom: 14,
                  onTap: (_, point) {
                    setState(() {
                      _selectedPoint = point;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.najiz_go_express',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ],
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
  final IconData icon;
  final VoidCallback onChangeTap;

  const _LocationRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
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
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.label,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
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
  required String message,
  required VoidCallback onTrackNow,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
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
    ),
  );
}
