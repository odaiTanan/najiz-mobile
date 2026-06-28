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
  static bool acceptsOrders(String? raw, {required bool isOpened}) {
    if (!isOpened) return false;
    final n = normalized(raw);
    if (n == null) return true;
    if (n == 'busy' || n == 'not_accepting') return false;
    return true;
  }

  static bool showsBlockingBanner(String? raw) {
    final n = normalized(raw);
    return n == 'busy' || n == 'not_accepting';
  }

  /// Top dark strip on vendor image: only [busy] / [not_accepting], not [available].
  static String? blockingBannerMessage(
    String? vendorStatus, {
    required bool isStore,
    required bool isOpened,
  }) {
    if (!isOpened) {
      final unit = isStore ? 'vendor.store'.tr : 'vendor.restaurant'.tr;
      return '$unit ${'search.statusClosed'.tr}';
    }
    if (!showsBlockingBanner(vendorStatus)) return null;
    final n = normalized(vendorStatus)!;
    if (isStore) {
      return n == 'busy'
          ? 'vendor.storeBusyBanner'.tr
          : 'vendor.storeNotAcceptingBanner'.tr;
    }
    return n == 'busy'
        ? 'vendor.restaurantBusyBanner'.tr
        : 'vendor.restaurantNotAcceptingBanner'.tr;
  }

  static Color statusDotColor(
    String? vendorStatus, {
    required bool isOpened,
  }) {
    if (!isOpened) {
      return const Color(0xFFC43D3D);
    }
    if (showsBlockingBanner(vendorStatus)) {
      return const Color(0xFFC43D3D);
    }
    return const Color(0xFF1B8E4B);
  }

  /// Short label next to the status dot.
  static String shortLabel(
    String? vendorStatus, {
    required bool isOpened,
    required bool isStore,
  }) {
    if (!isOpened) {
      final unit = isStore ? 'vendor.store'.tr : 'vendor.restaurant'.tr;
      return '$unit ${'search.statusClosed'.tr}';
    }
    final n = normalized(vendorStatus);
    switch (n) {
      case 'busy':
        return 'vendor.statusBusy'.tr;
      case 'not_accepting':
        return 'vendor.statusNotAccepting'.tr;
      case 'available':
      default:
        return 'vendor.statusAvailable'.tr;
    }
  }

  /// Message when user tries to add to cart while [busy] / [not_accepting].
  static String cannotAddToCartMessage(
    String? vendorStatus, {
    required bool isStore,
    required bool isOpened,
  }) {
    if (!isOpened) {
      return 'vendor.closedCannotOrder'.trParams({
        'unit': isStore ? 'vendor.store'.tr : 'vendor.restaurant'.tr,
      });
    }
    final n = normalized(vendorStatus);
    if (isStore) {
      return n == 'not_accepting'
          ? 'vendor.storeNotAcceptingCart'.tr
          : 'vendor.storeBusyCart'.tr;
    }
    return n == 'not_accepting'
        ? 'vendor.restaurantNotAcceptingCart'.tr
        : 'vendor.restaurantBusyCart'.tr;
  }
}

/// Pill with colored dot for API order status, or legacy active/inactive when unknown.
class VendorOrderStatusPill extends StatelessWidget {
  const VendorOrderStatusPill({
    super.key,
    required this.vendorStatus,
    required this.isActive,
    required this.isOpened,
    required this.isStore,
  });

  final String? vendorStatus;
  final bool isActive;
  final bool isOpened;
  final bool isStore;

  @override
  Widget build(BuildContext context) {
    if (!isOpened) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          VendorOrderStatus.shortLabel(
            vendorStatus,
            isOpened: isOpened,
            isStore: isStore,
          ),
          style: const TextStyle(
            color: Color(0xFFC43D3D),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final n = VendorOrderStatus.normalized(vendorStatus);
    if (n == 'available' || n == 'busy' || n == 'not_accepting') {
      final dot = VendorOrderStatus.statusDotColor(
        vendorStatus,
        isOpened: isOpened,
      );
      final label = VendorOrderStatus.shortLabel(
        vendorStatus,
        isOpened: isOpened,
        isStore: isStore,
      );
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
