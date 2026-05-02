import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFFF8A00);
  static const Color primaryLight = Color(0xFFFFB347);
  static const Color primaryDark = Color(0xFFFF6A00);
  static const Color accent = Color(0xFFE86F00);
  static const Color background = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0D253C);
  static const Color textSecondary = Color(0xFF707070);
  static const Color inputBorder = Color(0xFFE0E0E0);
  static const Color error = Color(0xFFFF3B30);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark],
  );
}

