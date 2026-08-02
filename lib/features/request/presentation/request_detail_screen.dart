import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_badges.dart';
import '../../orders/data/bid_repository.dart';
import '../../orders/presentation/bid_list_section.dart';
import '../../orders/presentation/bid_sheet.dart';
import '../data/request_repository.dart';
import '../domain/haul_request.dart';

/// รายละเอียดคำขอ — guest เปิดดูได้ทั้งหมด
/// จะติดกำแพงล็อกอินก็ต่อเมื่อกด "เสนอราคารับหิ้ว"
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(requestByIdProvider(requestId));

    if (request == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('ไม่พบคำขอนี้')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('รายละเอียดคำขอ'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(
            onPressed: () => ref.ensureSignedIn(
              context,
              reason: 'เข้าสู่ระบบเพื่อบันทึกคำขอนี้',
            ),
            icon: const Icon(Icons.bookmark_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryThumb(category: request.category, size: 92),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OriginBadge(
                        type: request.originType,
                        place: request.originName,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        request.category.text,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section('สรุปข้อเสนอ', [
            _row('งบค่าสินค้าสูงสุด', Fmt.baht(request.budgetMax)),
            _row('ค่าจ้างหิ้วที่เสนอ', Fmt.baht(request.serviceFeeOffer),
                highlight: true),
            _row('จำนวน', '${request.quantity} ชิ้น'),
            _row('รวมสูงสุด', Fmt.baht(request.totalOffer)),
          ]),
          const SizedBox(height: 10),
          _section('กำหนดเวลา', [
            _row('ต้องได้ภายใน', Fmt.thaiDate(request.deadline)),
            _row('เหลือเวลา', Fmt.remaining(request.deadline),
                highlight: request.isUrgent),
            _row('สถานะ', request.status.text),
          ]),
          if (request.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'หมายเหตุจากผู้ฝาก',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request.note,
                    style: const TextStyle(height: 1.6, color: AppColors.ink),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.brandSoft,
                  child: Text(
                    request.requesterName.characters.first,
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requesterName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'โพสต์เมื่อ ${Fmt.thaiDate(request.createdAt)} · '
                        '${request.bidCount} ข้อเสนอ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  // แชทผูกกับออเดอร์ ไม่ใช่ผูกกับคน จึงยังเปิดห้องไม่ได้
                  // จนกว่าจะมีออเดอร์ — บอกให้ชัดดีกว่าเปิดห้องลอยๆ
                  // ที่อ้างอิงไม่ได้ตอนเกิดข้อพิพาท
                  onPressed: () async {
                    final ok = await ref.ensureSignedIn(
                      context,
                      reason: 'เข้าสู่ระบบเพื่อแชทกับผู้ฝาก',
                    );
                    if (!ok || !context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'ห้องแชทจะเปิดให้อัตโนมัติเมื่อผู้ฝากรับข้อเสนอ '
                          'เพื่อให้ทุกข้อความอ้างอิงกับออเดอร์ได้',
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('แชท'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          BidListSection(request: request),
          const SizedBox(height: 10),
          const _EscrowNotice(),
        ],
      ),
      bottomNavigationBar: _BidBar(request: request),
    );
  }

  Widget _section(String title, List<Widget> rows) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...rows,
          ],
        ),
      );

  Widget _row(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: const TextStyle(color: AppColors.inkMuted)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: highlight ? AppColors.brand : AppColors.ink,
              ),
            ),
          ],
        ),
      );
}

/// อธิบายว่าแอปถือเงินไว้ให้ — จุดขายเรื่องความน่าเชื่อถือของ "ตัวกลาง"
class _EscrowNotice extends StatelessWidget {
  const _EscrowNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppColors.success, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'คุ้มครองการชำระเงิน — ระบบถือเงินไว้จนกว่าผู้ฝากจะกดยืนยันรับของ '
              'ถ้าของไม่ตรงหรือไม่ได้รับ สามารถเปิดเคสขอคืนเงินได้',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BidBar extends ConsumerWidget {
  const _BidBar({required this.request});

  final HaulRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alreadyBid =
        ref.watch(bidsForRequestProvider(request.id)).any((b) => b.isMine);

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ค่าหิ้วที่เสนอ',
                  style: TextStyle(fontSize: 11, color: AppColors.inkMuted),
                ),
                Text(
                  Fmt.baht(request.serviceFeeOffer),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 200,
            child: FilledButton(
              onPressed: alreadyBid ? null : () => _bid(context, ref),
              child: Text(
                alreadyBid ? 'เสนอราคาไปแล้ว' : 'เสนอราคารับหิ้ว',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bid(BuildContext context, WidgetRef ref) async {
    // นักหิ้วก็เหมือนกัน: ดูฟรี แต่จะเสนอราคาต้องล็อกอิน + เปิดโหมดนักหิ้วก่อน
    final ok = await ref.ensureCarrier(
      context,
      reason: 'เข้าสู่ระบบเพื่อเสนอราคารับหิ้ว',
    );
    if (!ok || !context.mounted) return;

    final sent = await BidSheet.show(context, request);
    if (sent != true || !context.mounted) return;

    // ตัวเลขบนการ์ดฟีดยังอ่านจาก bidCount อยู่ ขยับให้ตรงกัน
    ref.read(requestListProvider.notifier).incrementBid(request.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ส่งข้อเสนอเรียบร้อย รอผู้ฝากตอบกลับ')),
    );
  }
}
