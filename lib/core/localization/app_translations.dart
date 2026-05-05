import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:get/get.dart';

class AppTranslations extends Translations {
  AppTranslations._(this._keys);

  final Map<String, Map<String, String>> _keys;

  static AppTranslations? _instance;

  static AppTranslations get instance {
    final current = _instance;
    if (current == null) {
      throw StateError('AppTranslations is not initialized');
    }
    return current;
  }

  static Future<void> init() async {
    final arRaw = await rootBundle.loadString('assets/i18n/ar.json');
    final enRaw = await rootBundle.loadString('assets/i18n/en.json');

    final arFlat = _flattenMap(jsonDecode(arRaw));
    final enFlat = _flattenMap(jsonDecode(enRaw));
    _instance = AppTranslations._({
      'ar_SA': arFlat,
      'ar': arFlat,
      'en_US': enFlat,
      'en': enFlat,
    });
  }

  @override
  Map<String, Map<String, String>> get keys => _keys;
}

Map<String, String> _flattenMap(dynamic input, [String prefix = '']) {
  final result = <String, String>{};
  if (input is! Map) return result;

  input.forEach((rawKey, rawValue) {
    final key = rawKey.toString();
    final fullKey = prefix.isEmpty ? key : '$prefix.$key';
    if (rawValue is Map) {
      result.addAll(_flattenMap(rawValue, fullKey));
      return;
    }
    result[fullKey] = rawValue?.toString() ?? '';
  });

  return result;
}
