import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Writes rendered stepper assets for the Android background bridge fallback.
class OrderNotificationCacheWriter {
  static Future<void> write({
    required int orderId,
    required Uint8List? stepperPng,
    required int stepIndex,
    required int stepTotal,
    required bool isFinished,
    required String title,
    required String body,
  }) async {
    if (orderId <= 0) return;
    try {
      final orderDir = await _orderNotifDir();
      if (!await orderDir.exists()) {
        await orderDir.create(recursive: true);
      }

      final metaFile = File('${orderDir.path}/$orderId.json');
      await metaFile.writeAsString(
        jsonEncode({
          'order_id': orderId,
          'step': stepIndex,
          'step_total': stepTotal,
          'is_finished': isFinished,
          'title': title,
          'body': body,
        }),
        flush: true,
      );

      final pngFile = File('${orderDir.path}/$orderId.png');
      if (stepperPng != null && stepperPng.isNotEmpty) {
        await pngFile.writeAsBytes(stepperPng, flush: true);
      }
    } catch (_) {
      // Cache is best-effort for background delivery.
    }
  }

  /// Removes all cached order-notification assets for the previous session.
  static Future<void> clearAll() async {
    try {
      final orderDir = await _orderNotifDir();
      if (await orderDir.exists()) {
        await orderDir.delete(recursive: true);
      }
    } catch (_) {
      // Best-effort cleanup during session invalidation.
    }
  }

  static Future<Directory> _orderNotifDir() async {
    final cacheDir = await getTemporaryDirectory();
    return Directory('${cacheDir.path}/order_notif');
  }
}
