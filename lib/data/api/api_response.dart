import 'dart:convert';

/// Shared JSON parsing and envelope helpers for API responses.
class ApiResponse {
  ApiResponse._();

  static Map<String, dynamic> safeDecodeMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static dynamic safeDecodeAny(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static bool isSuccess(Map<String, dynamic> data) {
    final success = data['success'];
    if (success is bool) return success;
    final status = data['status'];
    if (status is bool) return status;
    final statusText = data['status']?.toString().toLowerCase();
    return statusText == 'success';
  }

  static String extractMessage(
    Map<String, dynamic> data, {
    bool includeValidationErrors = false,
  }) {
    final message = data['message'] ?? data['error'];
    if (message != null) return message.toString();

    if (includeValidationErrors) {
      final errors = data['errors'];
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value != null) return value.toString();
        }
      }
    }

    return 'فشل الطلب';
  }

  static List<Map<String, dynamic>> asMapList(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
        .toList();
  }

  static Map<String, dynamic> asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> extractDataMap(
    dynamic data, {
    Map<String, dynamic>? fallback,
  }) {
    final root = asMap(data);
    final inner = root['data'];
    if (inner is Map<String, dynamic>) return inner;
    if (inner is Map) {
      return inner.map((k, v) => MapEntry(k.toString(), v));
    }
    if (root.isNotEmpty) return root;
    return fallback ?? <String, dynamic>{};
  }

  static List<Map<String, dynamic>> extractDataList(dynamic data) {
    final root = asMap(data);
    final inner = root.isNotEmpty ? (root['data'] ?? data) : data;
    if (inner is List) {
      return inner
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();
    }
    return const [];
  }

  static int? asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static bool asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final normalized = value?.toString().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
}
