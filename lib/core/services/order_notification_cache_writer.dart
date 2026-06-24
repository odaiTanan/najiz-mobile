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
      final cacheDir = await getTemporaryDirectory();
      final orderDir = Directory('${cacheDir.path}/order_notif');
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
}
