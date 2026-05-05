import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:najiz_go_express/core/constants/app_colors.dart';
import 'package:najiz_go_express/features/home/controllers/notifications_controller.dart';
import 'package:najiz_go_express/features/home/models/app_notification_item.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationsController(), tag: 'notifications');
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications.title'.tr),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: controller.markAllRead,
            child: Text(
              'notifications.markAllRead'.tr,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.notifications.isEmpty) {
          return Center(
            child: Text(
              'notifications.empty'.tr,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
          itemCount: controller.notifications.length,
          separatorBuilder: (_, unusedIndex) => const SizedBox(height: 10),
          itemBuilder: (_, index) {
            final item = controller.notifications[index];
            return _NotificationTile(
              item: item,
              onTap: () => controller.onNotificationTap(item),
            );
          },
        );
      }),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final unreadBg = Color.alphaBlend(
      AppColors.primary.withValues(alpha: 0.12),
      cs.surface,
    );
    final iconUnreadBg = Color.alphaBlend(
      AppColors.primary.withValues(alpha: 0.18),
      cs.surface,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: item.isRead ? cs.surface : unreadBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? cs.outlineVariant
                  : AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.isRead
                      ? cs.surfaceContainerHighest
                      : iconUnreadBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: item.isRead ? cs.onSurfaceVariant : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(item.createdAt),
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime dt) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}/${two(dt.month)}/${two(dt.day)} - ${two(dt.hour)}:${two(dt.minute)}';
}
