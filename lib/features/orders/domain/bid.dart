import '../../payments/domain/funding_policy.dart';

enum BidStatus {
  pending('รอผู้ฝากตอบ'),
  accepted('ผู้ฝากรับข้อเสนอแล้ว'),
  rejected('ไม่ได้ถูกเลือก'),
  withdrawn('นักหิ้วถอนข้อเสนอ');

  const BidStatus(this.text);
  final String text;
}

/// ข้อเสนอรับหิ้ว 1 ใบ
///
/// เดิมฟีเจอร์นี้เป็นแค่ตัวเลข `bidCount` ที่บวกหนึ่ง ซึ่งแปลว่า
/// ผู้ฝากไม่มีอะไรให้เลือกเลย — ครึ่งหลังของมาร์เก็ตเพลสจึงไม่มีอยู่จริง
class Bid {
  const Bid({
    required this.id,
    required this.requestId,
    required this.carrierName,
    required this.carrierTier,
    required this.merchant,
    required this.serviceFeeTHB,
    required this.deliverBy,
    required this.createdAt,
    this.carrierRating = 0,
    this.completedTrips = 0,
    this.note = '',
    this.status = BidStatus.pending,
    this.isMine = false,
  });

  final String id;
  final String requestId;

  final String carrierName;
  final CarrierTier carrierTier;

  /// นักหิ้วเป็นคนบอกเองว่าจะไปซื้อร้านแบบไหน เพราะเป็นคนเดียวที่รู้
  /// ตัวนี้กำหนดว่าแพลตฟอร์มจะออกเงินให้ด้วยวิธีไหน (ดู [FundingPolicy])
  final MerchantProfile merchant;

  /// คะแนนรีวิวเฉลี่ย 0–5
  final double carrierRating;
  final int completedTrips;

  /// ค่าหิ้วที่นักหิ้วขอ (อาจต่างจากที่ผู้ฝากตั้งไว้)
  final double serviceFeeTHB;

  /// รับปากว่าของถึงมือภายในวันนี้
  final DateTime deliverBy;

  final String note;
  final DateTime createdAt;
  final BidStatus status;

  /// ข้อเสนอของผู้ใช้ปัจจุบันเอง — UI จะได้ไม่ให้กด "รับข้อเสนอ" ตัวเอง
  final bool isMine;

  bool get isOpen => status == BidStatus.pending;

  /// นักหิ้วที่ยังไม่ยืนยันตัวตนรับงานไม่ได้ตั้งแต่แรก
  bool get carrierCanWork => carrierTier != CarrierTier.unverified;

  /// แผนการจ่ายเงินถ้าข้อเสนอนี้ถูกเลือก — คิดจากยอดที่ต้องออกไปซื้อ
  /// โชว์ให้นักหิ้วเห็นตั้งแต่ตอนเสนอราคา ว่าจะไม่ต้องควักเงินตัวเอง
  FundingPlan fundingPlanFor(double outlayTHB) => FundingPolicy.decide(
        outlayTHB: outlayTHB,
        merchant: merchant,
        tier: carrierTier,
      );

  Bid copyWith({BidStatus? status}) => Bid(
        id: id,
        requestId: requestId,
        carrierName: carrierName,
        carrierTier: carrierTier,
        merchant: merchant,
        serviceFeeTHB: serviceFeeTHB,
        deliverBy: deliverBy,
        createdAt: createdAt,
        carrierRating: carrierRating,
        completedTrips: completedTrips,
        note: note,
        status: status ?? this.status,
        isMine: isMine,
      );
}
