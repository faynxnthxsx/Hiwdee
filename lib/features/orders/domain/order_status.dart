/// ใครเป็นคนกดในออเดอร์หนึ่ง
///
/// สำคัญกว่าที่คิด เพราะกติกาส่วนใหญ่ของ escrow คือ "ใครมีสิทธิ์ทำอะไร"
/// ไม่ใช่แค่ "สถานะไหนไปสถานะไหนได้"
enum OrderActor {
  requester('ผู้ฝาก'),
  carrier('นักหิ้ว'),
  platform('แพลตฟอร์ม');

  const OrderActor(this.text);
  final String text;
}

/// สถานะออเดอร์ เรียงตามลำดับเวลาจริง
enum OrderStatus {
  awaitingPayment(
    'รอชำระเงิน',
    'ผู้ฝากต้องโอนเข้าระบบก่อน นักหิ้วถึงจะเริ่มงานได้',
  ),
  funded(
    'เงินเข้าระบบแล้ว',
    'แพลตฟอร์มถือเงินไว้ กำลังจัดเตรียมเงินสำรองให้นักหิ้ว',
  ),
  purchasing(
    'กำลังไปซื้อ',
    'นักหิ้วได้รับเงินสำรองแล้ว ไม่ได้ควักเงินตัวเอง',
  ),
  purchased(
    'ซื้อของแล้ว',
    'อัปสลิปและรูปสินค้าเข้าระบบเรียบร้อย',
  ),
  inTransit(
    'กำลังนำส่ง',
    'ของอยู่ระหว่างเดินทางมาหาผู้ฝาก',
  ),
  delivered(
    'ส่งถึงแล้ว',
    'รอผู้ฝากกดยืนยันรับของ เงินยังไม่ถูกปล่อย',
  ),
  completed(
    'จบงาน',
    'ผู้ฝากรับของแล้ว ค่าจ้างถูกปล่อยเข้ากระเป๋านักหิ้ว',
  ),
  cancelled(
    'ยกเลิกแล้ว',
    'คืนเงินผู้ฝากเต็มจำนวน',
  ),
  disputed(
    'เปิดข้อพิพาท',
    'แพลตฟอร์มกำลังตรวจสอบ เงินถูกถือไว้จนกว่าจะได้ข้อสรุป',
  );

  const OrderStatus(this.text, this.description);
  final String text;
  final String description;

  /// จบแล้ว ไม่มีทางไปต่อ
  bool get isTerminal => this == completed || this == cancelled;

  /// เงินของผู้ฝากอยู่ในมือแพลตฟอร์มแล้ว
  bool get isEscrowFunded => this != awaitingPayment && this != cancelled;

  /// นักหิ้วถือเงินสำรองไปแล้ว — เลยจุดนี้ยกเลิกฝ่ายเดียวไม่ได้
  bool get carrierHasAdvance => switch (this) {
        purchasing || purchased || inTransit || delivered || disputed => true,
        _ => false,
      };

  /// จุดเดียวที่ค่าจ้างถูกปล่อยให้นักหิ้ว
  bool get releasesCarrierEarning => this == completed;
}

/// ทางเดินหนึ่งเส้นจากสถานะหนึ่งไปอีกสถานะ
class OrderTransition {
  const OrderTransition({
    required this.to,
    required this.by,
    required this.actionText,
    this.isDestructive = false,
  });

  final OrderStatus to;

  /// ใครกดได้บ้าง — ว่างไม่ได้
  final Set<OrderActor> by;

  /// ข้อความบนปุ่มที่ผู้ใช้เห็น
  final String actionText;

  /// ปุ่มแบบยกเลิก/เปิดเคส ให้ UI ย้อมสีเตือน
  final bool isDestructive;

  bool allows(OrderActor actor) => by.contains(actor);
}

/// กติกาการเดินสถานะของออเดอร์
///
/// เขียนเป็นตารางล้วนๆ ไม่มี if ซ้อน เพื่อให้ข้อห้ามอ่านออกจากตารางได้เลย
/// และเทสต์ยิงครอบได้ทุกช่อง
///
/// ข้อห้ามที่สำคัญที่สุด: **พอนักหิ้วรับเงินสำรองไปแล้ว (purchasing เป็นต้นไป)
/// จะไม่มีเส้นทางไป cancelled ตรงๆ อีก** ต้องผ่าน disputed ให้แพลตฟอร์มตัดสิน
/// เพราะเงินออกจากระบบไปแล้วและอาจมีของถูกซื้อจริง การให้ฝ่ายใดฝ่ายหนึ่ง
/// กดยกเลิกเองได้ตรงนั้นคือช่องโกงที่ชัดที่สุดของโมเดลนี้
abstract final class OrderFlow {
  static const _table = <OrderStatus, List<OrderTransition>>{
    OrderStatus.awaitingPayment: [
      OrderTransition(
        to: OrderStatus.funded,
        by: {OrderActor.requester},
        actionText: 'ชำระเงินเข้าระบบ',
      ),
      OrderTransition(
        to: OrderStatus.cancelled,
        by: {OrderActor.requester, OrderActor.carrier},
        actionText: 'ยกเลิกออเดอร์',
        isDestructive: true,
      ),
    ],
    OrderStatus.funded: [
      OrderTransition(
        to: OrderStatus.purchasing,
        by: {OrderActor.carrier},
        actionText: 'รับเงินสำรองแล้วเริ่มไปซื้อ',
      ),
      // ยังไม่มีใครควักเงิน ยกเลิกตรงนี้ยังคืนเงินได้เต็มจำนวน
      OrderTransition(
        to: OrderStatus.cancelled,
        by: {OrderActor.requester},
        actionText: 'ยกเลิกและขอเงินคืน',
        isDestructive: true,
      ),
    ],
    OrderStatus.purchasing: [
      OrderTransition(
        to: OrderStatus.purchased,
        by: {OrderActor.carrier},
        actionText: 'อัปสลิปและรูปสินค้า',
      ),
      OrderTransition(
        to: OrderStatus.disputed,
        by: {OrderActor.requester, OrderActor.carrier},
        actionText: 'เปิดข้อพิพาท',
        isDestructive: true,
      ),
    ],
    OrderStatus.purchased: [
      OrderTransition(
        to: OrderStatus.inTransit,
        by: {OrderActor.carrier},
        actionText: 'ส่งของเข้าระบบขนส่งแล้ว',
      ),
      OrderTransition(
        to: OrderStatus.disputed,
        by: {OrderActor.requester, OrderActor.carrier},
        actionText: 'เปิดข้อพิพาท',
        isDestructive: true,
      ),
    ],
    OrderStatus.inTransit: [
      OrderTransition(
        to: OrderStatus.delivered,
        by: {OrderActor.carrier},
        actionText: 'แจ้งว่าส่งถึงแล้ว',
      ),
      OrderTransition(
        to: OrderStatus.disputed,
        by: {OrderActor.requester, OrderActor.carrier},
        actionText: 'เปิดข้อพิพาท',
        isDestructive: true,
      ),
    ],
    OrderStatus.delivered: [
      // จุดที่เงินถูกปล่อย — ต้องเป็นผู้ฝากกดเท่านั้น
      OrderTransition(
        to: OrderStatus.completed,
        by: {OrderActor.requester},
        actionText: 'ยืนยันรับของ',
      ),
      OrderTransition(
        to: OrderStatus.disputed,
        by: {OrderActor.requester},
        actionText: 'ของไม่ตรง เปิดเคส',
        isDestructive: true,
      ),
    ],
    OrderStatus.disputed: [
      OrderTransition(
        to: OrderStatus.completed,
        by: {OrderActor.platform},
        actionText: 'ตัดสินให้นักหิ้ว จ่ายค่าจ้าง',
      ),
      OrderTransition(
        to: OrderStatus.cancelled,
        by: {OrderActor.platform},
        actionText: 'ตัดสินให้ผู้ฝาก คืนเงิน',
        isDestructive: true,
      ),
    ],
    OrderStatus.completed: [],
    OrderStatus.cancelled: [],
  };

  /// ทางออกทั้งหมดของสถานะนี้
  static List<OrderTransition> from(OrderStatus status) =>
      _table[status] ?? const [];

  /// ทางออกที่คนคนนี้กดได้
  static List<OrderTransition> forActor(OrderStatus status, OrderActor actor) =>
      from(status).where((t) => t.allows(actor)).toList(growable: false);

  /// เดินจาก [from] ไป [to] ได้ไหม — ระบุ [by] ด้วยถ้าจะเช็คสิทธิ์
  static bool canGo(OrderStatus from, OrderStatus to, {OrderActor? by}) {
    for (final t in OrderFlow.from(from)) {
      if (t.to != to) continue;
      if (by == null || t.allows(by)) return true;
    }
    return false;
  }

  /// เส้นทางปกติที่ไม่มีปัญหาอะไร — ใช้วาดไทม์ไลน์ให้ผู้ใช้เห็นว่าเหลืออีกกี่ขั้น
  static const happyPath = <OrderStatus>[
    OrderStatus.awaitingPayment,
    OrderStatus.funded,
    OrderStatus.purchasing,
    OrderStatus.purchased,
    OrderStatus.inTransit,
    OrderStatus.delivered,
    OrderStatus.completed,
  ];
}
