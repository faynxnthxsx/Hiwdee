import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../payments/domain/funding_policy.dart';
import '../../request/domain/haul_request.dart';
import '../data/bid_repository.dart';
import '../domain/bid.dart';

/// ตัวเลือกลักษณะร้านที่นักหิ้วจะไปซื้อ
///
/// ให้นักหิ้วเลือกเอง เพราะเป็นคนเดียวที่รู้ว่าจะไปซื้อที่ไหน
/// และเป็นข้อมูลชิ้นเดียวที่ [FundingPolicy] ต้องการเพื่อเลือกวิธีจ่ายเงิน
enum _ShopKind {
  online('ร้านออนไลน์', MerchantProfile.onlineStore()),
  card('ร้านมีหน้าร้าน รับบัตร', MerchantProfile.physicalWithCard()),
  cash('ร้านรับแต่เงินสด', MerchantProfile.cashOnly());

  const _ShopKind(this.text, this.profile);
  final String text;
  final MerchantProfile profile;
}

/// ฟอร์มเสนอราคารับหิ้ว
///
/// เดิมปุ่ม "เสนอราคารับหิ้ว" แค่บวกเลข `bidCount` ขึ้นหนึ่ง ผู้ฝากจึงไม่มี
/// อะไรให้เลือกเลย ตรงนี้คือฝั่งอุปทานจริงของมาร์เก็ตเพลส
class BidSheet extends ConsumerStatefulWidget {
  const BidSheet({super.key, required this.request});

  final HaulRequest request;

  static Future<bool?> show(BuildContext context, HaulRequest request) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) => BidSheet(request: request),
    );
  }

  @override
  ConsumerState<BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends ConsumerState<BidSheet> {
  late final _feeCtrl = TextEditingController(
    text: widget.request.serviceFeeOffer.round().toString(),
  );
  final _noteCtrl = TextEditingController();
  late DateTime _deliverBy = widget.request.deadline;
  _ShopKind _shop = _ShopKind.online;

  @override
  void dispose() {
    _feeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _fee => double.tryParse(_feeCtrl.text.trim()) ?? 0;
  bool get _valid => _fee > 0;

  /// นโยบายการเงินบล็อกไว้ → ส่งข้อเสนอไม่ได้ตั้งแต่แรก
  /// กันไม่ให้ผู้ฝากเลือกคนที่ทำงานให้ไม่ได้จริง
  bool get _isBlocked => FundingPolicy.decide(
        outlayTHB: widget.request.budgetMax,
        merchant: _shop.profile,
        tier: _tierOf(ref.read(currentUserProvider)),
      ).blocked;

  /// ระดับความน่าเชื่อถือมาจากสถานะยืนยันตัวตนของผู้ใช้
  /// ของจริงต้องผูกกับ KYC ครบขั้น ตอนนี้แมปจาก [AppUser.isVerified] ไปก่อน
  CarrierTier _tierOf(AppUser? user) =>
      (user?.isVerified ?? false) ? CarrierTier.banked : CarrierTier.identified;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliverBy,
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (picked != null) setState(() => _deliverBy = picked);
  }

  void _submit() {
    final user = ref.read(currentUserProvider);
    final now = DateTime.now();

    ref.read(bidListProvider.notifier).submit(
          Bid(
            id: 'b${now.microsecondsSinceEpoch}',
            requestId: widget.request.id,
            carrierName: user?.displayName ?? 'คุณ',
            carrierTier: _tierOf(user),
            merchant: _shop.profile,
            carrierRating: user?.rating ?? 0,
            completedTrips: user?.reviewCount ?? 0,
            serviceFeeTHB: _fee,
            deliverBy: _deliverBy,
            note: _noteCtrl.text.trim(),
            createdAt: now,
            isMine: true,
          ),
        );

    Navigator.of(context).pop(true);
  }

  /// โชว์ตั้งแต่ตอนเสนอราคาว่าแพลตฟอร์มจะออกเงินให้ยังไง
  ///
  /// เป็นข้อมูลที่ตัดสินใจได้จริง — ถ้าร้านรับแต่เงินสดและยอดเกินเพดาน
  /// ของระดับตัวเอง จะได้รู้ตรงนี้เลย ไม่ใช่ไปเจอตอนรับงานแล้ว
  Widget _fundingPreview() {
    final user = ref.watch(currentUserProvider);
    final tier = _tierOf(user);
    final outlay = widget.request.budgetMax;
    final plan = FundingPolicy.decide(
      outlayTHB: outlay,
      merchant: _shop.profile,
      tier: tier,
    );

    final blocked = plan.blocked;
    final tint = blocked ? AppColors.danger : AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                blocked ? Icons.block : Icons.verified_user_outlined,
                size: 17,
                color: tint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  blocked ? 'รับงานนี้ไม่ได้' : plan.method.text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            blocked ? plan.blockReason : plan.reason,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.5,
              color: AppColors.ink,
            ),
          ),
          if (!blocked) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniStat(
                    'คุณต้องควักเอง',
                    Fmt.baht(plan.carrierOutOfPocket),
                    AppColors.success,
                  ),
                ),
                if (plan.bondRequired > 0)
                  Expanded(
                    child: _miniStat(
                      'เงินค้ำ (คืนเมื่องานจบ)',
                      Fmt.baht(plan.bondRequired),
                      AppColors.warning,
                    ),
                  ),
              ],
            ),
          ],
          if (tier == CarrierTier.identified && !blocked) ...[
            const SizedBox(height: 8),
            Text(
              'ระดับปัจจุบัน: ${tier.text} '
              '· เพดานเงินสด ${Fmt.baht(tier.cashAdvanceCapTHB)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: AppColors.inkMuted),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final offered = widget.request.serviceFeeOffer;
    final diff = _fee - offered;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'เสนอราคารับหิ้ว',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.request.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.inkMuted, fontSize: 14),
            ),
            const SizedBox(height: 20),

            const Text(
              'ค่าหิ้วที่คุณขอ',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _feeCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                isDense: true,
                prefixText: '฿ ',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              switch (diff) {
                0 => 'เท่ากับที่ผู้ฝากตั้งไว้ (${Fmt.baht(offered)})',
                < 0 => 'ต่ำกว่าที่ผู้ฝากตั้งไว้ ${Fmt.baht(diff.abs())} '
                    '— โอกาสถูกเลือกสูงขึ้น',
                _ => 'สูงกว่าที่ผู้ฝากตั้งไว้ ${Fmt.baht(diff)} '
                    '— ควรอธิบายเหตุผลในหมายเหตุ',
              },
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: diff > 0 ? AppColors.warning : AppColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'ของถึงมือผู้ฝากภายใน',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            OutlinedButton(
              onPressed: _pickDate,
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 48),
              ),
              child: Row(
                children: [
                  Text(
                    Fmt.thaiDate(_deliverBy),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    Fmt.remaining(_deliverBy),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (_deliverBy.isAfter(widget.request.deadline)) ...[
              const SizedBox(height: 6),
              Text(
                'ช้ากว่ากำหนดที่ผู้ฝากต้องการ '
                '(${Fmt.thaiDate(widget.request.deadline)}) '
                'ผู้ฝากอาจไม่รับข้อเสนอนี้',
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppColors.warning,
                ),
              ),
            ],
            const SizedBox(height: 16),

            const Text(
              'จะไปซื้อจากร้านแบบไหน',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in _ShopKind.values)
                  ChoiceChip(
                    label: Text(kind.text),
                    selected: _shop == kind,
                    onSelected: (_) => setState(() => _shop = kind),
                    selectedColor: AppColors.brandSoft,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _shop == kind
                          ? AppColors.brand
                          : AppColors.inkMuted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _fundingPreview(),
            const SizedBox(height: 16),

            const Text(
              'หมายเหตุถึงผู้ฝาก (ไม่บังคับ)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'เช่น บินโตเกียวอยู่แล้ว แวะร้านให้ได้ '
                    'ซื้อที่ร้าน Tax-Free ประหยัดได้อีก 10%',
                hintStyle: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _valid && !_isBlocked ? _submit : null,
              child: Text(_isBlocked ? 'รับงานนี้ไม่ได้' : 'ส่งข้อเสนอ'),
            ),
            const SizedBox(height: 10),
            const Text(
              'ส่งแล้วรอผู้ฝากกดรับ — ถ้าถูกเลือกจะเกิดออเดอร์ '
              'และแพลตฟอร์มจะออกเงินค่าสินค้าให้ก่อน คุณไม่ต้องสำรองจ่ายเอง',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
