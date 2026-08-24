import 'package:najiz_go_express/core/di/network_dependencies.dart';
import 'package:najiz_go_express/data/api/api_client.dart';
import 'package:najiz_go_express/features/support/models/support_settings.dart';

class SupportSettingsRepository {
  SupportSettingsRepository({ApiClient? apiClient})
    : _api = apiClient ?? resolveApiClient();

  final ApiClient _api;

  Future<SupportSettings> getSettings() async {
    try {
      final response = await _api.getEnvelope(
        path: Endpoints.supportSettings,
        retries: 0,
      );

      final raw = response['data'];

      if (raw is Map<String, dynamic>) {
        return SupportSettings.fromJson(raw);
      }

      if (raw is Map) {
        return SupportSettings.fromJson(
          raw.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // Backend setting endpoint may not exist yet.
    }

    return SupportSettings.fallback;
  }
}
