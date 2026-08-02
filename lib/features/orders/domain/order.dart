import '../../payments/domain/funding_policy.dart';
import '../../pricing/domain/pricing_engine.dart';
import '../../request/domain/haul_request.dart';
import 'order_status.dart';

/// หนึ่งเหตุการณ์บนไทม์ไลน์ของออเดอร์
class OrderEvent {
  const OrderEvent({required this.status, required this.at, this.note = ''});

  final OrderStatus status;
  final DateTime at;
  final String note;
}

/// ออเดอร์ที่เกิดขึ้นหลังผู้ฝากรับข้อเสนอของนักหิ้ว
///
/// ตัวเชื่อมที่ทำให้ [FundingPolicy] มีที่ยืนในแอปจริง — เดิมลอจิกก้อนนั้น
/// ถูกเรียกจากไฟล์เทสต์ที่เดียว ไม่มีหน้าจอไหนแตะเลย
class Order {
  const Order({
    required this.id,
    required this.requestId,
    required this.title,
    required this.category,
    required this.originName,
    required this.requesterName,
    required this.carrierName,
    required this.carrierTier,
    required this.merchant,
    required this.goodsCostTHB,
    required this.serviceFeeTHB,
    required this.createdAt,
    required this.timeline,
    this.taxTHB = 0,
    this.shippingTHB = 0,
    this.status = OrderStatus.awaitingPayment,
    this.myRole = OrderActor.requester,
  });

  final String id;
  final String requestId;
  final String title;
  final HaulCategory category;
  final String originName;

  final String requesterName;
  final String carrierName;
  final CarrierTier carrierTier;

  /// ลักษณะร้านปลายทาง — ตัวกำหนดว่าแพลตฟอร์มจะออกเงินให้ยังไง
  final MerchantProfile merchant;

  final double goodsCostTHB;
  final double serviceFeeTHB;
  final double taxTHB;
  final double shippingTHB;

  final OrderStatus status;
  final DateTime createdAt;
  final List<OrderEvent> timeline;

  /// ผู้ใช้ปัจจุบันอยู่ฝั่งไหนของออเดอร์นี้
  final OrderActor myRole;

  /// เงินที่ต้องมีก่อนนักหิ้วออกไปซื้อ — ฐานที่ [FundingPolicy] ใช้ตัดสิน
  double get carrierOutlayTHB => goodsCostTHB + taxTHB + shippingTHB;

  double get platformFeeTHB => serviceFeeTHB * PricingEngine.platformFeeRate;

  /// ค่าจ้างสุทธิที่นักหิ้วได้หลังหักค่าธรรมเนียม
  double get carrierEarningTHB => serviceFeeTHB - platformFeeTHB;

  double get requesterTotalTHB => carrierOutlayTHB + serviceFeeTHB;

  /// แผนการจ่ายเงินของออเดอร์นี้ — คำนวณสดจากลักษณะร้านและระดับนักหิ้ว
  FundingPlan get fundingPlan => FundingPolicy.decide(
        outlayTHB: carrierOutlayTHB,
        merchant: merchant,
        tier: carrierTier,
      );

  PayoutSchedule get payout => PayoutSchedule.forOrder(
        carrierAdvance: carrierOutlayTHB,
        carrierEarning: carrierEarningTHB,
        tier: carrierTier,
      );

  /// ปุ่มที่ผู้ใช้คนนี้กดได้ตอนนี้
  List<OrderTransition> get availableActions =>
      OrderFlow.forActor(status, myRole);

  /// เดินสถานะพร้อมบันทึกไทม์ไลน์
  ///
  /// ไม่เช็คสิทธิ์ในนี้ — ให้ [OrderFlow.canGo] เป็นคนตัดสินก่อนเรียก
  /// เพื่อให้ที่ตัดสินใจมีที่เดียว
  Order advanceTo(OrderStatus next, {DateTime? at, String note = ''}) {
    return copyWith(
      status: next,
      timeline: [
        ...timeline,
        OrderEvent(status: next, at: at ?? DateTime.now(), note: note),
      ],
    );
  }

  Order copyWith({
    OrderStatus? status,
    List<OrderEvent>? timeline,
    OrderActor? myRole,
  }) {
    return Order(
      id: id,
      requestId: requestId,
      title: title,
      category: category,
      originName: originName,
      requesterName: requesterName,
      carrierName: carrierName,
      carrierTier: carrierTier,
      merchant: merchant,
      goodsCostTHB: goodsCostTHB,
      serviceFeeTHB: serviceFeeTHB,
      createdAt: createdAt,
      timeline: timeline ?? this.timeline,
      taxTHB: taxTHB,
      shippingTHB: shippingTHB,
      status: status ?? this.status,
      myRole: myRole ?? this.myRole,
    );
  }
}
