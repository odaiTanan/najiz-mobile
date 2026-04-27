import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/constants/app_colors.dart';

const String _mapsApiKey = String.fromEnvironment(
  'MAPS_API_KEY',
  defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
);

class ProfileAddressEditorScreen extends StatefulWidget {
  const ProfileAddressEditorScreen({
    super.key,
    this.initialAddress,
    required this.onSave,
  });

  final String? initialAddress;
  final Future<void> Function(String address) onSave;

  @override
  State<ProfileAddressEditorScreen> createState() =>
      _ProfileAddressEditorScreenState();
}

class _ProfileAddressEditorScreenState extends State<ProfileAddressEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _areaController = TextEditingController();
  final _streetController = TextEditingController();
  final _detailsController = TextEditingController();

  ll.LatLng _selectedPoint = const ll.LatLng(33.5138, 36.2765);
  String? _selectedAddress;
  bool _isSaving = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAddress?.trim();
    if (initial != null && initial.isNotEmpty) {
      _selectedAddress = initial;
    }
    _bootstrapLocation();
  }

  Future<void> _bootstrapLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final current = ll.LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _selectedPoint = current);
      if (_selectedAddress == null) {
        final label = await _reverseGeocode(current);
        if (!mounted) return;
        setState(() => _selectedAddress = label);
      }
    } catch (_) {}
  }

  Future<String> _reverseGeocode(ll.LatLng point) async {
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${point.latitude},${point.longitude}',
        'language': 'ar',
        'region': 'sy',
        'key': _mapsApiKey,
      },
    );
    try {
      final res = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final results = body['results'];
        final text = (results is List && results.isNotEmpty)
            ? (results.first['formatted_address'] as String?)?.trim()
            : null;
        if (text != null && text.isNotEmpty) {
          return text;
        }
      }
    } catch (_) {}
    return '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
  }

  Future<void> _searchByName() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _isSearching) return;
    setState(() => _isSearching = true);
    try {
      final suggestUrl = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': query,
          'language': 'ar',
          'components': 'country:sy',
          'key': _mapsApiKey,
        },
      );
      final suggestRes = await http.get(
        suggestUrl,
        headers: const {'Accept': 'application/json'},
      );
      if (suggestRes.statusCode != 200) {
        _showSnack('خطأ', 'تعذر تنفيذ البحث');
        return;
      }
      final suggestBody = jsonDecode(suggestRes.body);
      if (suggestBody is! Map<String, dynamic>) {
        _showSnack('خطأ', 'تعذر قراءة نتائج البحث');
        return;
      }
      final predictions = suggestBody['predictions'];
      if (predictions is! List || predictions.isEmpty) {
        _showSnack('تنبيه', 'لا توجد نتائج داخل سوريا');
        return;
      }
      final first = Map<String, dynamic>.from(predictions.first as Map);
      final placeId = (first['place_id'] ?? '').toString().trim();
      if (placeId.isEmpty) {
        _showSnack('خطأ', 'تعذر قراءة الموقع');
        return;
      }
      final detailsUrl = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields': 'geometry/location,formatted_address',
          'language': 'ar',
          'key': _mapsApiKey,
        },
      );
      final detailsRes = await http.get(
        detailsUrl,
        headers: const {'Accept': 'application/json'},
      );
      if (detailsRes.statusCode != 200) {
        _showSnack('خطأ', 'تعذر تحميل تفاصيل الموقع');
        return;
      }
      final detailsBody = jsonDecode(detailsRes.body);
      if (detailsBody is! Map<String, dynamic>) {
        _showSnack('خطأ', 'تعذر قراءة تفاصيل الموقع');
        return;
      }
      final result = (detailsBody['result'] is Map)
          ? Map<String, dynamic>.from(detailsBody['result'] as Map)
          : <String, dynamic>{};
      final geometry = (result['geometry'] is Map)
          ? Map<String, dynamic>.from(result['geometry'] as Map)
          : <String, dynamic>{};
      final location = (geometry['location'] is Map)
          ? Map<String, dynamic>.from(geometry['location'] as Map)
          : <String, dynamic>{};
      final lat = double.tryParse(location['lat']?.toString() ?? '');
      final lng = double.tryParse(location['lng']?.toString() ?? '');
      if (lat == null || lng == null) {
        _showSnack('خطأ', 'تعذر قراءة الموقع');
        return;
      }
      final point = ll.LatLng(lat, lng);
      if (!mounted) return;
      setState(() {
        _selectedPoint = point;
        _selectedAddress =
            (result['formatted_address']?.toString().trim().isNotEmpty ?? false)
            ? result['formatted_address'].toString()
            : _selectedAddress;
      });
      _showSnack('تم', 'تم العثور على الموقع');
    } catch (_) {
      _showSnack('خطأ', 'فشل البحث عن الموقع');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<_AddressPickerResult>(
      MaterialPageRoute(
        builder: (_) => _AddressMapPickerScreen(initialPoint: _selectedPoint),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedPoint = result.point;
      _selectedAddress = result.address;
    });
  }

  Future<void> _saveAddress() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    if (_selectedAddress == null || _selectedAddress!.trim().isEmpty) {
      _showSnack('تنبيه', 'يرجى اختيار عنوان التوصيل أولًا');
      return;
    }

    setState(() => _isSaving = true);
    final builtAddress =
        'العنوان: ${_selectedAddress!.trim()} | اسم العنوان: ${_titleController.text.trim()} | المنطقة: ${_areaController.text.trim()} | الشارع: ${_streetController.text.trim()} | تفاصيل: ${_detailsController.text.trim()}';
    try {
      await widget.onSave(builtAddress);
      if (!mounted) return;
      Navigator.of(context).pop();
      _showSnack('تم', 'تم حفظ عنوان التوصيل بنجاح');
    } catch (_) {
      _showSnack('خطأ', 'تعذر حفظ العنوان');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title: $message')),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _areaController.dispose();
    _streetController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تفاصيل العنوان الجديد',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          children: [
            const Text(
              'اختر عنوان التوصيل',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchByName(),
              decoration: InputDecoration(
                hintText: 'ابحث عن الموقع',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _searchByName,
                        icon: const Icon(Icons.arrow_forward_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE3E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _openMapPicker,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_outlined, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedAddress?.trim().isNotEmpty == true
                            ? _selectedAddress!
                            : 'اضغط لاختيار الموقع من الخريطة',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _openMapPicker,
                      child: Text(
                        _selectedAddress == null ? 'اختيار' : 'تعديل',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'اسم العنوان',
              controller: _titleController,
              hint: 'مثل: منزل، عمل، نادي...',
              validator: _required,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'المنطقة',
              controller: _areaController,
              hint: 'المنطقة',
              validator: _required,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'الشارع',
              controller: _streetController,
              hint: 'الشارع',
              validator: _required,
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'تفاصيل العنوان',
              controller: _detailsController,
              hint: 'مثال: المبنى، الطابق، بجانب...',
              validator: _required,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'حفظ العنوان',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'هذا الحقل مطلوب';
    return null;
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final String? Function(String?) validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE3E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.error, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddressMapPickerScreen extends StatefulWidget {
  const _AddressMapPickerScreen({required this.initialPoint});

  final ll.LatLng initialPoint;

  @override
  State<_AddressMapPickerScreen> createState() => _AddressMapPickerScreenState();
}

class _AddressMapPickerScreenState extends State<_AddressMapPickerScreen> {
  late ll.LatLng _selectedPoint;
  String _resolvedAddress = 'جاري تحديد العنوان...';
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
    _resolveCurrentPoint();
  }

  Future<void> _resolveCurrentPoint() async {
    if (_isResolving) return;
    setState(() => _isResolving = true);
    final url = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '${_selectedPoint.latitude},${_selectedPoint.longitude}',
        'language': 'ar',
        'region': 'sy',
        'key': _mapsApiKey,
      },
    );
    try {
      final res = await http.get(
        url,
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final results = body['results'];
        final label = (results is List && results.isNotEmpty)
            ? (results.first['formatted_address'] as String?)?.trim()
            : null;
        if (label != null && label.isNotEmpty && mounted) {
          setState(() => _resolvedAddress = label);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _resolvedAddress = 'تعذر تحديد العنوان، يمكنك التأكيد');
      }
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'اختر عنوان التوصيل',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  widget.initialPoint.latitude,
                  widget.initialPoint.longitude,
                ),
                zoom: 15,
              ),
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onTap: (point) {
                setState(() => _selectedPoint = ll.LatLng(point.latitude, point.longitude));
                _resolveCurrentPoint();
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Text(
                  _resolvedAddress,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isResolving
                        ? null
                        : () => Navigator.of(context).pop(
                              _AddressPickerResult(
                                point: _selectedPoint,
                                address: _resolvedAddress,
                              ),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'تأكيد الموقع',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressPickerResult {
  const _AddressPickerResult({required this.point, required this.address});

  final ll.LatLng point;
  final String address;
}
