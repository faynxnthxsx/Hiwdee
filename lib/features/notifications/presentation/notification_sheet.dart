import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

/// ป๊อปอัพแจ้งเตือน — เด้งขึ้นมาทับหน้าเดิม ไม่พาผู้ใช้ออกจากฟีด
/// แนวเดียวกับ LoginSheet คือปิดแล้วอยู่ที่เดิม
class NotificationSheet extends ConsumerWidget {
  const NotificationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => const NotificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationListProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Grabber(),
          _header(context, ref, unread),
          const Divider(height: 1),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 40, color: AppColors.inkMuted),
                  SizedBox(height: 10),
                  Text(
                    'ยังไม่มีการแจ้งเตือน',
                    style: TextStyle(color: AppColors.inkMuted),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 64),
                itemBuilder: (context, i) => _NotificationTile(
                  item: items[i],
                  onTap: () => _open(context, ref, items[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, int unread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
      child: Row(
        children: [
          const Text(
            'การแจ้งเตือน',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unread ใหม่',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (unread > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationListProvider.notifier).markAllRead(),
              child: const Text('อ่านทั้งหมด'),
            ),
        ],
      ),
    );
  }

  /// กดแล้วทำเครื่องหมายว่าอ่าน แล้วพาไปหน้าที่เกี่ยวข้องถ้ามี
  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationListProvider.notifier).markRead(n.id);
    if (n.requestId == null) return;

    Navigator.of(context).pop();
    context.push(AppRoutes.requestDetail(n.requestId!));
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(item.kind);

    return ListTile(
      onTap: onTap,
      tileColor: item.isRead ? null : AppColors.brandSoft,
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: style.color.withValues(alpha: 0.12),
        child: Icon(style.icon, size: 20, color: style.color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              item.title,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Fmt.ago(item.createdAt),
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          item.body,
          style: const TextStyle(fontSize: 12.5, height: 1.45),
        ),
      ),
      trailing: item.isActionable
          ? const Icon(Icons.chevron_right, color: AppColors.inkMuted)
          : null,
    );
  }

  static ({IconData icon, Color color}) _styleOf(NotificationKind kind) =>
      switch (kind) {
        NotificationKind.bid => (
            icon: Icons.local_offer_outlined,
            color: AppColors.brand,
          ),
        NotificationKind.order => (
            icon: Icons.inventory_2_outlined,
            color: AppColors.abroad,
          ),
        NotificationKind.payout => (
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.success,
          ),
        NotificationKind.chat => (
            icon: Icons.chat_bubble_outline,
            color: AppColors.domestic,
          ),
        NotificationKind.system => (
            icon: Icons.campaign_outlined,
            color: AppColors.inkMuted,
          ),
      };
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.line,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
