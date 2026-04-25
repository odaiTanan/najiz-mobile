import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/controllers/transport_order_tracking_controller.dart';
import 'package:najiz_go_express/features/support/views/support_chat_screen.dart';

class TransportOrderTrackingScreen extends StatelessWidget {
  const TransportOrderTrackingScreen({
    super.key,
    required this.token,
    required this.orderId,
    required this.orderNumber,
    required this.initialStatus,
    required this.initialDispatchStatus,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationLat,
    required this.destinationLng,
  });

  final String token;
  final int orderId;
  final String orderNumber;
  final String initialStatus;
  final String initialDispatchStatus;
  final double pickupLat;
  final double pickupLng;
  final double destinationLat;
  final double destinationLng;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      TransportOrderTrackingController(
        token: token,
        orderId: orderId,
        orderNumber: orderNumber,
        initialStatus: initialStatus,
        initialDispatchStatus: initialDispatchStatus,
        pickupPoint: LatLng(pickupLat, pickupLng),
        destinationPoint: LatLng(destinationLat, destinationLng),
      ),
      tag: 'transport-tracking-$orderId',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F8),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'تتبع الطلب',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Obx(
          () => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _TopCard(
                orderNumber: orderNumber,
                connected: controller.isLiveConnected.value,
              ),
              if (controller.errorMessage.value != null) ...[
                const SizedBox(height: 8),
                Text(
                  controller.errorMessage.value!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 12),
              _MapCard(controller: controller),
              const SizedBox(height: 12),
              _DriverInfoCard(controller: controller, token: token),
              const SizedBox(height: 12),
              _TransportTimelineCard(currentIndex: controller.stageIndex),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  const _DriverInfoCard({required this.controller, required this.token});

  final TransportOrderTrackingController controller;
  final String token;

  @override
  Widget build(BuildContext context) {
    final hasDriverData =
        (controller.driverName.value ?? '').isNotEmpty ||
        (controller.driverVehicleType.value ?? '').isNotEmpty ||
        (controller.driverPlate.value ?? '').isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'معلومات السائق',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          if (!hasDriverData)
            const Text(
              'جاري تعيين/تحديث بيانات السائق...',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            _driverRow(
              'الاسم',
              controller.driverName.value ?? 'غير متاح',
            ),
            _driverRow(
              'نوع المركبة',
              controller.driverVehicleType.value ?? 'غير متاح',
            ),
            _driverRow(
              'رقم اللوحة',
              controller.driverPlate.value ?? 'غير متاح',
            ),
            _driverRow(
              'التقييم',
              controller.driverRating.value ?? 'غير متاح',
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Get.to(() => SupportChatScreen(token: token)),
              icon: const Icon(Icons.support_agent),
              label: const Text('التواصل مع الدعم'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _driverRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCard extends StatelessWidget {
  const _TopCard({required this.orderNumber, required this.connected});

  final String orderNumber;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              orderNumber,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFFE9F9EE)
                  : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              connected ? 'متصل لحظيا' : 'غير متصل',
              style: TextStyle(
                color: connected
                    ? const Color(0xFF0F9D58)
                    : const Color(0xFFE11D48),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.controller});

  final TransportOrderTrackingController controller;

  @override
  Widget build(BuildContext context) {
    final driver = controller.driverPoint.value;
    final markers = <Marker>[
      Marker(
        point: controller.pickupPoint,
        width: 36,
        height: 36,
        child: const _DotPin(color: Color(0xFF3B82F6), label: 'A'),
      ),
      Marker(
        point: controller.destinationPoint,
        width: 36,
        height: 36,
        child: const _DotPin(color: Color(0xFFF97316), label: 'B'),
      ),
      if (driver != null)
        Marker(
          point: driver,
          width: 40,
          height: 40,
          child: const _DotPin(color: Color(0xFF16A34A), label: 'س'),
        ),
    ];

    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: driver ?? controller.pickupPoint,
          initialZoom: 13.5,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.najiz_go_express',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: [controller.pickupPoint, controller.destinationPoint],
                strokeWidth: 4,
                color: const Color(0xFF94A3B8),
              ),
            ],
          ),
          MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

class _DotPin extends StatelessWidget {
  const _DotPin({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TransportTimelineCard extends StatelessWidget {
  const _TransportTimelineCard({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    const steps = [
      'تم قبول الطلب من قبل سائق',
      'السائق متوجه للاستلام',
      'السائق في الطريق للتوصيل',
      'تم التوصيل',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مراحل الطلب',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final done = currentIndex >= i;
            final isLast = i == steps.length - 1;
            return _TimelineRow(
              title: entry.value,
              done: done,
              isLast: isLast,
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
  });

  final String title;
  final bool done;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Icon(
                  done ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 18,
                  color: done ? AppColors.primary : const Color(0xFFCBD5E1),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: done ? AppColors.primary : const Color(0xFFCBD5E1),
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
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: done ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
