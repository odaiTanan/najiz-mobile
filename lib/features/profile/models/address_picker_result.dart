import 'package:latlong2/latlong.dart';

class AddressPickerResult {
  const AddressPickerResult({
    required this.point,
    required this.address,
  });

  final LatLng point;
  final String address;
}
