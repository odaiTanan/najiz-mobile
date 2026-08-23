import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/services/auth_guard_service.dart';
import 'package:najiz_go_express/core/services/session_service.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/features/orders/views/transport_order_tracking_screen.dart';
import 'package:najiz_go_express/features/shipping/errors/shipping_api_exception.dart';
import 'package:najiz_go_express/features/shipping/controllers/shipping_controller.dart'
    show ShippingPlaceSuggestion;
import 'package:najiz_go_express/features/wassini/controllers/wassini_controller.dart';

class WassiniScreen extends StatefulWidget {
  final String? token;

  const WassiniScreen({super.key, required this.token});

  @override
  State<WassiniScreen> createState() => _WassiniScreenState();
}

class _WassiniScreenState extends State<WassiniScreen> {
  late final WassiniController controller;

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pickupAddressController = TextEditingController();
  final _destinationAddressController = TextEditingController();

  Worker? _pickupAddressWorker;
  Worker? _destinationAddressWorker;

  @override
  void initState() {
    super.initState();

    controller = Get.put(
      WassiniController(token: widget.token),
      tag: 'wassini-screen',
    );

    _pickupAddressWorker = ever<String>(controller.pickupAddress, (value) {
      if (_pickupAddressController.text == value) return;
      _pickupAddressController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    });

    _destinationAddressWorker = ever<String>(controller.destinationAddress, (
      value,
    ) {
      if (_destinationAddressController.text == value) return;
      _destinationAddressController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    });

    _loadAccountDefaults();

    _descriptionController.addListener(() {
      controller.setRequestDescription(_descriptionController.text);
      setState(() {});
    });

    _amountController.addListener(() {
      controller.setPurchaseAmount(_amountController.text);
      controller.calculatePrice();
      setState(() {});
    });

    _nameController.addListener(_syncContacts);
    _phoneController.addListener(_syncContacts);
  }

  void _syncContacts() {
    controller.setContacts(
      senderNameValue: _nameController.text,
      senderPhoneValue: _phoneController.text,
      receiverNameValue: _nameController.text,
      receiverPhoneValue: _phoneController.text,
    );

    setState(() {});
  }

  Future<void> _loadAccountDefaults() async {
    final identity = await SessionService.getUserIdentity();

    if (!mounted) return;

    final name = identity['name']?.trim() ?? '';
    final phone = identity['phone']?.trim() ?? '';
    final savedAddress = identity['address']?.trim() ?? '';

    if (_nameController.text.trim().isEmpty && name.isNotEmpty) {
      _nameController.text = name;
    }

    if (_phoneController.text.trim().isEmpty && phone.isNotEmpty) {
      _phoneController.text = phone;
    }

    if (_destinationAddressController.text.trim().isEmpty &&
        savedAddress.isNotEmpty &&
        controller.destinationAddress.value.trim().isEmpty) {
      _destinationAddressController.text = savedAddress;
    }

    _syncContacts();
  }

  Future<void> _useTypedAddress({required bool isPickup}) async {
    final text = isPickup
        ? _pickupAddressController.text
        : _destinationAddressController.text;

    final success = await controller.setAddressFromText(
      address: text,
      isPickup: isPickup,
    );

    if (!mounted) return;

    if (!success && controller.errorMessage.value != null) {
      AppSnackbar.show('العنوان', controller.errorMessage.value!);
    }
  }

  @override
  void dispose() {
    _pickupAddressWorker?.dispose();
    _destinationAddressWorker?.dispose();

    _descriptionController.dispose();
    _amountController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _pickupAddressController.dispose();
    _destinationAddressController.dispose();

    if (Get.isRegistered<WassiniController>(tag: 'wassini-screen')) {
      Get.delete<WassiniController>(tag: 'wassini-screen');
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: cs.surfaceContainerLowest,
        foregroundColor: cs.onSurface,
        title: const Text(
          'وصّيني',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Obx(
          () => ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
            children: [
              _HeroCard(colorScheme: cs),
              const SizedBox(height: 12),

              _SectionCard(
                title: 'شو بدك؟',
                child: TextField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'مثلاً: بدي كيلو تفاح، كيلو موز، وعلبتين حليب...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              _SectionCard(
                title: 'المبلغ المطلوب مع المندوب',
                subtitle:
                    'إذا المندوب لازم يدفع ثمن الأغراض، اكتب المبلغ. هذا المبلغ منفصل عن أجرة وصّيني.',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'مثلاً 200000',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Obx(
                      () => DropdownButton<String>(
                        value: controller.purchaseCurrency.value,
                        items: const [
                          DropdownMenuItem(value: 'SYP', child: Text('ل.س')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          controller.setPurchaseCurrency(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              _SectionCard(
                title: 'من وين يجيب الطلب؟',
                subtitle: 'حدد مكان شراء أو استلام الأغراض.',
                child: _AddressAutocompleteField(
                  textController: _pickupAddressController,
                  icon: Icons.storefront_outlined,
                  hintText: 'اكتب اسم المحل أو العنوان',
                  fetchSuggestions: controller.fetchLocationSuggestions,
                  onSuggestionSelected: (suggestion) async {
                    final selected = await controller.selectSuggestionLocation(
                      suggestion: suggestion,
                    );

                    if (!mounted || selected == null) return;

                    await controller.setPickupLocation(
                      lat: selected.lat,
                      lng: selected.lng,
                    );

                    final label = selected.label?.trim();

                    _pickupAddressController.text =
                        label != null && label.isNotEmpty
                        ? label
                        : suggestion.description;
                  },
                  onUseText: () => _useTypedAddress(isPickup: true),
                  onMap: () => _openLocationPicker(isPickup: true),
                ),
              ),

              const SizedBox(height: 10),

              _SectionCard(
                title: 'لوين يوصله؟',
                subtitle: 'موقعك الحالي محدد تلقائياً، ويمكنك تغييره.',
                child: _AddressAutocompleteField(
                  textController: _destinationAddressController,
                  icon: Icons.location_on_outlined,
                  hintText: 'موقعك الحالي أو اكتب عنواناً آخر',
                  fetchSuggestions: controller.fetchLocationSuggestions,
                  onSuggestionSelected: (suggestion) async {
                    final selected = await controller.selectSuggestionLocation(
                      suggestion: suggestion,
                    );

                    if (!mounted || selected == null) return;

                    await controller.setDestinationLocation(
                      lat: selected.lat,
                      lng: selected.lng,
                    );

                    final label = selected.label?.trim();

                    _destinationAddressController.text =
                        label != null && label.isNotEmpty
                        ? label
                        : suggestion.description;
                  },
                  onUseText: () => _useTypedAddress(isPickup: false),
                  onMap: () => _openLocationPicker(isPickup: false),
                ),
              ),

              const SizedBox(height: 10),

              if (controller.pickupLat.value != null &&
                  controller.pickupLng.value != null &&
                  controller.destLat.value != null &&
                  controller.destLng.value != null)
                _RoutePreview(
                  pickup: LatLng(
                    controller.pickupLat.value!,
                    controller.pickupLng.value!,
                  ),
                  destination: LatLng(
                    controller.destLat.value!,
                    controller.destLng.value!,
                  ),
                ),

              const SizedBox(height: 10),

              _SectionCard(
                title: 'معلومات التواصل',
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        hintText: '09xxxxxxxx',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              if (controller.errorMessage.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    controller.errorMessage.value!,
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

              _PriceCard(
                isCalculating: controller.isCalculating.value,
                deliveryFee: controller.deliveryFee.value,
                distance: controller.distance.value,
              ),

              const SizedBox(height: 14),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed:
                      controller.isCreatingOrder.value ||
                          controller.isCalculating.value ||
                          !controller.canConfirmOrder
                      ? null
                      : _confirmOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: controller.isCreatingOrder.value
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'اطلب وصّيني',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
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
        ? controller.pickupLat.value
        : controller.destLat.value;

    final initialLng = isPickup
        ? controller.pickupLng.value
        : controller.destLng.value;

    final fallbackLat = controller.pickupLat.value ?? 33.5138;
    final fallbackLng = controller.pickupLng.value ?? 36.2765;

    final selected = await Get.to<LatLng>(
      () => _WassiniMapPicker(
        title: isPickup ? 'حدد مكان الشراء' : 'حدد موقع التسليم',
        initialPosition: LatLng(
          initialLat ?? fallbackLat,
          initialLng ?? fallbackLng,
        ),
      ),
    );

    if (selected == null) return;

    if (isPickup) {
      await controller.setPickupLocation(
        lat: selected.latitude,
        lng: selected.longitude,
      );
    } else {
      await controller.setDestinationLocation(
        lat: selected.latitude,
        lng: selected.longitude,
      );
    }
  }

  Future<void> _confirmOrder() async {
    await AuthGuardService.runOrRequestLogin(
      onAuthenticated: (token) async {
        controller.setAuthToken(token);

        try {
          final order = await controller.createOrder();

          if (!mounted) return;

          Get.to(
            () => TransportOrderTrackingScreen(
              token: token,
              orderId: order.orderId,
              orderNumber: order.orderNumber,
              orderType: 'shipping',
              initialStatus: order.status,
              initialDispatchStatus: order.dispatchStatus,
              pickupLat: order.pickupLat,
              pickupLng: order.pickupLng,
              destinationLat: order.destinationLat,
              destinationLng: order.destinationLng,
            ),
          );
        } on ShippingApiException catch (e) {
          AppSnackbar.show('خطأ', e.message);
        } catch (_) {
          AppSnackbar.show('خطأ', 'تعذر إنشاء طلب وصّيني');
        }
      },
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ColorScheme colorScheme;

  const _HeroCard({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: Color(0xFFFFE8D6),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وصّيني... ومنجيبلك ياه',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 4),
                Text(
                  'حدد شو بدك، من وين، ولوين... وأقرب مندوب بيتولى المهمة.',
                  style: TextStyle(fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _AddressAutocompleteField extends StatefulWidget {
  final TextEditingController textController;
  final IconData icon;
  final String hintText;
  final Future<List<ShippingPlaceSuggestion>> Function({required String query})
  fetchSuggestions;
  final Future<void> Function(ShippingPlaceSuggestion suggestion)
  onSuggestionSelected;
  final VoidCallback onUseText;
  final VoidCallback onMap;

  const _AddressAutocompleteField({
    required this.textController,
    required this.icon,
    required this.hintText,
    required this.fetchSuggestions,
    required this.onSuggestionSelected,
    required this.onUseText,
    required this.onMap,
  });

  @override
  State<_AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<_AddressAutocompleteField> {
  Timer? _debounce;
  List<ShippingPlaceSuggestion> _suggestions = const [];
  bool _loading = false;
  int _requestNumber = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();

    final query = value.trim();

    if (query.length < 2) {
      if (_suggestions.isNotEmpty || _loading) {
        setState(() {
          _suggestions = const [];
          _loading = false;
        });
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    final request = ++_requestNumber;

    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final result = await widget.fetchSuggestions(query: query);

      if (!mounted || request != _requestNumber) return;

      setState(() {
        _suggestions = result.take(6).toList(growable: false);
      });
    } catch (_) {
      if (!mounted || request != _requestNumber) return;

      setState(() {
        _suggestions = const [];
      });
    } finally {
      if (mounted && request == _requestNumber) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectSuggestion(ShippingPlaceSuggestion suggestion) async {
    _debounce?.cancel();

    widget.textController.value = TextEditingValue(
      text: suggestion.description,
      selection: TextSelection.collapsed(offset: suggestion.description.length),
    );

    setState(() {
      _suggestions = const [];
      _loading = true;
    });

    try {
      await widget.onSuggestionSelected(suggestion);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _suggestions = const [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        TextField(
          controller: widget.textController,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) {
            if (_suggestions.isNotEmpty) {
              _selectSuggestion(_suggestions.first);
            } else {
              widget.onUseText();
            }
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(widget.icon, color: AppColors.primary),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search_rounded),
            border: const OutlineInputBorder(),
          ),
        ),

        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x16000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: cs.outlineVariant),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];

                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    suggestion.primaryText.isNotEmpty
                        ? suggestion.primaryText
                        : suggestion.description,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: suggestion.secondaryText.isEmpty
                      ? null
                      : Text(
                          suggestion.secondaryText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 9),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : widget.onUseText,
                icon: const Icon(Icons.search_rounded),
                label: const Text('اعتماد العنوان المكتوب'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : widget.onMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('تحديد على الخريطة'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LocationTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_left),
          ],
        ),
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  final bool isCalculating;
  final double? deliveryFee;
  final double? distance;

  const _PriceCard({
    required this.isCalculating,
    required this.deliveryFee,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: isCalculating
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              children: [
                _PriceRow(
                  title: 'المسافة',
                  value: distance == null
                      ? '--'
                      : '${distance!.toStringAsFixed(1)} كم',
                ),
                const SizedBox(height: 9),
                _PriceRow(
                  title: 'أجرة وصّيني',
                  value: deliveryFee == null
                      ? '--'
                      : '${deliveryFee!.toStringAsFixed(0)} ل.س',
                  strong: true,
                ),
              ],
            ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String title;
  final String value;
  final bool strong;

  const _PriceRow({
    required this.title,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title)),
        Text(
          value,
          style: TextStyle(
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            fontSize: strong ? 16 : 14,
          ),
        ),
      ],
    );
  }
}

class _RoutePreview extends StatelessWidget {
  final LatLng pickup;
  final LatLng destination;

  const _RoutePreview({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    final center = LatLng(
      (pickup.latitude + destination.latitude) / 2,
      (pickup.longitude + destination.longitude) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: center, zoom: 12),
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          markers: {
            Marker(markerId: const MarkerId('pickup'), position: pickup),
            Marker(
              markerId: const MarkerId('destination'),
              position: destination,
            ),
          },
        ),
      ),
    );
  }
}

class _WassiniMapPicker extends StatefulWidget {
  final String title;
  final LatLng initialPosition;

  const _WassiniMapPicker({required this.title, required this.initialPosition});

  @override
  State<_WassiniMapPicker> createState() => _WassiniMapPickerState();
}

class _WassiniMapPickerState extends State<_WassiniMapPicker> {
  late LatLng selected;

  @override
  void initState() {
    super.initState();
    selected = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: selected, zoom: 15),
            onTap: (value) {
              setState(() {
                selected = value;
              });
            },
            markers: {
              Marker(markerId: const MarkerId('selected'), position: selected),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Get.back(result: selected);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'تأكيد الموقع',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
