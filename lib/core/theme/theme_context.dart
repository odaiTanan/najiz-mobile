import 'package:flutter/material.dart';

/// وصول سريع لألوان الثيم دون تكرار [Color(0x…)] في كل شاشة.
extension ThemeContextX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;

  /// خلفية الصفحة (تحت البطاقات).
  Color get uiPage => Theme.of(this).scaffoldBackgroundColor;

  /// بطاقة / لوح أبيض في الفاتح، داكن في الليل.
  Color get uiCard => cs.surface;

  /// حدود خفيفة.
  Color get uiHairline => cs.outlineVariant;

  /// نص رئيسي.
  Color get uiText => cs.onSurface;

  /// نص ثانوي.
  Color get uiSubtext => cs.onSurfaceVariant;

  /// خلفية مربعات أيقونة / حقول خفيفة.
  Color get uiMutedFill => cs.surfaceContainerHigh;

  Brightness get uiBrightness => Theme.of(this).brightness;

  bool get uiDark => uiBrightness == Brightness.dark;
}
