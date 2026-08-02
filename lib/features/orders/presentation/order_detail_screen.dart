import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_badges.dart';
import '../../payments/domain/funding_policy.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import '../domain/order_status.dart';

/// รายละเอียดออเดอร์ — ไทม์ไลน์ · แผนการจ่ายเงิน · ปุ่มเดินสถานะ
///
/// หน้านี้คือที่ที่ [FundingPolicy] ได้ออกมาให้ผู้ใช้เห็นจริงๆ เป็นครั้งแรก
/// ก่อนหน้านี้ลอจิกก้อนนั้นถูกเรียกจากไฟล์เทสต์ที่เดียว
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('ไม่พบออเดอร์นี้')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('รายละเอียดออเดอร์'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _RoleTag(role: order.myRole)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _header(order),
          const SizedBox(height: 10),
          _statusCard(order),
          const SizedBox(height: 10),
          _fundingCard(order),
          const SizedBox(height: 10),
          _moneyCard(order),
          const SizedBox(height: 10),
          _timelineCard(order),
        ],
      ),
      bottomNavigationBar: _ActionBar(order: order),
    );
  }

  // ── หัวออเดอร์ ────────────────────────────────────────────────

  Widget _header(Order order) {
    final other = order.myRole == OrderActor.requester
        ? 'นักหิ้ว: ${order.carrierName}'
        : 'ผู้ฝาก: ${order.requesterName}';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryThumb(category: order.category, size: 72),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  order.originName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  other,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── สถานะปัจจุบัน ─────────────────────────────────────────────

  Widget _statusCard(Order order) {
    final status = order.status;
    final step = OrderFlow.happyPath.indexOf(status);
    final onHappyPath = step >= 0;
    final tint = _tintOf(status);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
                ),
              ),
              const Spacer(),
              if (onHappyPath)
                Text(
                  'ขั้นที่ ${step + 1} จาก ${OrderFlow.happyPath.length}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.inkMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status.description,
            style: const TextStyle(fontSize: 12.5, height: 1.55),
          ),
          if (onHappyPath) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < OrderFlow.happyPath.length; i++)
                  Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(
                        right: i == OrderFlow.happyPath.length - 1 ? 0 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: i <= step ? tint : AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── แผนการจ่ายเงิน — หัวใจของโปรเจกต์ ─────────────────────────

  Widget _fundingCard(Order order) {
    final plan = order.fundingPlan;
    final payout = order.payout;
    final blocked = plan.blocked;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: AppColors.brand),
              const SizedBox(width: 8),
              const Text(
                'แพลตฟอร์มออกเงินให้ยังไง',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (blocked ? AppColors.danger : AppColors.success)
                  .withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blocked ? 'ออเดอร์นี้ถูกระงับ' : plan.method.text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: blocked ? AppColors.danger : AppColors.success,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  blocked ? plan.blockReason : plan.reason,
                  style: const TextStyle(fontSize: 12, height: 1.55),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _stat(
                  'นักหิ้วควักเอง',
                  Fmt.baht(plan.carrierOutOfPocket),
                  AppColors.success,
                  'นโยบายคือต้องเป็น ฿0 เสมอ',
                ),
              ),
              Expanded(
                child: _stat(
                  plan.bondRequired > 0 ? 'เงินค้ำ' : 'เงินที่แพลตฟอร์มเสี่ยง',
                  Fmt.baht(
                    plan.bondRequired > 0
                        ? plan.bondRequired
                        : plan.platformExposure,
                  ),
                  plan.bondRequired > 0
                      ? AppColors.warning
                      : AppColors.inkMuted,
                  plan.bondRequired > 0
                      ? 'คืนเต็มเมื่องานจบ'
                      : 'ความเสี่ยงย้ายมาที่แพลตฟอร์ม',
                ),
              ),
            ],
          ),
          if (plan.controls.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'มาตรการคุมความเสี่ยงของออเดอร์นี้',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            for (final c in plan.controls)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 8),
                      child: Icon(Icons.circle,
                          size: 5, color: AppColors.inkMuted),
                    ),
                    Expanded(
                      child: Text(
                        c,
                        style: const TextStyle(fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const Divider(height: 24),
          _row('เงินสำรองก่อนไปซื้อ', Fmt.baht(payout.advanceBeforePurchase)),
          _row(
            'ค่าจ้างหลังผู้ฝากรับของ',
            Fmt.baht(payout.earningOnCompletion),
            highlight: true,
          ),
          _row(
            'ถอนได้หลังจบงาน',
            '${payout.withdrawalHoldDays} วัน',
            hint: 'ระดับ "${order.carrierTier.text}" — '
                'ยิ่งน่าเชื่อถือยิ่งถอนไว',
          ),
        ],
      ),
    );
  }

  // ── เงิน ──────────────────────────────────────────────────────

  Widget _moneyCard(Order order) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายละเอียดเงิน',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _row('ค่าสินค้า', Fmt.baht(order.goodsCostTHB)),
          if (order.taxTHB > 0) _row('ภาษีนำเข้า', Fmt.baht(order.taxTHB)),
          _row('ค่าจัดส่ง', Fmt.baht(order.shippingTHB)),
          _row('ค่าหิ้ว', Fmt.baht(order.serviceFeeTHB)),
          const Divider(height: 22),
          _row(
            'ผู้ฝากจ่ายทั้งหมด',
            Fmt.baht(order.requesterTotalTHB),
            highlight: true,
          ),
          _row(
            'ค่าธรรมเนียมแพลตฟอร์ม',
            Fmt.baht(order.platformFeeTHB),
            hint: 'คิด 8% จากค่าหิ้วเท่านั้น ไม่ใช่ยอดรวม',
          ),
          _row('นักหิ้วได้สุทธิ', Fmt.baht(order.carrierEarningTHB)),
        ],
      ),
    );
  }

  // ── ไทม์ไลน์ ──────────────────────────────────────────────────

  Widget _timelineCard(Order order) {
    final events = order.timeline.reversed.toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ไทม์ไลน์',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const Text(
              'ยังไม่มีความเคลื่อนไหว',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
            )
          else
            for (var i = 0; i < events.length; i++)
              _TimelineRow(
                event: events[i],
                isLatest: i == 0,
                isLast: i == events.length - 1,
              ),
        ],
      ),
    );
  }

  // ── ตัวช่วยเล็กๆ ──────────────────────────────────────────────

  static Color _tintOf(OrderStatus s) => switch (s) {
        OrderStatus.completed => AppColors.success,
        OrderStatus.cancelled => AppColors.inkMuted,
        OrderStatus.disputed => AppColors.danger,
        OrderStatus.awaitingPayment => AppColors.warning,
        _ => AppColors.brand,
      };

  Widget _stat(String label, String value, Color color, String hint) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkMuted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.4,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      );

  Widget _row(
    String label,
    String value, {
    bool highlight = false,
    String? hint,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: highlight ? 16 : 14,
                    fontWeight: FontWeight.w800,
                    color: highlight ? AppColors.brand : AppColors.ink,
                  ),
                ),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 70),
                child: Text(
                  hint,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.inkMuted,
                  ),
                ),
              ),
          ],
        ),
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLatest,
    required this.isLast,
  });

  final OrderEvent event;
  final bool isLatest;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isLatest ? AppColors.brand : AppColors.line;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: isLatest ? AppColors.brand : Colors.white,
                  border: Border.all(color: color, width: 2),
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: AppColors.line),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.status.text,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                isLatest ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        Fmt.ago(event.at),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                  if (event.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        event.note,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.role});

  final OrderActor role;

  @override
  Widget build(BuildContext context) {
    final color = role == OrderActor.requester
        ? AppColors.abroad
        : AppColors.domestic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'คุณคือ${role.text}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// ปุ่มเดินสถานะ — โผล่เฉพาะที่บทบาทของผู้ใช้กดได้จริง
class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = order.availableActions;

    if (actions.isEmpty) {
      return SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          order.status.isTerminal
              ? 'ออเดอร์นี้จบแล้ว'
              : 'รออีกฝ่ายดำเนินการ — ยังไม่มีอะไรให้คุณกดตอนนี้',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
        ),
      );
    }

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: action.isDestructive
                    ? OutlinedButton(
                        onPressed: () => _run(context, ref, action),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          minimumSize: const Size(0, 46),
                        ),
                        child: Text(action.actionText),
                      )
                    : FilledButton(
                        onPressed: () => _run(context, ref, action),
                        child: Text(action.actionText),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    OrderTransition action,
  ) async {
    if (action.isDestructive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(action.actionText),
          content: Text(
            'ออเดอร์จะเปลี่ยนเป็น "${action.to.text}"\n\n'
            '${action.to.description}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }

    final moved =
        ref.read(orderListProvider.notifier).advance(order.id, action.to);

    if (!moved || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('อัปเดตเป็น "${action.to.text}" แล้ว')),
    );
  }
}
