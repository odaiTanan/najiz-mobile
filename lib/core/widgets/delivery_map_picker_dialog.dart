import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/features/orders/services/checkout_places_service.dart';

class DeliveryMapPickerResult {
  const DeliveryMapPickerResult({
    required this.point,
    this.label,
  });

  final ll.LatLng point;
  final String? label;
}

typedef DeliveryFetchSuggestions = Future<List<CheckoutPlaceSuggestion>> Function(
  String query,
);

typedef DeliveryResolveSuggestion = Future<CheckoutPlaceResult?> Function(
  String placeId,
  String fallbackDescription,
);

class DeliveryMapPickerDialog extends StatefulWidget {
  const DeliveryMapPickerDialog({
    super.key,
    required this.initialPoint,
    required this.fetchSuggestions,
    required this.resolveSuggestion,
  });

  final ll.LatLng initialPoint;
  final DeliveryFetchSuggestions fetchSuggestions;
  final DeliveryResolveSuggestion resolveSuggestion;

  @override
  State<DeliveryMapPickerDialog> createState() =>
      _DeliveryMapPickerDialogState();
}

class _DeliveryMapPickerDialogState extends State<DeliveryMapPickerDialog> {
  late ll.LatLng _selectedPoint;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isResolvingSuggestion = false;
  bool _isLoadingSuggestions = false;
  List<_SuggestionView> _suggestions = const [];

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _moveCamera(ll.LatLng point) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLng(LatLng(point.latitude, point.longitude)),
    );
  }

  void _onSearchChanged(String value) {
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
      final results = await widget.fetchSuggestions(query);
      if (!mounted) return;
      setState(() {
        _isLoadingSuggestions = false;
        _suggestions = results
            .map(
              (item) => _SuggestionView(
                placeId: item.placeId,
                primaryText: item.primaryText,
                secondaryText: item.secondaryText.isNotEmpty
                    ? item.secondaryText
                    : item.description,
                distanceMeters: item.distanceMeters,
              ),
            )
            .toList(growable: false);
      });
    });
  }

  Future<void> _selectSuggestion(_SuggestionView suggestion) async {
    if (_isResolvingSuggestion) return;
    setState(() => _isResolvingSuggestion = true);
    final resolved = await widget.resolveSuggestion(
      suggestion.placeId,
      suggestion.secondaryText,
    );
    if (!mounted) return;
    if (resolved == null) {
      AppSnackbar.show(
        'common.error'.tr,
        'location.resultOutsideSyria'.tr,
      );
      setState(() => _isResolvingSuggestion = false);
      return;
    }
    setState(() {
      _selectedPoint = ll.LatLng(resolved.latitude, resolved.longitude);
      _suggestions = const [];
      _isResolvingSuggestion = false;
    });
    _searchController.text = resolved.label;
    await _moveCamera(_selectedPoint);
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
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'location.searchHint'.tr,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _isLoadingSuggestions || _isResolvingSuggestion
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
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
            ),
            if (_suggestions.isNotEmpty)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, color: cs.outlineVariant),
                  itemBuilder: (_, index) {
                    final suggestion = _suggestions[index];
                    final distanceKm = suggestion.distanceMeters == null
                        ? null
                        : suggestion.distanceMeters! / 1000.0;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: cs.onSurfaceVariant,
                        size: 20,
                      ),
                      title: Text(
                        suggestion.primaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                      subtitle: Text(
                        suggestion.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      trailing: distanceKm == null
                          ? null
                          : Text(
                              '${distanceKm.toStringAsFixed(distanceKm >= 10 ? 0 : 1)} كم',
                              style: TextStyle(
                                color: cs.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                      onTap: _isResolvingSuggestion
                          ? null
                          : () => _selectSuggestion(suggestion),
                    );
                  },
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        widget.initialPoint.latitude,
                        widget.initialPoint.longitude,
                      ),
                      zoom: 14,
                    ),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (controller) => _mapController = controller,
                    onTap: (point) {
                      setState(() {
                        _selectedPoint =
                            ll.LatLng(point.latitude, point.longitude);
                        _suggestions = const [];
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    DeliveryMapPickerResult(
                      point: _selectedPoint,
                      label: _searchController.text.trim().isNotEmpty
                          ? _searchController.text.trim()
                          : null,
                    ),
                  ),
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

class _SuggestionView {
  const _SuggestionView({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    this.distanceMeters,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final int? distanceMeters;
}

Future<DeliveryMapPickerResult?> showDeliveryMapPicker({
  required BuildContext context,
  required ll.LatLng initialPoint,
  required DeliveryFetchSuggestions fetchSuggestions,
  required DeliveryResolveSuggestion resolveSuggestion,
}) {
  return AppPopupDialog.show<DeliveryMapPickerResult>(
    context: context,
    builder: (_) => DeliveryMapPickerDialog(
      initialPoint: initialPoint,
      fetchSuggestions: fetchSuggestions,
      resolveSuggestion: resolveSuggestion,
    ),
  );
}
