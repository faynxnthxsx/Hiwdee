import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../payments/domain/funding_policy.dart';
import '../../request/domain/haul_request.dart';
import '../data/bid_repository.dart';
import '../data/order_repository.dart';
import '../domain/bid.dart';

/// รายการข้อเสนอของคำขอหนึ่งใบ พร้อมปุ่มรับข้อเสนอ
///
/// ผู้ฝากกดรับ → ข้อเสนอใบอื่นตกไปทั้งหมด แล้วเกิดออเดอร์ที่รอชำระเงิน
class BidListSection extends ConsumerWidget {
  const BidListSection({super.key, required this.request});

  final HaulRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bids = ref.watch(bidsForRequestProvider(request.id));
    final accepted = bids.where((b) => b.status == BidStatus.accepted).toList();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'ข้อเสนอจากนักหิ้ว',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              Text(
                '${bids.length} ใบ',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.inkMuted,
                ),
              ),
              const Spacer(),
              if (bids.length > 1 && accepted.isEmpty)
                const Text(
                  'เรียงจากถูกสุด',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (bids.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'ยังไม่มีใครเสนอราคา — เป็นคนแรกได้เลย',
                  style: TextStyle(color: AppColors.inkMuted, fontSize: 13),
                ),
              ),
            )
          else
            for (final bid in bids)
              _BidRow(
                bid: bid,
                request: request,
                locked: accepted.isNotEmpty,
              ),
        ],
      ),
    );
  }
}

class _BidRow extends ConsumerWidget {
  const _BidRow({
    required this.bid,
    required this.request,
    required this.locked,
  });

  final Bid bid;
  final HaulRequest request;

  /// มีคนถูกเลือกไปแล้ว — ใบที่เหลือกดรับไม่ได้อีก
  final bool locked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAccepted = bid.status == BidStatus.accepted;
    final isRejected = bid.status == BidStatus.rejected;

    return Opacity(
      opacity: isRejected ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAccepted ? AppColors.brandSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAccepted ? AppColors.brand : AppColors.line,
            width: isAccepted ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.brandSoft,
                  child: Text(
                    bid.carrierName.characters.first,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              bid.carrierName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (bid.isMine) ...[
                            const SizedBox(width: 6),
                            const _Tag('ข้อเสนอของคุณ', AppColors.abroad),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 2),
                          Text(
                            bid.carrierRating > 0
                                ? bid.carrierRating.toStringAsFixed(1)
                                : 'ยังไม่มีรีวิว',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'หิ้วสำเร็จ ${bid.completedTrips} ครั้ง',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      Fmt.baht(bid.serviceFeeTHB),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brand,
                      ),
                    ),
                    Text(
                      'ถึงภายใน ${Fmt.thaiDate(bid.deliverBy)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(bid.carrierTier.text, AppColors.success),
                _Tag(_shopText(bid.merchant), AppColors.inkMuted),
              ],
            ),
            if (bid.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                bid.note,
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
            ],
            const SizedBox(height: 10),
            if (isAccepted)
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.brand),
                  SizedBox(width: 6),
                  Text(
                    'รับข้อเสนอนี้แล้ว',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              )
            else if (isRejected)
              Text(
                bid.status.text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkMuted,
                ),
              )
            else if (!locked && !bid.isMine)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _accept(context, ref),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.brand),
                  ),
                  child: const Text('รับข้อเสนอนี้'),
                ),
              )
            else
              Text(
                bid.isMine ? 'รอผู้ฝากตอบกลับ' : bid.status.text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.inkMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _shopText(MerchantProfile m) {
    final kind = m.isOnline
        ? 'ร้านออนไลน์'
        : (m.acceptsCard ? 'หน้าร้าน รับบัตร' : 'ร้านเงินสด');
    return m.name.isEmpty ? kind : '${m.name} · $kind';
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    // ของจริงต้องเช็คว่าผู้ใช้เป็นเจ้าของคำขอใบนี้จริง
    // ตอนนี้ยังไม่มีเจ้าของบนโมเดล เลยกั้นแค่ล็อกอินไปก่อน
    final ok = await ref.ensureSignedIn(
      context,
      reason: 'เข้าสู่ระบบเพื่อรับข้อเสนอ',
    );
    if (!ok || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('รับข้อเสนอนี้?'),
        content: Text(
          '${bid.carrierName} จะเป็นนักหิ้วของคำขอนี้ '
          'ค่าหิ้ว ${Fmt.baht(bid.serviceFeeTHB)}\n\n'
          'ข้อเสนอใบอื่นจะถูกปิดทั้งหมด และระบบจะสร้างออเดอร์ให้ '
          'โดยยังไม่ตัดเงินจนกว่าคุณจะกดชำระ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยังก่อน'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('รับข้อเสนอ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    ref.read(bidListProvider.notifier).accept(bid.id);
    final order = ref.read(orderListProvider.notifier).createFromBid(
          request: request,
          bid: bid,
        );

    context.push(AppRoutes.orderDetail(order.id));
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
