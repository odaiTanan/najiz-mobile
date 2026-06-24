import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/profile/models/user_address.dart';

/// Bottom sheet for choosing delivery location — current GPS, saved addresses,
/// or add new (same UX as profile «عناويني» data).
class DeliveryAddressPickerSheet extends StatelessWidget {
  const DeliveryAddressPickerSheet({
    super.key,
    required this.savedAddresses,
    required this.isLoadingAddresses,
    required this.selectedAddressId,
    required this.onUseCurrentLocation,
    required this.onSelectSaved,
    required this.onAddNewAddress,
    required this.onPickFromMap,
    this.showLoginHint = false,
    this.mapLocationSelected = false,
  });

  final List<UserAddress> savedAddresses;
  final bool isLoadingAddresses;
  final int? selectedAddressId;
  final bool mapLocationSelected;
  final VoidCallback onUseCurrentLocation;
  final ValueChanged<UserAddress> onSelectSaved;
  final VoidCallback onAddNewAddress;
  final VoidCallback onPickFromMap;
  final bool showLoginHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  const SizedBox(width: 40),
                  Expanded(
                    child: Text(
                      'address.deliveryLabel'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionTile(
                      title: 'address.useCurrentLocationTitle'.tr,
                      subtitle: 'address.useCurrentLocationHint'.tr,
                      icon: Icons.my_location_rounded,
                      selected:
                          selectedAddressId == null && !mapLocationSelected,
                      onTap: onUseCurrentLocation,
                    ),
                    const SizedBox(height: 6),
                    _ActionTile(
                      title: 'address.pickFromMapTitle'.tr,
                      subtitle: 'address.pickFromMapHint'.tr,
                      icon: Icons.map_outlined,
                      selected: mapLocationSelected,
                      onTap: onPickFromMap,
                    ),
                    const SizedBox(height: 6),
                    _ActionTile(
                      title: 'address.addNew'.tr,
                      subtitle: 'address.addNewHint'.tr,
                      icon: Icons.add_circle_outline_rounded,
                      selected: false,
                      onTap: onAddNewAddress,
                    ),
                    if (showLoginHint) ...[
                      const SizedBox(height: 12),
                      Text(
                        'checkout.loginForSavedAddresses'.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ] else if (isLoadingAddresses) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ] else if (savedAddresses.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'address.savedAddressesTitle'.tr,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...savedAddresses.map(
                        (address) => _SavedAddressTile(
                          address: address,
                          selected: selectedAddressId == address.id,
                          onTap: () => onSelectSaved(address),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  const _SavedAddressTile({
    required this.address,
    required this.selected,
    required this.onTap,
  });

  final UserAddress address;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = address.title.trim().isNotEmpty
        ? address.title.trim()
        : 'address.savedFallbackTitle'.tr;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      address.toPickerSubtitle(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.location_on_outlined,
                color: selected ? AppColors.primary : cs.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
