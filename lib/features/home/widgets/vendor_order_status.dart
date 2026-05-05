import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Normalizes API `vendor_status`: `available` | `busy` | `not_accepting`.
abstract final class VendorOrderStatus {
  static String? normalized(String? raw) {
    var t = raw?.trim().toLowerCase();
    if (t == null || t.isEmpty) return null;
    t = t.replaceAll(RegExp(r'[\s-]+'), '_');
    if (t == 'available' || t == 'busy' || t == 'not_accepting') return t;
    if (t.contains('not_accept')) return 'not_accepting';
    if (t.contains('busy')) return 'busy';
    return t;
  }

  /// Treats missing/unknown status as accepting orders (legacy APIs).
  static bool acceptsOrders(String? raw) {
    final n = normalized(raw);
    if (n == null) return true;
    if (n == 'busy' || n == 'not_accepting') return false;
    return true;
  }

  static bool showsBlockingBanner(String? raw) {
    final n = normalized(raw);
    return n == 'busy' || n == 'not_accepting';
  }

  static bool _isEnglishLocale() =>
      Get.locale?.languageCode.toLowerCase() == 'en';

  /// Top dark strip on vendor image: only [busy] / [not_accepting], not [available].
  static String? blockingBannerMessage(
    String? vendorStatus, {
    required bool isStore,
  }) {
    if (!showsBlockingBanner(vendorStatus)) return null;
    final n = normalized(vendorStatus)!;
    if (_isEnglishLocale()) {
      final u = isStore ? 'This store' : 'This restaurant';
      switch (n) {
        case 'busy':
          return '$u is busy right now — try again shortly';
        case 'not_accepting':
          return '$u is not accepting orders right now';
        default:
          return null;
      }
    }
    final u = isStore ? 'المتجر' : 'المطعم';
    switch (n) {
      case 'busy':
        return '$u مزدحم حالياً، حاول بعد قليل';
      case 'not_accepting':
        return '$u لا يستقبل طلبات حالياً';
      default:
        return null;
    }
  }

  static Color statusDotColor(String? vendorStatus) {
    if (showsBlockingBanner(vendorStatus)) {
      return const Color(0xFFC43D3D);
    }
    return const Color(0xFF1B8E4B);
  }

  /// Short label next to the status dot (embedded strings so UI never shows raw i18n keys).
  static String shortLabel(String? vendorStatus) {
    final n = normalized(vendorStatus);
    if (_isEnglishLocale()) {
      switch (n) {
        case 'busy':
          return 'Busy';
        case 'not_accepting':
          return 'Not accepting';
        case 'available':
        default:
          return 'Available';
      }
    }
    switch (n) {
      case 'busy':
        return 'مشغول';
      case 'not_accepting':
        return 'لا يقبل الطلبات';
      case 'available':
      default:
        return 'متاح';
    }
  }

  /// Message when user tries to add to cart while [busy] / [not_accepting].
  static String cannotAddToCartMessage(
    String? vendorStatus, {
    required bool isStore,
  }) {
    final n = normalized(vendorStatus);
    if (_isEnglishLocale()) {
      if (n == 'not_accepting') {
        return isStore
            ? 'This store is not accepting orders right now.'
            : 'This restaurant is not accepting orders right now.';
      }
      return isStore
          ? 'This store is busy. Please try again later.'
          : 'The restaurant is busy. Please try again later.';
    }
    if (n == 'not_accepting') {
      return isStore
          ? 'المتجر لا يستقبل طلبات حالياً.'
          : 'المطعم لا يستقبل طلبات حالياً.';
    }
    return isStore
        ? 'المتجر مزدحم، حاول لاحقاً.'
        : 'المطعم مزدحم، حاول لاحقاً.';
  }
}

/// Pill with colored dot for API order status, or legacy active/inactive when unknown.
class VendorOrderStatusPill extends StatelessWidget {
  const VendorOrderStatusPill({
    super.key,
    required this.vendorStatus,
    required this.isActive,
  });

  final String? vendorStatus;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final n = VendorOrderStatus.normalized(vendorStatus);
    if (n == 'available' || n == 'busy' || n == 'not_accepting') {
      final dot = VendorOrderStatus.statusDotColor(vendorStatus);
      final label = VendorOrderStatus.shortLabel(vendorStatus);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A2B48),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final bgColor =
        isActive ? const Color(0xFFE8F7EE) : const Color(0xFFFFF1F1);
    final fgColor =
        isActive ? const Color(0xFF1B8E4B) : const Color(0xFFC43D3D);
    final label = isActive ? 'services.active'.tr : 'services.inactive'.tr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fgColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
