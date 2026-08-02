import 'dart:math' as math;

/// ระดับความน่าเชื่อถือของนักหิ้ว — ตัวคุมความเสี่ยงที่ได้ผลที่สุด
///
/// คนโกงต้องการ *ความเร็ว* กับ *ความนิรนาม* ขั้นบันไดนี้ตัดทั้งสองอย่าง
/// จะเบิกเงินสดก้อนใหญ่ได้ ต้องเอาบัตรประชาชนจริงมาผูก แล้วยังต้องทำงาน
/// สำเร็จสะสมก่อน ซึ่งไม่คุ้มกับการโกงครั้งเดียวแล้วหนี
enum CarrierTier {
  /// ยืนยันแค่เบอร์มือถือ — รับหิ้วไม่ได้
  unverified('ยังไม่ยืนยันตัวตน', 0, 0),

  /// บัตรประชาชน + selfie liveness
  identified('ยืนยันบัตรประชาชนแล้ว', 5000, 0.10),

  /// + บัญชีธนาคารที่ชื่อตรงกับบัตร
  banked('ผูกบัญชีธนาคารแล้ว', 30000, 0.05),

  /// + ทำงานสำเร็จ 10 ครั้ง คะแนน 4.5 ขึ้นไป
  trusted('นักหิ้วที่ไว้ใจได้', 100000, 0);

  const CarrierTier(this.text, this.cashAdvanceCapTHB, this.bondRate);

  final String text;

  /// เพดานเงินสดที่โอนล่วงหน้าให้ถือได้
  final double cashAdvanceCapTHB;

  /// สัดส่วนเงินค้ำที่ต้องวาง (เฉพาะกรณีเบิกเงินสดเท่านั้น)
  final double bondRate;
}

/// วิธีที่แพลตฟอร์มออกเงินค่าสินค้าให้
enum FundingMethod {
  /// แพลตฟอร์มจ่ายร้านค้าออนไลน์โดยตรง เงินไม่ผ่านมือนักหิ้วเลย
  platformDirect(
    'แพลตฟอร์มจ่ายร้านโดยตรง',
    'ปลอดภัยที่สุด เงินไม่ผ่านมือใครเลย',
  ),

  /// ออกบัตรเสมือนใช้ครั้งเดียว วงเงินเท่ายอดที่อนุมัติ
  virtualCard(
    'บัตรเสมือนใช้ครั้งเดียว',
    'รูดได้เฉพาะยอดและร้านที่กำหนด ถอนเป็นเงินสดไม่ได้',
  ),

  /// โอนเงินสดเข้ากระเป๋านักหิ้ว ใช้เมื่อร้านรับแต่เงินสด
  cashAdvance(
    'โอนเงินสดล่วงหน้า',
    'ใช้กับร้านที่รับแต่เงินสด เช่น ตลาดหรือร้านเล็ก',
  );

  const FundingMethod(this.text, this.description);
  final String text;
  final String description;
}

/// ลักษณะร้านค้าปลายทาง เป็นตัวกำหนดว่าจ่ายเงินยังไงได้บ้าง
class MerchantProfile {
  const MerchantProfile({
    required this.isOnline,
    required this.acceptsCard,
    this.name = '',
  });

  const MerchantProfile.onlineStore({String name = ''})
      : this(isOnline: true, acceptsCard: true, name: name);

  const MerchantProfile.physicalWithCard({String name = ''})
      : this(isOnline: false, acceptsCard: true, name: name);

  const MerchantProfile.cashOnly({String name = ''})
      : this(isOnline: false, acceptsCard: false, name: name);

  final bool isOnline;
  final bool acceptsCard;
  final String name;
}

/// แผนการจ่ายเงินของออเดอร์หนึ่ง
class FundingPlan {
  const FundingPlan({
    required this.method,
    required this.advanceAmount,
    required this.bondRequired,
    required this.platformExposure,
    required this.carrierOutOfPocket,
    required this.reason,
    this.blocked = false,
    this.blockReason = '',
    this.controls = const [],
  });

  final FundingMethod method;

  /// เงินที่แพลตฟอร์มออกให้ก่อนนักหิ้วไปซื้อ
  final double advanceAmount;

  /// เงินค้ำที่นักหิ้วต้องวาง (คืนเมื่องานจบ)
  final double bondRequired;

  /// เงินที่แพลตฟอร์มเสี่ยงจริงถ้านักหิ้วเชิด
  final double platformExposure;

  /// **ต้องเป็น 0 เสมอ** — นโยบายคือนักหิ้วไม่ควักเงินตัวเอง
  final double carrierOutOfPocket;

  final String reason;

  final bool blocked;
  final String blockReason;

  /// มาตรการคุมความเสี่ยงที่ต้องเปิดใช้กับออเดอร์นี้
  final List<String> controls;

  bool get isCarrierRiskFree => carrierOutOfPocket == 0;
}

/// ตัดสินใจว่าจะออกเงินให้นักหิ้วด้วยวิธีไหน
///
/// **นโยบายหลัก: นักหิ้วไม่ควักเงินตัวเองในทุกกรณี**
///
/// เหตุผลเชิงธุรกิจ ไม่ใช่แค่ความใจดี — ถ้านักหิ้วต้องสำรองจ่ายเอง
/// คนที่กล้ารับงานจะเหลือแต่คนมีเงินเย็น ซึ่งมีน้อยมาก ฝั่งอุปทานจะตัน
/// และนักหิ้วจะกดดันให้ผู้ฝากโอนตรงนอกแอป ซึ่งทำลายระบบคุ้มครองทั้งหมด
///
/// ความเสี่ยงจึงถูกย้ายมาไว้ที่แพลตฟอร์ม แล้วคุมด้วยเครื่องมือแทน:
/// เลือกวิธีจ่ายที่เงินไม่กลายเป็นเงินสด + ขั้นบันได KYC + เพดานวงเงิน
abstract final class FundingPolicy {
  /// ยอดที่ถือว่าเล็กพอจะไม่ต้องวางเงินค้ำ
  static const bondFreeThresholdTHB = 3000.0;

  static FundingPlan decide({
    required double outlayTHB,
    required MerchantProfile merchant,
    required CarrierTier tier,
  }) {
    if (tier == CarrierTier.unverified) {
      return FundingPlan(
        method: FundingMethod.platformDirect,
        advanceAmount: 0,
        bondRequired: 0,
        platformExposure: 0,
        carrierOutOfPocket: 0,
        reason: 'ยังยืนยันตัวตนไม่ครบ',
        blocked: true,
        blockReason: 'ต้องยืนยันบัตรประชาชนก่อนจึงจะรับงานหิ้วได้',
      );
    }

    // 1) ร้านออนไลน์ — แพลตฟอร์มจ่ายร้านเอง เงินไม่แตะมือนักหิ้ว
    if (merchant.isOnline) {
      return FundingPlan(
        method: FundingMethod.platformDirect,
        advanceAmount: 0,
        bondRequired: 0,
        platformExposure: outlayTHB,
        carrierOutOfPocket: 0,
        reason: 'ร้านออนไลน์ แพลตฟอร์มชำระให้ร้านโดยตรง '
            'นักหิ้วมีหน้าที่แค่รับของและนำกลับ',
        controls: const [
          'ส่งของไปที่อยู่ที่แพลตฟอร์มกำหนดเท่านั้น',
          'เลขคำสั่งซื้อของร้านถูกบันทึกไว้ตรวจสอบได้',
        ],
      );
    }

    // 2) ร้านมีหน้าร้านแต่รับบัตร — ออกบัตรเสมือนวงเงินจำกัด
    if (merchant.acceptsCard) {
      return FundingPlan(
        method: FundingMethod.virtualCard,
        advanceAmount: outlayTHB,
        bondRequired: 0,
        platformExposure: outlayTHB,
        carrierOutOfPocket: 0,
        reason: 'ออกบัตรเสมือนวงเงิน ${outlayTHB.round()} บาท '
            'ให้รูดที่ร้านโดยตรง ถอนเป็นเงินสดไม่ได้',
        controls: [
          'วงเงินตายตัว รูดเกินไม่ได้',
          'จำกัดหมวดร้านค้าและประเทศที่รูดได้',
          'บัตรหมดอายุอัตโนมัติเมื่อจบทริป',
          if (outlayTHB > tier.cashAdvanceCapTHB)
            'ยอดสูงกว่าเพดานเงินสดของระดับนี้ '
                'จึงบังคับใช้บัตรเสมือนเท่านั้น',
        ],
      );
    }

    // 3) ร้านรับแต่เงินสด — ทางเดียวที่ต้องโอนเงินสดจริง
    if (outlayTHB > tier.cashAdvanceCapTHB) {
      return FundingPlan(
        method: FundingMethod.cashAdvance,
        advanceAmount: 0,
        bondRequired: 0,
        platformExposure: 0,
        carrierOutOfPocket: 0,
        reason: 'ร้านรับแต่เงินสด และยอดเกินเพดานของระดับ '
            '"${tier.text}"',
        blocked: true,
        blockReason: 'ยอด ${outlayTHB.round()} บาท เกินเพดาน '
            '${tier.cashAdvanceCapTHB.round()} บาท — '
            'เลื่อนระดับความน่าเชื่อถือ หรือให้ผู้ฝากเลือกร้านที่รับบัตรแทน',
      );
    }

    final bond = outlayTHB <= bondFreeThresholdTHB
        ? 0.0
        : _roundTo100(outlayTHB * tier.bondRate);

    return FundingPlan(
      method: FundingMethod.cashAdvance,
      advanceAmount: outlayTHB,
      bondRequired: bond,
      platformExposure: math.max(0, outlayTHB - bond),
      carrierOutOfPocket: 0,
      reason: bond == 0
          ? 'ร้านรับแต่เงินสด โอนล่วงหน้าเต็มจำนวน ไม่ต้องวางเงินค้ำ'
          : 'ร้านรับแต่เงินสด โอนล่วงหน้าเต็มจำนวน '
              'วางเงินค้ำ ${bond.round()} บาท คืนเมื่องานจบ',
      controls: [
        'ต้องอัปสลิปและรูปสินค้าภายใน 48 ชม. หลังรับเงิน',
        'ถ่ายจากกล้องในแอปเท่านั้น เลือกจากแกลเลอรีไม่ได้',
        if (bond > 0) 'เงินค้ำคืนเต็มจำนวนเมื่อผู้ฝากกดรับของ',
      ],
    );
  }

  static double _roundTo100(double v) => (v / 100).ceilToDouble() * 100;
}

/// งวดการจ่ายเงินของออเดอร์
///
/// หลักคิด: คืน *ต้นทุน* ให้นักหิ้วเร็วที่สุดเพื่อไม่ให้ขาดสภาพคล่อง
/// แต่จับ *กำไร* ไว้จนจบงาน เพื่อให้การทำงานให้จบคุ้มกว่าการเชิด
class PayoutSchedule {
  const PayoutSchedule({
    required this.advanceBeforePurchase,
    required this.earningOnCompletion,
    required this.withdrawalHoldDays,
  });

  /// เงินค่าของ + ค่าขนส่ง + ภาษี — จ่ายก่อนออกไปซื้อ
  final double advanceBeforePurchase;

  /// ค่าจ้างหิ้วหลังหักค่าธรรมเนียม — จ่ายหลังผู้ฝากกดรับของ
  final double earningOnCompletion;

  /// เข้ากระเป๋าแล้วแต่ถอนได้หลังกี่วัน (กันเคลมย้อนหลังและ chargeback)
  final int withdrawalHoldDays;

  double get total => advanceBeforePurchase + earningOnCompletion;

  factory PayoutSchedule.forOrder({
    required double carrierAdvance,
    required double carrierEarning,
    required CarrierTier tier,
  }) {
    return PayoutSchedule(
      advanceBeforePurchase: carrierAdvance,
      earningOnCompletion: carrierEarning,
      withdrawalHoldDays: switch (tier) {
        CarrierTier.unverified => 14,
        CarrierTier.identified => 7,
        CarrierTier.banked => 5,
        CarrierTier.trusted => 2,
      },
    );
  }
}
