import 'package:flutter/material.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';

/// تنسيق موحّد للبوب أب يتبع ثيم الفاتح/الداكن.
class AppPopupDialog {
  AppPopupDialog._();

  static ThemeData scopeTheme(BuildContext context) {
    final base = Theme.of(context);
    final cs = base.colorScheme;
    final dialogSurface = cs.surface;
    return base.copyWith(
      colorScheme: cs.copyWith(
        surface: dialogSurface,
        surfaceDim: dialogSurface,
        surfaceBright: dialogSurface,
        surfaceContainerLowest: dialogSurface,
        surfaceContainerLow: dialogSurface,
        surfaceContainer: dialogSurface,
        surfaceContainerHigh: dialogSurface,
        surfaceContainerHighest: dialogSurface,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: dialogSurface,
        surfaceTintColor: Colors.transparent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: dialogSurface,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: dialogSurface,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  static Widget wrap(BuildContext context, Widget child) {
    return Theme(
      data: scopeTheme(context),
      child: child,
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext context) builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      builder: (ctx) => wrap(ctx, builder(ctx)),
    );
  }

  /// لـ `Dialog` / `Get.dialog` — كارد يتبع السطح الحالي.
  static BoxDecoration cardDecoration(BuildContext context, {double radius = 16}) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    );
  }

  static ShapeBorder dialogShape({double radius = 16}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
}
