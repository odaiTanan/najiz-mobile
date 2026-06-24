import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/core/network/api_error_mapper.dart';
import 'package:najiz_go_express/core/peak_hour/errors/peak_hour_api_exception.dart';
import 'package:najiz_go_express/core/peak_hour/models/peak_hour_status.dart';
import 'package:najiz_go_express/data/api/api_client.dart';

class PeakHourRepository {
  PeakHourRepository({ApiClient? apiClient})
      : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<T> _run<T>(Future<T> Function() action) {
    return runWithMappedApiErrors(action, PeakHourApiException.fromHome);
  }

  Future<PeakHourStatus> getPeakHourStatus({String? token}) {
    return _run(() async {
      final data = await _api.getEnvelope(
        path: Endpoints.peakHourStatus,
        token: token,
      );
      final payload = data['data'];
      if (payload is Map<String, dynamic>) {
        return PeakHourStatus.fromJson(payload);
      }
      if (payload is Map) {
        return PeakHourStatus.fromJson(
          payload.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return const PeakHourStatus(isPeakHour: false, enabled: false);
    });
  }
}
