import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/auth_required_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../chat/data/chat_providers.dart';
import '../../orders/data/order_repository.dart';
import '../../orders/domain/order.dart';
import '../../orders/domain/order_status.dart';

/// คิวข้อพิพาทที่รอแอดมินตัดสิน
final _disputedOrdersProvider = Provider<List<Order>>((ref) {
  return ref
      .watch(orderListProvider)
      .where((o) => o.status == OrderStatus.disputed)
      .toList();
});

/// หน้าแอดมิน — ตัดสินข้อพิพาท
///
/// เป็นที่เดียวในแอปที่ทำงานในบทบาท [OrderActor.platform] ซึ่ง state machine
/// อนุญาตให้พา `disputed` ไป `completed` หรือ `cancelled` ได้
/// ผู้ฝากกับนักหิ้วทำเองไม่ได้ — กติกาข้อนี้ถูกคุมด้วยเทสต์
///
/// ตั้งใจให้เปิดบน Flutter Web
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('หน้าแอดมิน')),
        body: const AuthRequiredView(
          icon: Icons.admin_panel_settings_outlined,
          title: 'เฉพาะเจ้าหน้าที่',
          message: 'เข้าสู่ระบบด้วยบัญชีแอดมินเพื่อดูคิวข้อพิพาท',
          reason: 'เข้าสู่ระบบเพื่อเข้าหน้าแอดมิน',
        ),
      );
    }

    if (!user.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('หน้าแอดมิน')),
        body: const EmptyState(
          icon: Icons.lock_outline,
          message: 'บัญชีนี้ไม่มีสิทธิ์เข้าหน้าแอดมิน\n'
              'โหมดทดลอง: ล็อกอินด้วยเบอร์ 0899999999',
        ),
      );
    }

    final disputes = ref.watch(_disputedOrdersProvider);
    final all = ref.watch(orderListProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('คิวข้อพิพาท'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'ออเดอร์ทั้งหมด ${all.length}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ],
      ),
      body: disputes.isEmpty
          ? const EmptyState(
              icon: Icons.verified_outlined,
              message: 'ไม่มีข้อพิพาทรอตัดสิน\n'
                  'ลองเปิดเคสจากหน้าออเดอร์แล้วกลับมาดูใหม่',
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: disputes.length,
              itemBuilder: (_, i) => _DisputeCard(order: disputes[i]),
            ),
    );
  }
}

class _DisputeCard extends ConsumerWidget {
  const _DisputeCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = order.fundingPlan;
    final messages =
        ref.watch(chatStreamProvider(order.id)).value ?? const [];
    final evidence = messages.where((m) => m.hasImage).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'รอตัดสิน',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _factRow('ผู้ฝาก', order.requesterName),
          _factRow('นักหิ้ว',
              '${order.carrierName} · ${order.carrierTier.text}'),
          _factRow('วิธีจ่ายเงิน', plan.method.text),
          _factRow('เงินที่แพลตฟอร์มเสี่ยง',
              Fmt.baht(plan.platformExposure)),
          _factRow('เงินค้ำที่วางไว้', Fmt.baht(plan.bondRequired)),
          _factRow('ยอดที่ผู้ฝากจ่าย', Fmt.baht(order.requesterTotalTHB)),
          _factRow('เปิดเคสเมื่อ',
              Fmt.ago(order.timeline.last.at)),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(
                  evidence > 0
                      ? Icons.photo_library_outlined
                      : Icons.warning_amber_rounded,
                  size: 17,
                  color:
                      evidence > 0 ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    evidence > 0
                        ? 'มีหลักฐาน $evidence รูป และข้อความ '
                            '${messages.length} รายการ'
                        : 'ยังไม่มีรูปหลักฐานในเคสนี้',
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.chat(order.id)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('อ่านเคส'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _resolve(
                    context,
                    ref,
                    to: OrderStatus.cancelled,
                    label: 'คืนเงินผู้ฝาก',
                    detail: 'ผู้ฝากได้เงินคืนเต็มจำนวน '
                        '${Fmt.baht(order.requesterTotalTHB)} '
                        'และนักหิ้วไม่ได้ค่าจ้าง',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    minimumSize: const Size(0, 44),
                  ),
                  child: const Text('ตัดสินให้ผู้ฝาก'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _resolve(
                    context,
                    ref,
                    to: OrderStatus.completed,
                    label: 'จ่ายค่าจ้างนักหิ้ว',
                    detail: 'นักหิ้วได้ค่าจ้าง '
                        '${Fmt.baht(order.carrierEarningTHB)} '
                        'และเงินค้ำถูกคืน',
                  ),
                  child: const Text('ตัดสินให้นักหิ้ว'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _factRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref, {
    required OrderStatus to,
    required String label,
    required String detail,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text('$detail\n\nการตัดสินนี้ย้อนกลับไม่ได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ยืนยันคำตัดสิน'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    // เดินสถานะในบทบาทแพลตฟอร์ม — ทางเดียวที่ออกจาก disputed ได้
    final moved = ref.read(orderListProvider.notifier).advance(
          order.id,
          to,
          note: 'แอดมินตัดสิน: $label',
          by: OrderActor.platform,
        );

    if (!context.mounted) return;

    if (!moved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กติกาไม่อนุญาตให้เดินไปสถานะนี้')),
      );
      return;
    }

    await ref.read(chatRepositoryProvider).postSystemNote(
          order.id,
          'แอดมินตัดสินข้อพิพาทแล้ว: $label — $detail',
        );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ตัดสินเรียบร้อย · ${to.text}')),
    );
  }
}
