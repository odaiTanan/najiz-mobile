import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// OneSignal often nests Laravel `data` under [rawPayload] (`custom`, `custom.a`, …).
/// Without this merge, [additionalData] may miss `type` / `order_id` until later payloads.
Map<String, dynamic> mergeOneSignalNotificationData(OSNotification notification) {
  final out = <String, dynamic>{};

  void mergeIn(Map<String, dynamic>? source) {
    if (source == null) return;
    for (final e in source.entries) {
      if (e.value == null) continue;
      out[e.key] = e.value;
    }
  }

  mergeIn(notification.additionalData);

  final raw = notification.rawPayload;
  if (raw == null) return out;

  mergeIn(raw.cast<String, dynamic>());

  final custom = raw['custom'];
  if (custom is String && custom.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(custom);
      if (decoded is Map) {
        mergeIn(decoded.cast<String, dynamic>());
        final a = decoded['a'];
        if (a is Map) mergeIn(a.cast<String, dynamic>());
      }
    } catch (_) {}
  } else if (custom is Map) {
    final cm = custom.cast<String, dynamic>();
    mergeIn(cm);
    final a = cm['a'];
    if (a is Map) mergeIn(a.cast<String, dynamic>());
  }

  final data = raw['data'];
  if (data is Map) mergeIn(data.cast<String, dynamic>());

  return out;
}

List<String> stepperLabelsForOrderType(String orderType) {
  switch (orderType) {
    case 'taxi':
      return const ['تم الطلب', 'مقبول', 'في الطريق', 'الرحلة'];
    case 'shipping':
      return const ['تم الطلب', 'مقبول', 'الاستلام', 'بالطريق', 'تم التوصيل'];
    default:
      return const ['تم الطلب', 'مقبول', 'تحضير', 'استلام', 'بالطريق'];
  }
}

int defaultStepTotalForOrderType(String orderType) {
  switch (orderType) {
    case 'taxi':
      return 4;
    case 'shipping':
      return 5;
    default:
      return 5;
  }
}

enum _StepperServiceStyle { taxi, shipping, restaurant, store }

_StepperServiceStyle _stepperStyle(String orderType, bool isStore) {
  switch (orderType) {
    case 'taxi':
      return _StepperServiceStyle.taxi;
    case 'shipping':
      return _StepperServiceStyle.shipping;
    default:
      return isStore ? _StepperServiceStyle.store : _StepperServiceStyle.restaurant;
  }
}

/// نفس أسلوب الأيقونات المستخدم في الشاشات (Outlined) — راجع my_orders_screen / taxi_booking / shipping.
List<IconData> _notificationStepperIcons(String orderType, bool isStore) {
  switch (_stepperStyle(orderType, isStore)) {
    case _StepperServiceStyle.taxi:
      return const [
        Icons.receipt_long_outlined,
        Icons.place_outlined,
        Icons.local_taxi_outlined,
        Icons.flag_outlined,
      ];
    case _StepperServiceStyle.shipping:
      return const [
        Icons.inventory_2_outlined,
        Icons.task_alt_outlined,
        Icons.local_shipping_outlined,
        Icons.route_outlined,
        Icons.home_outlined,
      ];
    case _StepperServiceStyle.store:
      return const [
        Icons.storefront_outlined,
        Icons.shopping_bag_outlined,
        Icons.inventory_2_outlined,
        Icons.takeout_dining_outlined,
        Icons.flag_outlined,
      ];
    case _StepperServiceStyle.restaurant:
      return const [
        Icons.receipt_long_outlined,
        Icons.restaurant_outlined,
        Icons.restaurant_menu_outlined,
        Icons.takeout_dining_outlined,
        Icons.flag_outlined,
      ];
  }
}

void _drawMaterialGlyph(
  Canvas canvas,
  Offset center,
  IconData icon,
  double fontSize,
  Color color,
) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontFamily: icon.fontFamily ?? 'MaterialIcons',
        fontSize: fontSize,
        color: color,
        height: 1.0,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  );
  tp.layout(maxWidth: fontSize * 2.5);
  tp.paint(
    canvas,
    Offset(
      center.dx - tp.width / 2,
      center.dy - tp.height / 2,
    ),
  );
}

/// RTL stepper: first step on the right. [activeIndex] 0..[stepCount]-1.
Future<Uint8List?> renderOrderStepperPng({
  required List<String> labels,
  required int activeIndex,
  bool allComplete = false,
  String orderType = '',
  bool isStore = false,
}) async {
  if (labels.isEmpty) return null;
  final stepCount = labels.length;
  final safeActive = activeIndex.clamp(0, stepCount - 1);

  const width = 1080.0;
  const height = 248.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFFF1F3F7),
  );

  const margin = 40.0;
  const nodeY = 68.0;
  const nodeRadius = 42.0;
  const lineThickness = 11.0;
  final usable = width - 2 * margin;
  final gap = stepCount <= 1 ? 0.0 : usable / (stepCount - 1);

  const lineY = nodeY;
  const brand = Color(0xFFFF8A00);
  const track = Color(0xFFD8DEE8);
  const ink = Color(0xFF0F172A);
  const muted = Color(0xFF64748B);

  final iconSet = _notificationStepperIcons(orderType, isStore);
  IconData stepGlyph(int i) =>
      iconSet[i < iconSet.length ? i : iconSet.length - 1];

  for (int i = 0; i < stepCount - 1; i++) {
    final xRight = width - margin - i * gap;
    final xLeft = width - margin - (i + 1) * gap;
    final segmentDone = allComplete || i < safeActive;
    canvas.drawLine(
      Offset(xLeft, lineY),
      Offset(xRight, lineY),
      Paint()
        ..color = track
        ..strokeWidth = lineThickness + 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(xLeft, lineY),
      Offset(xRight, lineY),
      Paint()
        ..color = segmentDone ? brand : track
        ..strokeWidth = lineThickness
        ..strokeCap = StrokeCap.round,
    );
  }

  for (int i = 0; i < stepCount; i++) {
    final cx = width - margin - i * gap;
    final r = nodeRadius;
    final done = allComplete || i < safeActive;
    final current = !allComplete && i == safeActive;
    final stepIcon = stepGlyph(i);

    if (done) {
      canvas.drawCircle(Offset(cx, nodeY), r + 3, Paint()..color = brand.withValues(alpha: 0.2));
      canvas.drawCircle(Offset(cx, nodeY), r, Paint()..color = brand);
      _drawMaterialGlyph(canvas, Offset(cx, nodeY), stepIcon, 40, Colors.white);
    } else if (current) {
      canvas.drawCircle(Offset(cx, nodeY), r + 4, Paint()..color = brand.withValues(alpha: 0.32));
      canvas.drawCircle(Offset(cx, nodeY), r + 1.5, Paint()..color = brand);
      canvas.drawCircle(Offset(cx, nodeY), r - 1.5, Paint()..color = ink);
      _drawMaterialGlyph(canvas, Offset(cx, nodeY), stepIcon, 42, Colors.white);
    } else {
      canvas.drawCircle(Offset(cx, nodeY), r + 2, Paint()..color = const Color(0xFFE2E8F0));
      canvas.drawCircle(Offset(cx, nodeY), r, Paint()..color = Colors.white);
      canvas.drawCircle(
        Offset(cx, nodeY),
        r,
        Paint()
          ..color = const Color(0xFFBAC4D4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _drawMaterialGlyph(canvas, Offset(cx, nodeY), stepIcon, 36, muted);
    }

    final label = i < labels.length ? labels[i] : '';
    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: 16,
        height: 1.25,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        maxLines: 2,
        fontWeight: current ? FontWeight.w800 : FontWeight.w600,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: current ? ink : const Color(0xFF334155),
      ))
      ..addText(label);
    final paragraph = pb.build()
      ..layout(ui.ParagraphConstraints(width: gap + 48));
    canvas.drawParagraph(
      paragraph,
      Offset(cx - (gap + 48) / 2, nodeY + r + 14),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width.ceil(), height.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}
