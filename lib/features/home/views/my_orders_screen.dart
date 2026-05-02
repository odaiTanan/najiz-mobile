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
  String _selectedType = 'all';
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
        title: Text(
          'orders.title'.tr,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
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
                ElevatedButton(
                  onPressed: controller.loadOrders,
                  child: Text('orders.retry'.tr),
                ),
              ],
            ),
          );
        }
        final typeOrders = controller.orders
            .where((o) => _matchesSelectedType(o.type, _selectedType))
            .toList(growable: false);
        final active = typeOrders
            .where((o) => o.status != 'delivered' && o.status != 'cancelled')
            .toList(growable: false);
        final completed = typeOrders
            .where((o) => o.status == 'delivered')
            .toList(growable: false);
        final cancelled = typeOrders
            .where((o) => o.status == 'cancelled')
            .toList(growable: false);
        final allOrders = [...typeOrders]..sort(_sortByNewest);
        final activeSorted = [...active]..sort(_sortByNewest);
        final completedSorted = [...completed]..sort(_sortByNewest);
        final cancelledSorted = [...cancelled]..sort(_sortByNewest);

        return RefreshIndicator(
          onRefresh: controller.loadOrders,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
            children: [
              _TypeTabs(selected: _selectedType, onChanged: (v) => setState(() => _selectedType = v)),
              const SizedBox(height: 12),
              _FilterTabs(selected: _selectedFilter, onChanged: (v) => setState(() => _selectedFilter = v)),
              const SizedBox(height: 16),
              if (_selectedFilter == 'all') ...[
                _Header('orders.allOrders'.tr),
                const SizedBox(height: 10),
                if (allOrders.isEmpty) _EmptyCard('orders.noOrders'.tr),
                ...allOrders.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: o.status == 'delivered'
                        ? _CompletedOrderCard(
                            order: o,
                            onTap: () => _showOrderDetails(o),
                          )
                        : o.status == 'cancelled'
                        ? _CancelledOrderCard(order: o)
                        : _ActiveOrderCard(
                            order: o,
                            onTrack: () => _openTracking(o),
                            onCancel: () async {
                              if (o.status != 'pending') {
                                Get.snackbar(
                                  'orders.warning'.tr,
                                  'orders.cancelOnlyPending'.tr,
                                );
                                return;
                              }
                              final reason = await _showCancelOrderSheet(
                                context,
                                orderType: o.type,
                              );
                              if (reason == null) return;
                              try {
                                await controller.cancelOrder(
                                  o.id,
                                  cancellationReason: reason,
                                );
                                if (!mounted) return;
                                Get.snackbar(
                                  'orders.success'.tr,
                                  'orders.cancelSuccess'.tr,
                                );
                              } catch (e) {
                                final msg = e.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                );
                                Get.snackbar('orders.error'.tr, msg);
                              }
                            },
                          ),
                  ),
                ),
              ] else if (_selectedFilter == 'active') ...[
                _Header('orders.activeOrders'.tr),
                const SizedBox(height: 10),
                if (activeSorted.isEmpty) _EmptyCard('orders.noActiveOrders'.tr),
                ...activeSorted.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActiveOrderCard(
                      order: o,
                      onTrack: () => _openTracking(o),
                      onCancel: () async {
                        if (o.status != 'pending') {
                          Get.snackbar(
                            'orders.warning'.tr,
                            'orders.cancelOnlyPending'.tr,
                          );
                          return;
                        }
                        final reason = await _showCancelOrderSheet(
                          context,
                          orderType: o.type,
                        );
                        if (reason == null) return;
                        try {
                          await controller.cancelOrder(
                            o.id,
                            cancellationReason: reason,
                          );
                          if (!mounted) return;
                          Get.snackbar(
                            'orders.success'.tr,
                            'orders.cancelSuccess'.tr,
                          );
                        } catch (e) {
                          final msg = e.toString().replaceFirst('Exception: ', '');
                          Get.snackbar('orders.error'.tr, msg);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _Header('orders.completedOrders'.tr),
                const SizedBox(height: 10),
                if (completedSorted.isEmpty)
                  _EmptyCard('orders.noCompletedOrders'.tr),
                ...completedSorted.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompletedOrderCard(
                      order: o,
                      onTap: () => _showOrderDetails(o),
                    ),
                  ),
                ),
              ] else if (_selectedFilter == 'completed') ...[
                _Header('orders.completedOrders'.tr),
                const SizedBox(height: 10),
                if (completedSorted.isEmpty)
                  _EmptyCard('orders.noCompletedOrders'.tr),
                ...completedSorted.map(
                  (o) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CompletedOrderCard(
                      order: o,
                      onTap: () => _showOrderDetails(o),
                    ),
                  ),
                ),
              ] else ...[
                _Header('orders.cancelledOrders'.tr),
                const SizedBox(height: 10),
                if (cancelledSorted.isEmpty)
                  _EmptyCard('orders.noCancelledOrders'.tr),
                ...cancelledSorted.map((o) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _CancelledOrderCard(order: o))),
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
            orderType: order.type,
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
            Text(
              'orders.orderDetails'.tr,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _detailRow('orders.orderNumber'.tr, order.orderNumber),
            _detailRow('orders.type'.tr, _selectedTypeLabel(order.type)),
            _detailRow('orders.status'.tr, _statusLabel(order.status)),
            _detailRow('orders.dispatchStatus'.tr, order.dispatchStatus),
            _detailRow(
              'orders.subtotal'.tr,
              '\$${order.subtotal.toStringAsFixed(2)}',
            ),
            _detailRow(
              'orders.deliveryFee'.tr,
              '\$${order.deliveryFee.toStringAsFixed(2)}',
            ),
            _detailRow('orders.total'.tr, '\$${order.total.toStringAsFixed(2)}'),
            _detailRow('orders.time'.tr, _dateHint(order.createdAt)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('orders.close'.tr),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

Future<String?> _showCancelOrderSheet(
  BuildContext context, {
  required String orderType,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _CancelOrderSheet(orderType: orderType),
  );
}

class _CancelOrderSheet extends StatefulWidget {
  const _CancelOrderSheet({required this.orderType});

  final String orderType;

  @override
  State<_CancelOrderSheet> createState() => _CancelOrderSheetState();
}

class _CancelOrderSheetState extends State<_CancelOrderSheet> {
  static const List<String> _taxiReasons = [
    'orders.cancelReasonTooExpensive',
    'orders.cancelReasonDriverFar',
    'orders.cancelReasonChangedMind',
    'orders.cancelReasonCustom',
  ];
  String? _selectedReason;
  late final TextEditingController _customReasonController;

  bool get _isTaxi => widget.orderType.toLowerCase() == 'taxi';
  bool get _isCustomReason => _selectedReason == 'orders.cancelReasonCustom';

  @override
  void initState() {
    super.initState();
    _customReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final customReason = _customReasonController.text.trim();
    String? reason;
    if (_isTaxi) {
      if (_selectedReason == null) {
        Get.snackbar(
          'orders.warning'.tr,
          'orders.selectCancelReason'.tr,
        );
        return;
      }
      reason = _isCustomReason ? customReason : _selectedReason;
      if (reason == null || reason.isEmpty) {
        Get.snackbar(
          'orders.warning'.tr,
          'orders.writeCancelReason'.tr,
        );
        return;
      }
    } else if (_selectedReason != null) {
      reason = _isCustomReason ? customReason : _selectedReason;
      if (reason != null && reason.isEmpty) {
        reason = null;
      }
    }

    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3E7EF),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'orders.cancelReasonTitle'.tr,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isTaxi
                    ? 'orders.cancelReasonRequiredTaxi'.tr
                    : 'orders.cancelReasonOptional'.tr,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ..._taxiReasons.map(
                (reason) => InkWell(
                  onTap: () => setState(() => _selectedReason = reason),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedReason == reason
                            ? AppColors.primary
                            : const Color(0xFFE2E8F0),
                      ),
                      color: _selectedReason == reason
                          ? const Color(0xFFFFF3E8)
                          : Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reason.tr,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Icon(
                          _selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 20,
                          color: _selectedReason == reason
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isCustomReason) ...[
                TextField(
                  controller: _customReasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'orders.cancelReasonPlaceholder'.tr,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: const BorderSide(color: Color(0xFFD8DFEA)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text('orders.dontCancel'.tr),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'orders.cancelOrder'.tr,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      ('all', 'orders.all'.tr),
      ('taxi', 'orders.taxi'.tr),
      ('shipping', 'orders.shipping'.tr),
      ('food', 'orders.food'.tr),
      ('stores', 'orders.store'.tr),
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
        _FilterChip(
          text: 'orders.all'.tr,
          active: selected == 'all',
          onTap: () => onChanged('all'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          text: 'orders.active'.tr,
          active: selected == 'active',
          onTap: () => onChanged('active'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          text: 'orders.completed'.tr,
          active: selected == 'completed',
          onTap: () => onChanged('completed'),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          text: 'orders.cancelled'.tr,
          active: selected == 'cancelled',
          onTap: () => onChanged('cancelled'),
        ),
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
                    Text(_orderDisplayTitle(order), style: const TextStyle(fontWeight: FontWeight.w800)),
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
                  child: Text(
                    order.type == 'taxi'
                        ? 'orders.trackTrip'.tr
                        : 'orders.trackOrder'.tr,
                  ),
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
                  child: Text('orders.cancelOrder'.tr),
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
                  Text(_orderDisplayTitle(order), style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${_dateHint(order.createdAt)} • ${'orders.delivered'.tr}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
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
          Expanded(child: Text(_orderDisplayTitle(order), style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(
            'orders.cancelled'.tr,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
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
      return 'orders.pendingApproval'.tr;
    case 'accepted':
      return 'orders.accepted'.tr;
    case 'preparing':
      return 'orders.preparing'.tr;
    case 'ready':
      return 'orders.ready'.tr;
    case 'on_the_way_to_pickup':
      return 'orders.driverToPickup'.tr;
    case 'picked_up':
      return 'orders.pickedUp'.tr;
    case 'on_way':
      return 'orders.onWay'.tr;
    case 'delivered':
      return 'orders.delivered'.tr;
    case 'cancelled':
      return 'orders.cancelled'.tr;
    default:
      return status;
  }
}

String _selectedTypeLabel(String type) {
  switch (type) {
    case 'food':
      return 'orders.typeRestaurants'.tr;
    case 'shipping':
      return 'orders.shipping'.tr;
    case 'taxi':
      return 'orders.taxi'.tr;
    case 'stores':
      return 'orders.typeStores'.tr;
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
  if (selected == 'all') return true;
  final v = value.toLowerCase();
  if (selected == 'stores') return v == 'stores' || v == 'store';
  return v == selected;
}

int _sortByNewest(UserOrder a, UserOrder b) {
  final ad = DateTime.tryParse(a.createdAt);
  final bd = DateTime.tryParse(b.createdAt);
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1;
  if (bd == null) return -1;
  return bd.compareTo(ad);
}

String _orderDisplayTitle(UserOrder order) {
  final prefix = switch (order.type.toLowerCase()) {
    'shipping' => 'home.orderShipping'.tr,
    'taxi' => 'home.orderTaxi'.tr,
    'stores' || 'store' => 'home.orderStore'.tr,
    _ => 'home.orderFood'.tr,
  };
  final compact = _compactOrderToken(order.orderNumber, order.id);
  const lrm = '\u200e';
  return '$prefix ${'home.orderNumberPrefix'.tr} $lrm$compact';
}

String _compactOrderToken(String orderNumber, int fallbackId) {
  final chunks = RegExp(r'[A-Za-z0-9]+').allMatches(orderNumber);
  if (chunks.isNotEmpty) {
    final raw = chunks.last.group(0) ?? '';
    if (raw.isNotEmpty) {
      final upper = raw.toUpperCase();
      if (upper.length > 8) {
        return upper.substring(upper.length - 8);
      }
      return upper;
    }
  }
  return fallbackId.toString();
}
