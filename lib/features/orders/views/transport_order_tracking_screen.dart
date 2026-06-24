import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/core/widgets/app_popup_dialog.dart';
import 'package:najiz_go_express/core/widgets/app_snackbar.dart';
import 'package:najiz_go_express/core/utils/delivery_eta_helper.dart';
import 'package:najiz_go_express/features/orders/models/order_driver_info.dart';
import 'package:najiz_go_express/features/orders/controllers/transport_order_tracking_controller.dart';
import 'package:najiz_go_express/features/orders/widgets/estimated_delivery_eta_card.dart';
import 'package:najiz_go_express/features/orders/widgets/order_driver_info_card.dart';
import 'package:najiz_go_express/features/orders/widgets/taxi_trip_sos_button.dart';
import 'package:najiz_go_express/core/routes/app_routes.dart';
import 'package:najiz_go_express/core/services/shipping_order_state.dart';
import 'package:najiz_go_express/core/widgets/shipping_delivery_code_card.dart';
import 'package:url_launcher/url_launcher.dart';

class TransportOrderTrackingScreen extends StatelessWidget {
  const TransportOrderTrackingScreen({
    super.key,
    required this.token,
    required this.orderId,
    required this.orderNumber,
    required this.orderType,
    required this.initialStatus,
    required this.initialDispatchStatus,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
    this.initialTripDistanceKm,
  });

  final String token;
  final int orderId;
  final String orderNumber;
  final String orderType;
  final String initialStatus;
  final String initialDispatchStatus;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;
  final double? initialTripDistanceKm;

  void _handleBack(TransportOrderTrackingController controller) {
    AppRoutes.openHome(token: controller.token, offAll: false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = Get.put(
      TransportOrderTrackingController(
        token: token,
        orderId: orderId,
        orderNumber: orderNumber,
        orderType: orderType,
        initialStatus: initialStatus,
        initialDispatchStatus: initialDispatchStatus,
        pickupPoint: ll.LatLng(pickupLat, pickupLng),
        destinationPoint: ll.LatLng(destinationLat, destinationLng),
        initialTripDistanceKm: initialTripDistanceKm,
      ),
      tag: 'transport-tracking-$orderId',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) {
        if (!didPop) _handleBack(controller);
      },
      child: Scaffold(
        backgroundColor: cs.surfaceContainerLowest,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () async {
              _handleBack(controller);
            },
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          backgroundColor: cs.surfaceContainerLowest,
          foregroundColor: cs.onSurface,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'tracking.title'.tr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: Obx(
            () {
              final showAcceptedLayout = orderType == 'taxi'
                  ? controller.stageIndex >= 1
                  : controller.stageIndex >= 0;
              controller.deliveryEta.value;
              controller.driverInfo.value;
              if (showAcceptedLayout) {
                return _AcceptedTrackingLayout(
                  controller: controller,
                  token: token,
                  orderNumber: orderNumber,
                  orderType: orderType,
                );
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _TopCard(
                    orderNumber: orderNumber,
                    orderType: orderType,
                    connected: controller.isLiveConnected.value,
                  ),
                  if (controller.errorMessage.value != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage.value!,
                      style: TextStyle(color: cs.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (controller.shouldShowShippingDeliveryCode) ...[
                    ShippingDeliveryCodeCard(
                      code: controller.shippingDeliveryCode!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _MapCard(controller: controller, orderType: orderType),
                  const SizedBox(height: 12),
                  OrderDriverInfoCard(
                    driver: controller.driverInfo.value,
                    token: token,
                  ),
                  const SizedBox(height: 12),
                  _TransportTimelineCard(
                    currentIndex: controller.stageIndex,
                    orderType: orderType,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AcceptedTrackingLayout extends StatelessWidget {
  const _AcceptedTrackingLayout({
    required this.controller,
    required this.token,
    required this.orderNumber,
    required this.orderType,
  });

  final TransportOrderTrackingController controller;
  final String token;
  final String orderNumber;
  final String orderType;

  String _titleForStatus() {
    if (orderType == 'shipping') {
      return controller.shippingStatusTitleKey.tr;
    }
    if (controller.currentStatus.value == 'delivered') return 'tracking.tripFinished'.tr;
    if (controller.isTripInProgress) return 'tracking.headingToDestination'.tr;
    if (controller.isHeadingToPickup) return 'tracking.driverHeadingToYou'.tr;
    return 'tracking.orderAcceptedByDriver'.tr;
  }

  String _subtitleForStatus() {
    if (orderType == 'shipping') {
      return _titleForStatus();
    }
    if (controller.currentStatus.value == 'delivered') {
      return 'tracking.thankYouForTrip'.tr;
    }
    if (controller.isTripInProgress) {
      return 'tracking.followDriverLive'.tr;
    }
    if (controller.isHeadingToPickup) {
      return 'tracking.followUntilPickup'.tr;
    }
    return 'tracking.tripPreparing'.tr;
  }

  Future<void> _callDriver() async {
    final phone = controller.driverPhone.value;
    if (phone == null || phone.trim().isEmpty) {
      AppSnackbar.show(
        'tracking.phoneUnavailable'.tr,
        'tracking.phoneWillAppear'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: normalized);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppSnackbar.show(
        'tracking.callFailed'.tr,
        'tracking.tryAgainLater'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _shareTripOnWhatsApp() async {
    final ll.LatLng? driver = controller.driverPoint.value;
    final originLat = (driver ?? controller.pickupPoint).latitude;
    final originLng = (driver ?? controller.pickupPoint).longitude;
    final destLat = controller.destinationPoint.latitude;
    final destLng = controller.destinationPoint.longitude;
    final mapsLink =
        'https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving';
    final message =
        'tracking.shareMessage'.trParams({'orderNumber': orderNumber}) + '\n'
        + 'tracking.driverLabel'.tr + ': ${controller.driverName.value ?? 'tracking.driverUnknown'.tr}\n'
        + 'tracking.shareRoute'.trParams({'link': mapsLink});
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppSnackbar.show(
        'tracking.whatsappFailed'.tr,
        'tracking.whatsappHint'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final eta = controller.deliveryEta.value;
    final driver = controller.driverInfo.value;
    final isTransportTripView = controller.isTripInProgress;
    final isTransportDeliveredView = orderType == 'shipping'
        ? controller.isShippingDelivered
        : controller.currentStatus.value == 'delivered';
    final mapHeight = MediaQuery.of(context).size.height * (isTransportTripView ? 0.6 : 0.52);

    return Column(
      children: [
        SizedBox(
          height: mapHeight,
          child: Stack(
            children: [
              _MapCard(
                controller: controller,
                orderType: orderType,
                height: mapHeight,
              ),
              if (orderType == 'taxi')
                PositionedDirectional(
                  top: 12,
                  start: 12,
                  child: TaxiTripSosButton(
                    controller: controller,
                    floating: true,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _TopCard(
                    orderNumber: orderNumber,
                    orderType: orderType,
                    connected: controller.isLiveConnected.value,
                  ),
                  if (controller.errorMessage.value != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      controller.errorMessage.value!,
                      style: TextStyle(color: cs.error),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (controller.shouldShowShippingDeliveryCode) ...[
                    ShippingDeliveryCodeCard(
                      code: controller.shippingDeliveryCode!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isTransportTripView && !isTransportDeliveredView) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _titleForStatus(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _subtitleForStatus(),
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        EstimatedDeliveryEtaCard(eta: eta, compact: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: OrderDriverSummaryTile(driver: driver),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => AppRoutes.openSupportChat(token: token),
                            icon: const Icon(Icons.support_agent),
                            label: Text('tracking.contactSupport'.tr),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _callDriver,
                            icon: const Icon(Icons.phone_outlined),
                            label: Text('tracking.callDriver'.tr),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (isTransportDeliveredView)
                    _TaxiTripCompletedPanel(
                      controller: controller,
                      orderType: orderType,
                      onRateNow: () => _showTaxiRatingDialog(
                        context: context,
                        controller: controller,
                      ),
                    )
                  else if (!isTransportTripView)
                    _TransportTimelineCard(
                      currentIndex: controller.stageIndex,
                      orderType: orderType,
                    )
                  else
                    _TaxiTripLivePanel(
                      orderType: orderType,
                      eta: eta,
                      driver: driver,
                      controller: controller,
                      deliveryCode: controller.shouldShowShippingDeliveryCode
                          ? controller.shippingDeliveryCode
                          : null,
                      onShareTrip: _shareTripOnWhatsApp,
                      onCallDriver: _callDriver,
                      onOpenSupport: () => AppRoutes.openSupportChat(token: token),
                    ),
                  if (orderType == 'shipping' &&
                      (isTransportTripView || isTransportDeliveredView)) ...[
                    const SizedBox(height: 14),
                    _TransportTimelineCard(
                      currentIndex: controller.stageIndex,
                      orderType: orderType,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaxiTripLivePanel extends StatelessWidget {
  const _TaxiTripLivePanel({
    required this.orderType,
    required this.eta,
    required this.driver,
    required this.controller,
    this.deliveryCode,
    required this.onShareTrip,
    required this.onCallDriver,
    required this.onOpenSupport,
  });

  final String orderType;
  final DeliveryEta? eta;
  final OrderDriverInfo? driver;
  final TransportOrderTrackingController controller;
  final String? deliveryCode;
  final VoidCallback onShareTrip;
  final VoidCallback onCallDriver;
  final VoidCallback onOpenSupport;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = orderType == 'shipping' ? 'tracking.driverOnWayToDelivery'.tr : 'tracking.headingToDestination'.tr;
    final etaText = eta?.minutes != null ? '${eta!.minutes}' : '--';
    final distanceText = eta?.distanceKm != null
        ? 'tracking.etaDistanceLeft'.trParams({'distance': eta!.distanceKm!.toStringAsFixed(1)})
        : 'tracking.waitingDistanceUpdate'.tr;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (deliveryCode != null) ...[
            ShippingDeliveryCodeCard(code: deliveryCode!),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'tracking.followLiveTripLabel'.tr,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      text: etaText,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                      children: [
                        TextSpan(
                          text: 'tracking.minutesAbbr'.tr,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    distanceText,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: OrderDriverSummaryTile(
              driver: driver,
              avatarRadius: 24,
              nameStyle: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
                fontSize: 14,
              ),
              subtitleStyle: TextStyle(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (orderType == 'taxi') ...[
            TaxiTripSosButton(controller: controller),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShareTrip,
                  icon: const Icon(Icons.share_outlined),
                  label: Text('tracking.shareTrip'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCallDriver,
                  icon: const Icon(Icons.phone_outlined),
                  label: Text('tracking.callDriver'.tr),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: onOpenSupport,
              icon: const Icon(Icons.support_agent),
              label: Text('tracking.contactSupport'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxiTripCompletedPanel extends StatelessWidget {
  const _TaxiTripCompletedPanel({
    required this.controller,
    required this.orderType,
    required this.onRateNow,
  });

  final TransportOrderTrackingController controller;
  final String orderType;
  final VoidCallback onRateNow;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final completedTitle = orderType == 'shipping'
        ? 'tracking.deliveredAndHandedOver'.tr
        : 'tracking.tripEndedLabel'.tr;
    final ratingCta = orderType == 'shipping' ? 'tracking.rateOrder'.tr : 'tracking.rateTrip'.tr;
    final distanceKm = controller.tripDistanceKm.value;
    final fare = controller.finalFare.value;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
              SizedBox(width: 8),
              Text(
                completedTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'tracking.tripSummary'.tr,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  context,
                  icon: Icons.route_rounded,
                  label: 'tracking.distanceTraveled'.tr,
                  value: distanceKm != null ? 'tracking.distanceKmLabel'.trParams({'distance': distanceKm.toStringAsFixed(1)}) : '--',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetric(
                  context,
                  icon: Icons.payments_outlined,
                  label: 'tracking.finalPrice'.tr,
                  value: fare != null ? 'tracking.finalPriceSyp'.trParams({'price': fare.toStringAsFixed(0)}) : '--',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(
            () => SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.ratingSubmitted.value ? null : onRateNow,
                icon: const Icon(Icons.star_rounded),
                label: Text(
                  controller.ratingSubmitted.value ? 'tracking.ratingSubmitted'.tr : ratingCta,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.orderNumber,
    required this.orderType,
    required this.connected,
  });

  final String orderNumber;
  final String orderType;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            orderType == 'taxi'
                ? Icons.local_taxi_outlined
                : Icons.local_shipping_outlined,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              orderNumber,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: connected
                    ? Color.alphaBlend(
                        const Color(0xFF0F9D58).withValues(alpha: 0.16),
                        cs.surface,
                      )
                    : Color.alphaBlend(
                        cs.error.withValues(alpha: 0.14),
                        cs.surface,
                      ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                connected ? 'tracking.liveConnected'.tr : 'tracking.liveDisconnected'.tr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: connected ? const Color(0xFF0F9D58) : cs.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showTaxiRatingDialog({
  required BuildContext context,
  required TransportOrderTrackingController controller,
}) async {
  await AppPopupDialog.show<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TaxiTripRatingDialog(controller: controller),
  );
}

class _TaxiTripRatingDialog extends StatefulWidget {
  const _TaxiTripRatingDialog({required this.controller});

  final TransportOrderTrackingController controller;

  @override
  State<_TaxiTripRatingDialog> createState() => _TaxiTripRatingDialogState();
}

class _TaxiTripRatingDialogState extends State<_TaxiTripRatingDialog> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 5;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final comment = _commentController.text.trim();
    if (_rating <= 3 && comment.isEmpty) {
      setState(() => _error = 'tracking.lowRatingNeedsComment'.tr);
      return;
    }
    try {
      await widget.controller.submitTripRating(
        rating: _rating,
        comment: comment.isEmpty ? null : comment,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(
        'tracking.thankYou'.tr,
        'tracking.ratingSentSuccess'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show('tracking.submissionFailed'.tr, e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'tracking.rateYourTrip'.tr,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'tracking.shareExperience'.tr,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            _TaxiRatingStars(
              value: _rating,
              onChanged: (v) {
                setState(() {
                  _rating = v;
                  _error = null;
                });
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: TextStyle(color: cs.onSurface),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: 'tracking.ratingNotesHint'.tr,
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                errorText: _error,
                filled: true,
                fillColor: cs.surfaceContainerHigh,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      backgroundColor: cs.surface,
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('tracking.later'.tr),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Obx(
                    () => FilledButton(
                      onPressed: widget.controller.isSubmittingRating.value ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: widget.controller.isSubmittingRating.value
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text('tracking.submit'.tr),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaxiRatingStars extends StatelessWidget {
  const _TaxiRatingStars({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: List.generate(5, (index) {
        final star = index + 1;
        return IconButton(
          onPressed: () => onChanged(star),
          icon: Icon(
            value >= star ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFF59E0B),
            size: 30,
          ),
          padding: const EdgeInsets.all(0),
          constraints: const BoxConstraints(minWidth: 36),
        );
      }),
    );
  }
}

class _MapCard extends StatefulWidget {
  const _MapCard({
    required this.controller,
    required this.orderType,
    this.height = 250,
  });

  final TransportOrderTrackingController controller;
  final String orderType;
  final double height;

  @override
  State<_MapCard> createState() => _MapCardState();
}

class _MapCardState extends State<_MapCard> {
  static const String _mapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDZ08IdUEAJm7mfGB_nAiX4mH7EkrcvJh8',
  );
  GoogleMapController? _mapController;
  ll.LatLng? _lastFocusedPoint;
  bool _followDriver = false;
  ll.LatLng? _animatedDriverPoint;
  Timer? _driverAnimationTimer;
  BitmapDescriptor? _carMarkerIcon;
  Worker? _driverWorker;
  Worker? _statusWorker;
  Worker? _dispatchWorker;
  StreamSubscription<Position>? _userLocationSub;
  ll.LatLng? _userPoint;
  bool _driverOffRoute = false;
  List<ll.LatLng> _routePoints = const [];

  @override
  void initState() {
    super.initState();
    _prepareCarMarkerIcon();
    final initialDriver = widget.controller.driverPoint.value;
    if (initialDriver != null) {
      _animatedDriverPoint = ll.LatLng(initialDriver.latitude, initialDriver.longitude);
    }
    _driverWorker = ever<ll.LatLng?>(widget.controller.driverPoint, (point) {
      _animateDriverTo(point);
      if (mounted) setState(() {});
    });
    _statusWorker = ever<String>(widget.controller.currentStatus, (_) {
      _refreshRoutePolyline();
      if (mounted) setState(() {});
    });
    _dispatchWorker = ever<String>(widget.controller.currentDispatchStatus, (_) {
      _updateOffRouteState();
      if (mounted) setState(() {});
    });
    _startUserLocationTracking();
    _refreshRoutePolyline();
  }

  @override
  void dispose() {
    _driverWorker?.dispose();
    _statusWorker?.dispose();
    _dispatchWorker?.dispose();
    _driverAnimationTimer?.cancel();
    _userLocationSub?.cancel();
    super.dispose();
  }

  Future<void> _prepareCarMarkerIcon() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 168.0;
    const center = Offset(size / 2, size / 2);

    final shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.2);
    final shellPaint = Paint()..color = const Color(0xFF111827);
    final glassPaint = Paint()..color = const Color(0xFF7DD3FC);
    canvas.drawCircle(center.translate(0, 4), 50, shadowPaint);
    final halo = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(center, 46, halo);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 88, height: 48),
        const Radius.circular(18),
      ),
      shellPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, -5), width: 52, height: 20),
        const Radius.circular(9),
      ),
      glassPaint,
    );
    final wheelPaint = Paint()..color = const Color(0xFFE5E7EB);
    canvas.drawCircle(center.translate(-26, 20), 8, wheelPaint);
    canvas.drawCircle(center.translate(26, 20), 8, wheelPaint);

    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(Icons.directions_car_filled_rounded.codePoint),
        style: TextStyle(
          fontSize: 32,
          fontFamily: Icons.directions_car_filled_rounded.fontFamily,
          package: Icons.directions_car_filled_rounded.fontPackage,
          color: Colors.white,
        ),
      ),
    )..layout();
    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;

    final descriptor = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    if (!mounted) return;
    setState(() => _carMarkerIcon = descriptor);
  }

  void _animateDriverTo(ll.LatLng? nextPoint) {
    _driverAnimationTimer?.cancel();
    if (nextPoint == null) {
      if (mounted) setState(() => _animatedDriverPoint = null);
      return;
    }

    final from = _animatedDriverPoint ?? nextPoint;
    final to = nextPoint;
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      if (mounted) setState(() => _animatedDriverPoint = to);
      return;
    }

    const totalSteps = 20;
    var step = 0;
    _driverAnimationTimer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      step++;
      final t = step / totalSteps;
      final lat = from.latitude + (to.latitude - from.latitude) * t;
      final lng = from.longitude + (to.longitude - from.longitude) * t;
      final point = ll.LatLng(lat, lng);

      if (mounted) {
        setState(() => _animatedDriverPoint = point);
      }
      _updateOffRouteState(point);
      if (_followDriver && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(point.latitude, point.longitude)),
        );
      }

      if (step >= totalSteps) {
        timer.cancel();
        if (mounted) setState(() => _animatedDriverPoint = to);
        _updateOffRouteState(to);
      }
    });
  }

  Future<void> _startUserLocationTracking() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      _userLocationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (!mounted) return;
        setState(() => _userPoint = ll.LatLng(pos.latitude, pos.longitude));
      });
    } catch (_) {
      // User location is optional for trip UI.
    }
  }

  void _updateOffRouteState([ll.LatLng? currentDriver]) {
    final isTaxiOrder = widget.orderType.toLowerCase() == 'taxi';
    final tripInProgress = widget.controller.isTripInProgress;
    if (!isTaxiOrder || !tripInProgress) {
      if (_driverOffRoute) {
        setState(() => _driverOffRoute = false);
      }
      return;
    }
    final driver = currentDriver ?? _animatedDriverPoint ?? widget.controller.driverPoint.value;
    if (driver == null) return;
    final pickup = ll.LatLng(
      widget.controller.pickupPoint.latitude,
      widget.controller.pickupPoint.longitude,
    );
    final destination = ll.LatLng(
      widget.controller.destinationPoint.latitude,
      widget.controller.destinationPoint.longitude,
    );
    final routePoints = _routePoints.isNotEmpty
        ? _routePoints
        : _buildRoutePoints(pickup, destination);
    if (routePoints.isEmpty) return;
    final distance = const ll.Distance();
    var minMeters = double.infinity;
    for (final p in routePoints) {
      final meters = distance.as(ll.LengthUnit.Meter, driver, p);
      if (meters < minMeters) minMeters = meters;
    }
    final nextOffRoute = minMeters > 120;
    if (nextOffRoute != _driverOffRoute && mounted) {
      setState(() => _driverOffRoute = nextOffRoute);
    }
  }

  List<ll.LatLng> _buildRoutePoints(ll.LatLng from, ll.LatLng to) {
    const segments = 32;
    final points = <ll.LatLng>[];
    for (var i = 0; i <= segments; i++) {
      final t = i / segments;
      points.add(
        ll.LatLng(
          from.latitude + (to.latitude - from.latitude) * t,
          from.longitude + (to.longitude - from.longitude) * t,
        ),
      );
    }
    return points;
  }

  Future<void> _refreshRoutePolyline() async {
    final isTaxiOrder = widget.orderType.toLowerCase() == 'taxi';
    final shouldDrawTripRoute =
        widget.controller.isTripInProgress ||
        widget.controller.currentStatus.value == 'delivered';
    if (!isTaxiOrder || !shouldDrawTripRoute) {
      if (_routePoints.isNotEmpty && mounted) {
        setState(() => _routePoints = const []);
      }
      return;
    }
    final from = ll.LatLng(
      widget.controller.pickupPoint.latitude,
      widget.controller.pickupPoint.longitude,
    );
    final to = ll.LatLng(
      widget.controller.destinationPoint.latitude,
      widget.controller.destinationPoint.longitude,
    );
    final points = await _fetchRoutePointsFromGoogle(from: from, to: to);
    if (!mounted) return;
    setState(() => _routePoints = points);
    _updateOffRouteState();
  }

  Future<List<ll.LatLng>> _fetchRoutePointsFromGoogle({
    required ll.LatLng from,
    required ll.LatLng to,
  }) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${from.latitude},${from.longitude}'
        '&destination=${to.latitude},${to.longitude}'
        '&mode=driving'
        '&key=$_mapsApiKey',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _buildRoutePoints(from, to);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _buildRoutePoints(from, to);
      }
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) {
        return _buildRoutePoints(from, to);
      }
      final route = routes.first;
      if (route is! Map<String, dynamic>) {
        return _buildRoutePoints(from, to);
      }
      final polyline = route['overview_polyline'];
      if (polyline is! Map<String, dynamic>) {
        return _buildRoutePoints(from, to);
      }
      final points = polyline['points']?.toString() ?? '';
      if (points.isEmpty) return _buildRoutePoints(from, to);
      final decodedPoints = _decodePolyline(points);
      return decodedPoints.isEmpty ? _buildRoutePoints(from, to) : decodedPoints;
    } catch (_) {
      return _buildRoutePoints(from, to);
    }
  }

  List<ll.LatLng> _decodePolyline(String encoded) {
    final points = <ll.LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;
    while (index < encoded.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dLat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dLng;

      points.add(ll.LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _focusDriverIfNeeded() {
    if (!_followDriver) return;
    final ll.LatLng? driver =
        _animatedDriverPoint ?? widget.controller.driverPoint.value;
    if (driver == null || _mapController == null) return;
    final next = ll.LatLng(driver.latitude, driver.longitude);
    if (_lastFocusedPoint == next) return;
    _lastFocusedPoint = next;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(next.latitude, next.longitude), 16),
    );
  }

  Future<void> _fitVisibleRoute() async {
    final controller = widget.controller;
    final map = _mapController;
    if (map == null) return;

    final points = <ll.LatLng>[
      ll.LatLng(controller.pickupPoint.latitude, controller.pickupPoint.longitude),
      ll.LatLng(
        controller.destinationPoint.latitude,
        controller.destinationPoint.longitude,
      ),
    ];
    final ll.LatLng? driver = _animatedDriverPoint ?? controller.driverPoint.value;
    if (driver != null) {
      points.add(ll.LatLng(driver.latitude, driver.longitude));
    }

    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points.skip(1)) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await map.animateCamera(CameraUpdate.newLatLngBounds(bounds, 64));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = widget.controller;
    final isTaxiOrder = widget.orderType.toLowerCase() == 'taxi';
    final ll.LatLng? driver = _animatedDriverPoint ?? controller.driverPoint.value;
    final headingToPickup = controller.isHeadingToPickup;
    final tripInProgress = controller.isTripInProgress;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          controller.pickupPoint.latitude,
          controller.pickupPoint.longitude,
        ),
        infoWindow: const InfoWindow(title: 'A'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(
          controller.destinationPoint.latitude,
          controller.destinationPoint.longitude,
        ),
        infoWindow: const InfoWindow(title: 'B'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ),
      if (driver != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: LatLng(driver.latitude, driver.longitude),
          infoWindow: InfoWindow(title: 'tracking.driverMarker'.tr),
          flat: true,
          anchor: const Offset(0.5, 0.58),
          zIndexInt: 3,
          icon: _carMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      if (isTaxiOrder && controller.isTripInProgress && _userPoint != null)
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(_userPoint!.latitude, _userPoint!.longitude),
          infoWindow: InfoWindow(title: 'tracking.myLocationMarker'.tr),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        ),
    };
    final taxiRoute = _routePoints.isNotEmpty
        ? _routePoints
        : _buildRoutePoints(
            ll.LatLng(controller.pickupPoint.latitude, controller.pickupPoint.longitude),
            ll.LatLng(
              controller.destinationPoint.latitude,
              controller.destinationPoint.longitude,
            ),
          );
    final polylines = <Polyline>{
      if (!isTaxiOrder && headingToPickup && driver != null)
        Polyline(
          polylineId: const PolylineId('driver_to_pickup'),
          points: [
            LatLng(driver.latitude, driver.longitude),
            LatLng(controller.pickupPoint.latitude, controller.pickupPoint.longitude),
          ],
          width: 5,
          color: const Color(0xFF3B82F6),
        ),
      if (!isTaxiOrder && (tripInProgress || controller.currentStatus.value == 'delivered'))
        Polyline(
          polylineId: const PolylineId('pickup_to_destination'),
          points: [
            if (driver != null && tripInProgress)
              LatLng(driver.latitude, driver.longitude)
            else
              LatLng(controller.pickupPoint.latitude, controller.pickupPoint.longitude),
            LatLng(
              controller.destinationPoint.latitude,
              controller.destinationPoint.longitude,
            ),
          ],
          width: 5,
          color: const Color(0xFF16A34A),
        ),
      if (isTaxiOrder && (tripInProgress || controller.currentStatus.value == 'delivered'))
        Polyline(
          polylineId: const PolylineId('taxi_trip_route'),
          points: taxiRoute
              .map((p) => LatLng(p.latitude, p.longitude))
              .toList(growable: false),
          width: 6,
          color: const Color(0xFF111827),
          patterns: [PatternItem.dash(24), PatternItem.gap(14)],
        ),
    };

    final canFollowDriver =
        (headingToPickup || (isTaxiOrder && tripInProgress)) && driver != null;
    if (!canFollowDriver && _followDriver) {
      _followDriver = false;
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: driver != null
                  ? LatLng(driver.latitude, driver.longitude)
                  : LatLng(
                      controller.pickupPoint.latitude,
                      controller.pickupPoint.longitude,
                    ),
              zoom: 13.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (_followDriver) {
                _focusDriverIfNeeded();
              } else {
                _fitVisibleRoute();
              }
            },
            myLocationButtonEnabled: false,
            myLocationEnabled: isTaxiOrder,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: true,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            },
            markers: markers,
            polylines: polylines,
          ),
          if (_driverOffRoute)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    const Color(0xFFF59E0B).withValues(alpha: 0.22),
                    cs.surface,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.55)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.onSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'tracking.driverRouteWarning'.tr,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Row(
              children: [
                if (canFollowDriver)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _followDriver = !_followDriver);
                        if (_followDriver) {
                          _focusDriverIfNeeded();
                        } else {
                          _fitVisibleRoute();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _followDriver
                            ? AppColors.primary
                            : cs.surface,
                        foregroundColor: _followDriver
                            ? Colors.white
                            : cs.onSurface,
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _followDriver
                                ? AppColors.primary
                                : cs.outlineVariant,
                          ),
                        ),
                      ),
                      icon: Icon(
                        _followDriver
                            ? Icons.gps_fixed
                            : Icons.my_location_outlined,
                        size: 18,
                      ),
                      label: Text(
                        _followDriver
                            ? 'tracking.stopTracking'.tr
                            : 'tracking.trackDriver'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                if (canFollowDriver) const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'fit_route_button',
                  backgroundColor: cs.surface,
                  foregroundColor: cs.onSurface,
                  onPressed: _fitVisibleRoute,
                  child: const Icon(Icons.fit_screen_outlined, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportTimelineCard extends StatelessWidget {
  const _TransportTimelineCard({
    required this.currentIndex,
    required this.orderType,
  });

  final int currentIndex;
  final String orderType;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = orderType == 'shipping'
        ? ShippingOrderState.timelineLabelKeys.map((key) => key.tr).toList()
        : [
            'orders.stepPlaced'.tr,
            'tracking.driverAcceptedOrder'.tr,
            'tracking.driverHeadingToPickup'.tr,
            'tracking.tripStartedLabel'.tr,
            'tracking.tripFinishedLabel'.tr,
          ];
    final shippingIcons = const [
      Icons.task_alt_outlined,
      Icons.local_shipping_outlined,
      Icons.inventory_2_outlined,
      Icons.route_outlined,
      Icons.home_outlined,
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'tracking.orderStages'.tr,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final done = currentIndex >= 0 && currentIndex >= i;
            final isLast = i == steps.length - 1;
            return _TimelineRow(
              title: entry.value,
              done: done,
              isLast: isLast,
              icon: orderType == 'shipping' ? shippingIcons[i] : null,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.title,
    required this.done,
    required this.isLast,
    this.icon,
  });

  final String title;
  final bool done;
  final bool isLast;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = cs.outline;
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Icon(
                  icon ??
                      (done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked),
                  size: 18,
                  color: done ? AppColors.primary : muted,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: done ? AppColors.primary : muted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: done ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
