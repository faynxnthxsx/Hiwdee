import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/auth_required_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/notification_sheet.dart';
import '../data/request_repository.dart';
import '../domain/haul_request.dart';
import 'request_card.dart';

/// หน้าแรก — ดูได้ทันทีโดยไม่ต้องล็อกอิน
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(filteredRequestsProvider);
    final filter = ref.watch(feedFilterProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(context, ref),
            if (!isLoggedIn) const _GuestBanner(),
            _filterRow(ref, filter),
            Expanded(
              child: requests.isEmpty
                  ? const EmptyState(
                      icon: Icons.search_off,
                      message: 'ไม่พบคำขอที่ตรงกับตัวกรอง',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 90),
                      itemCount: requests.length,
                      itemBuilder: (context, i) => RequestCard(
                        request: requests[i],
                        onTap: () => context.push(
                          AppRoutes.requestDetail(requests[i].id),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // จุดที่ต้องล็อกอิน: กดฝากหิ้ว → เด้ง sheet → มีที่อยู่ → ไปต่อ
          final address = await ref.ensureAddress(
            context,
            reason: 'เข้าสู่ระบบเพื่อฝากหิ้วของ',
          );
          if (address != null && context.mounted) {
            context.push(AppRoutes.requestNew);
          }
        },
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('ฝากหิ้ว', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _searchBar(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) => ref.read(feedFilterProvider.notifier).update(
                    (f) => f.copyWith(query: v),
                  ),
              decoration: const InputDecoration(
                hintText: 'ค้นหาของที่อยากได้ หรือประเทศ',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: 'คำนวณค่าหิ้ว + ภาษีนำเข้า',
            onPressed: () => context.push(AppRoutes.calculator),
            icon: const Icon(Icons.calculate_outlined),
          ),
          const _NotificationBell(),
        ],
      ),
    );
  }

  Widget _filterRow(WidgetRef ref, FeedFilter filter) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(
            label: 'ทั้งหมด',
            selected: filter.originType == null && filter.category == null,
            onTap: () => ref
                .read(feedFilterProvider.notifier)
                .update((f) => const FeedFilter().copyWith(query: f.query)),
          ),
          for (final o in OriginType.values)
            _chip(
              label: o.text,
              selected: filter.originType == o,
              onTap: () => ref.read(feedFilterProvider.notifier).update(
                    (f) => filter.originType == o
                        ? f.copyWith(clearOrigin: true)
                        : f.copyWith(originType: o),
                  ),
            ),
          const SizedBox(width: 4),
          for (final c in HaulCategory.values)
            _chip(
              label: '${c.emoji} ${c.text}',
              selected: filter.category == c,
              onTap: () => ref.read(feedFilterProvider.notifier).update(
                    (f) => filter.category == c
                        ? f.copyWith(clearCategory: true)
                        : f.copyWith(category: c),
                  ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppColors.brand : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.brand : AppColors.line,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// กระดิ่งแจ้งเตือน พร้อมป้ายนับที่ยังไม่ได้อ่าน
///
/// แยกเป็นวิดเจ็ตของตัวเองเพื่อให้เลข unread เปลี่ยนแล้วรีบิลด์แค่ปุ่ม
/// ไม่ลากทั้งฟีดไปด้วย
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final unread = isLoggedIn ? ref.watch(unreadNotificationCountProvider) : 0;

    return IconButton(
      tooltip: 'การแจ้งเตือน',
      onPressed: () async {
        // จุดที่ต้องล็อกอิน: การแจ้งเตือนเป็นของเฉพาะบุคคล
        final ok = await ref.ensureSignedIn(
          context,
          reason: 'เข้าสู่ระบบเพื่อดูการแจ้งเตือนของคุณ',
        );
        if (ok && context.mounted) await NotificationSheet.show(context);
      },
      icon: Badge.count(
        count: unread,
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.brand,
        child: Icon(
          unread > 0 ? Icons.notifications : Icons.notifications_none,
        ),
      ),
    );
  }
}

/// แถบบอก guest ว่าดูได้เลย ไม่ต้องสมัคร — ลดแรงเสียดทานตอนเปิดแอปครั้งแรก
class _GuestBanner extends ConsumerWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined,
              size: 18, color: AppColors.brand),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'กำลังดูแบบผู้เยี่ยมชม — เข้าสู่ระบบเมื่อพร้อมสั่งหรือรับหิ้ว',
              style: TextStyle(fontSize: 12.5, color: AppColors.brandDark),
            ),
          ),
          TextButton(
            onPressed: () => ref.ensureSignedIn(context),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.brand,
            ),
            child: const Text('เข้าสู่ระบบ'),
          ),
        ],
      ),
    );
  }
}
