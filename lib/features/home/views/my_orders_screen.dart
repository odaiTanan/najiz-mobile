import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/controllers/my_orders_controller.dart';
import 'package:najiz_go_express/features/home/models/user_order.dart';
import 'package:najiz_go_express/features/home/views/order_tracking_screen.dart';
import 'package:najiz_go_express/features/home/views/transport_order_tracking_screen.dart';
import 'package:najiz_go_express/features/home/widgets/home_bottom_bar.dart';
import 'package:najiz_go_express/features/home/widgets/main_bottom_nav.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key, required this.token});
  final String token;

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String _selectedType = 'food';
  String _selectedFilter = 'active';

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MyOrdersController(token: widget.token), tag: 'my-orders');
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      bottomNavigationBar: HomeBottomBar(
        activeIndex: 1,
        onTap: (index) => MainBottomNav.onTap(
          index: index,
          currentIndex: 1,
          token: widget.token,
        ),
      ),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7FB),
        elevation: 0,
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: const [Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.search))],
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator());
        if (controller.errorMessage.value != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(controller.errorMessage.value!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 10),
                ElevatedButton(onPressed: controller.loadOrders, child: const Text('إعادة المحاولة')),
              ],
            ),
          );
        }
        final typeOrders = controller.orders
            .where((o) => _matchesSelectedType(o.type, _selectedType))
            .toList(growable: false);
        final active = typeOrders.where((o) => o.status != 'delivered' && o.status != 'cancelled').toList(growable: false);
        final completed = typeOrders.where((o) => o.status == 'delivered').toList(growable: false);
        final cancelled = typeOrders.where((o) => o.status == 'cancelled').toList(growable: false);

        return RefreshIndicator(
          onRefresh: controller.loadOrders,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
            children: [
              _TypeTabs(selected: _selectedType, onChanged: (v) => setState(() => _selectedType = v)),
              const SizedBox(height: 12),
              _FilterTabs(selected: _selectedFilter, onChanged: (v) => setState(() => _selectedFilter = v)),
              const SizedBox(height: 16),
              if (_selectedFilter == 'active') ...[
                const _Header('الطلبات النشطة'),
                const SizedBox(height: 10),
                if (active.isEmpty) const _EmptyCard('لا يوجد طلبات نشطة'),
                ...active.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActiveOrderCard(
                      order: o,
                      onTrack: () => _openTracking(o),
                      onCancel: () async {
                        if (o.status != 'pending') {
                          Get.snackbar('تنبيه', 'الإلغاء متاح فقط للطلبات قيد الانتظار');
                          return;
                        }
                        try {
                          await controller.cancelOrder(o.id);
                          if (!mounted) return;
                          Get.snackbar('نجاح', 'تم إلغاء الطلب');
                        } catch (e) {
                          final msg = e.toString().replaceFirst('Exception: ', '');
                          Get.snackbar('خطأ', msg);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const _Header('الطلبات المكتملة'),
                const SizedBox(height: 10),
                if (completed.isEmpty) const _EmptyCard('لا يوجد طلبات مكتملة'),
                ...completed.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompletedOrderCard(
                      order: o,
                      onTap: () => _showOrderDetails(o),
                    ),
                  ),
                ),
              ] else if (_selectedFilter == 'completed') ...[
                const _Header('الطلبات المكتملة'),
                const SizedBox(height: 10),
                if (completed.isEmpty) const _EmptyCard('لا يوجد طلبات مكتملة'),
                ...completed.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompletedOrderCard(
                      order: o,
                      onTap: () => _showOrderDetails(o),
                    ),
                  ),
                ),
              ] else ...[
                const _Header('الطلبات الملغية'),
                const SizedBox(height: 10),
                if (cancelled.isEmpty) const _EmptyCard('لا يوجد طلبات ملغية'),
                ...cancelled.map((o) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _CancelledOrderCard(order: o))),
              ],
            ],
          ),
        );
      }),
    );
  }

  void _openTracking(UserOrder order) {
    if (order.type == 'shipping' || order.type == 'taxi') {
      Get.to(() => TransportOrderTrackingScreen(
            token: widget.token,
            orderId: order.id,
            orderNumber: order.orderNumber,
            initialStatus: order.status,
            initialDispatchStatus: order.dispatchStatus,
            pickupLat: order.lat,
            pickupLng: order.lng,
            destinationLat: order.lat,
            destinationLng: order.lng,
          ));
      return;
    }
    Get.to(() => OrderTrackingScreen(
          token: widget.token,
          orderId: order.id,
          orderNumber: order.orderNumber,
          initialStatus: order.status,
          initialDispatchStatus: order.dispatchStatus,
        ));
  }

  void _showOrderDetails(UserOrder order) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6EAF1),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'تفاصيل الطلب',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _detailRow('رقم الطلب', order.orderNumber),
            _detailRow('النوع', _selectedTypeLabel(order.type)),
            _detailRow('الحالة', _statusLabel(order.status)),
            _detailRow('حالة الإرسال', order.dispatchStatus),
            _detailRow('المجموع الفرعي', '\$${order.subtotal.toStringAsFixed(2)}'),
            _detailRow('رسوم التوصيل', '\$${order.deliveryFee.toStringAsFixed(2)}'),
            _detailRow('الإجمالي', '\$${order.total.toStringAsFixed(2)}'),
            _detailRow('الوقت', _dateHint(order.createdAt)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إغلاق'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('taxi', 'Ride'),
      ('shipping', 'Courier'),
      ('food', 'Food'),
      ('stores', 'Stores'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: items
          .map((it) => InkWell(
                onTap: () => onChanged(it.$1),
                child: Container(
                  padding: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: selected == it.$1 ? AppColors.primary : Colors.transparent, width: 2)),
                  ),
                  child: Text(
                    it.$2,
                    style: TextStyle(
                      color: selected == it.$1 ? AppColors.primary : const Color(0xFF667085),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ))
          .toList(growable: false),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(text: 'نشط', active: selected == 'active', onTap: () => onChanged('active')),
        const SizedBox(width: 8),
        _FilterChip(text: 'Completed', active: selected == 'completed', onTap: () => onChanged('completed')),
        const SizedBox(width: 8),
        _FilterChip(text: 'Cancelled', active: selected == 'cancelled', onTap: () => onChanged('cancelled')),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.text, required this.active, required this.onTap});
  final String text;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFE9EEF6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(text, style: TextStyle(color: active ? Colors.white : const Color(0xFF475467), fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: .5));
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({
    required this.order,
    required this.onTrack,
    required this.onCancel,
  });
  final UserOrder order;
  final VoidCallback onTrack;
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final canCancel = order.status == 'pending';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFDCC0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: const Color(0xFFF8EEE2), borderRadius: BorderRadius.circular(14)),
                child: Icon(_iconForType(order.type), color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(_dateHint(order.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Text('\$${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('• ${_statusLabel(order.status)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onTrack,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(order.type == 'taxi' ? 'تتبع الرحلة' : 'تتبع الطلب'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: canCancel ? onCancel : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: canCancel ? Colors.red : const Color(0xFF9AA4B2),
                    side: BorderSide(
                      color: canCancel ? const Color(0xFFF0CACA) : const Color(0xFFE0E5EC),
                    ),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('إلغاء الطلب'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedOrderCard extends StatelessWidget {
  const _CompletedOrderCard({required this.order, required this.onTap});
  final UserOrder order;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE7ECF4))),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: const Color(0xFFF0F3F8), borderRadius: BorderRadius.circular(14)),
              child: Icon(_iconForType(order.type), color: const Color(0xFF77839A)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${_dateHint(order.createdAt)} • تم التوصيل', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Text('\$${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const Icon(Icons.chevron_right, color: Color(0xFFAEB8C8)),
          ],
        ),
      ),
    );
  }
}

class _CancelledOrderCard extends StatelessWidget {
  const _CancelledOrderCard({required this.order});
  final UserOrder order;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF2D4D4))),
      child: Row(
        children: [
          Expanded(child: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.w700))),
          const Text('ملغي', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text(text, style: const TextStyle(color: AppColors.textSecondary)),
    );
  }
}

String _dateHint(String value) {
  final dt = DateTime.tryParse(value);
  if (dt == null) return value;
  final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final suffix = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day}/${dt.month} • $h:$m $suffix';
}

IconData _iconForType(String type) {
  switch (type) {
    case 'taxi':
      return Icons.local_taxi_outlined;
    case 'shipping':
      return Icons.local_shipping_outlined;
    case 'stores':
      return Icons.storefront_outlined;
    default:
      return Icons.restaurant_outlined;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'بانتظار القبول';
    case 'accepted':
      return 'تم قبول الطلب';
    case 'preparing':
      return 'جاري التحضير';
    case 'ready':
      return 'جاهز للاستلام';
    case 'on_the_way_to_pickup':
      return 'السائق متجه للاستلام';
    case 'picked_up':
      return 'تم الاستلام';
    case 'on_way':
      return 'في الطريق';
    case 'delivered':
      return 'تم التوصيل';
    case 'cancelled':
      return 'ملغي';
    default:
      return status;
  }
}

String _selectedTypeLabel(String type) {
  switch (type) {
    case 'food':
      return 'مطاعم';
    case 'shipping':
      return 'شحن';
    case 'taxi':
      return 'تكسي';
    case 'stores':
      return 'متاجر';
    default:
      return type;
  }
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

bool _matchesSelectedType(String value, String selected) {
  final v = value.toLowerCase();
  if (selected == 'stores') return v == 'stores' || v == 'store';
  return v == selected;
}
