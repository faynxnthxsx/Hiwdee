import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/domain/funding_policy.dart';
import '../../request/domain/haul_request.dart';
import '../domain/bid.dart';
import '../domain/order.dart';
import '../domain/order_status.dart';

class OrderNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() => _seed();

  /// ผู้ฝากกดรับข้อเสนอ → เกิดออเดอร์ใหม่ที่รอชำระเงิน
  Order createFromBid({
    required HaulRequest request,
    required Bid bid,
    OrderActor myRole = OrderActor.requester,
  }) {
    final now = DateTime.now();
    final order = Order(
      id: 'o${now.microsecondsSinceEpoch}',
      requestId: request.id,
      title: request.title,
      category: request.category,
      originName: request.originName,
      requesterName: request.requesterName,
      carrierName: bid.carrierName,
      carrierTier: bid.carrierTier,
      // ลักษณะร้านมาจากที่นักหิ้วระบุตอนเสนอราคา ไม่ใช่ระบบเดาเอง
      merchant: bid.merchant,
      goodsCostTHB: request.budgetMax,
      serviceFeeTHB: bid.serviceFeeTHB,
      shippingTHB: 60,
      status: OrderStatus.awaitingPayment,
      myRole: myRole,
      createdAt: now,
      timeline: [
        OrderEvent(
          status: OrderStatus.awaitingPayment,
          at: now,
          note: 'รับข้อเสนอของ${bid.carrierName}',
        ),
      ],
    );

    state = [order, ...state];
    return order;
  }

  /// เดินสถานะ — ปฏิเสธเงียบๆ ถ้ากติกาไม่อนุญาต
  ///
  /// คืน true เมื่อเดินสำเร็จ เพื่อให้ UI รู้ว่าจะโชว์ SnackBar ไหม
  bool advance(String orderId, OrderStatus to, {String note = ''}) {
    final order = byId(orderId);
    if (order == null) return false;
    if (!OrderFlow.canGo(order.status, to, by: order.myRole)) return false;

    state = [
      for (final o in state)
        o.id == orderId ? o.advanceTo(to, note: note) : o,
    ];
    return true;
  }

  Order? byId(String id) {
    for (final o in state) {
      if (o.id == id) return o;
    }
    return null;
  }

  static List<Order> _seed() {
    final now = DateTime.now();
    DateTime agoDays(int d) => now.subtract(Duration(days: d));
    DateTime agoHours(int h) => now.subtract(Duration(hours: h));

    return [
      // ฝั่งผู้ฝาก · ร้านออนไลน์ → แพลตฟอร์มจ่ายร้านตรง เงินไม่ผ่านมือใคร
      Order(
        id: 'o1',
        requestId: 'r4',
        title: 'Sony WH-1000XM6 หูฟังตัดเสียง',
        category: HaulCategory.gadget,
        originName: 'ญี่ปุ่น · โอซาก้า',
        requesterName: 'ปอนด์',
        carrierName: 'ก้อง',
        carrierTier: CarrierTier.trusted,
        merchant: const MerchantProfile.onlineStore(name: 'Yodobashi.com'),
        goodsCostTHB: 14500,
        serviceFeeTHB: 1200,
        taxTHB: 0,
        shippingTHB: 60,
        status: OrderStatus.inTransit,
        myRole: OrderActor.requester,
        createdAt: agoDays(4),
        timeline: [
          OrderEvent(status: OrderStatus.awaitingPayment, at: agoDays(4)),
          OrderEvent(
            status: OrderStatus.funded,
            at: agoDays(4),
            note: 'ชำระผ่านพร้อมเพย์',
          ),
          OrderEvent(status: OrderStatus.purchasing, at: agoDays(3)),
          OrderEvent(
            status: OrderStatus.purchased,
            at: agoDays(2),
            note: 'เลขคำสั่งซื้อ YB-88421905',
          ),
          OrderEvent(
            status: OrderStatus.inTransit,
            at: agoHours(20),
            note: 'Kerry · TH8891042271',
          ),
        ],
      ),

      // ฝั่งนักหิ้ว · ร้านเงินสด → โอนล่วงหน้า + วางเงินค้ำตามระดับ
      Order(
        id: 'o2',
        requestId: 'r3',
        title: 'ไส้อั่ว + แคบหมู ร้านดำรงค์',
        category: HaulCategory.local,
        originName: 'เชียงใหม่',
        requesterName: 'ต้น',
        carrierName: 'คุณ',
        carrierTier: CarrierTier.banked,
        merchant: const MerchantProfile.cashOnly(name: 'ร้านดำรงค์ กาดหลวง'),
        goodsCostTHB: 900,
        serviceFeeTHB: 250,
        shippingTHB: 45,
        status: OrderStatus.purchasing,
        myRole: OrderActor.carrier,
        createdAt: agoDays(1),
        timeline: [
          OrderEvent(status: OrderStatus.awaitingPayment, at: agoDays(1)),
          OrderEvent(status: OrderStatus.funded, at: agoHours(20)),
          OrderEvent(
            status: OrderStatus.purchasing,
            at: agoHours(5),
            note: 'รับเงินสำรอง ฿945 เข้ากระเป๋าแล้ว',
          ),
        ],
      ),

      // ฝั่งผู้ฝาก · ร้านมีหน้าร้านรับบัตร → บัตรเสมือนวงเงินตายตัว
      Order(
        id: 'o3',
        requestId: 'r2',
        title: 'Labubu The Monsters ซีรีส์ใหม่ (สุ่มกล่อง)',
        category: HaulCategory.collectible,
        originName: 'จีน · เซี่ยงไฮ้',
        requesterName: 'คุณ',
        carrierName: 'ต่าย',
        carrierTier: CarrierTier.banked,
        merchant: const MerchantProfile.physicalWithCard(name: 'POP MART'),
        goodsCostTHB: 4200,
        serviceFeeTHB: 600,
        taxTHB: 318,
        shippingTHB: 60,
        status: OrderStatus.delivered,
        myRole: OrderActor.requester,
        createdAt: agoDays(6),
        timeline: [
          OrderEvent(status: OrderStatus.awaitingPayment, at: agoDays(6)),
          OrderEvent(status: OrderStatus.funded, at: agoDays(6)),
          OrderEvent(
            status: OrderStatus.purchasing,
            at: agoDays(5),
            note: 'ออกบัตรเสมือนวงเงิน ฿4,578',
          ),
          OrderEvent(status: OrderStatus.purchased, at: agoDays(4)),
          OrderEvent(status: OrderStatus.inTransit, at: agoDays(2)),
          OrderEvent(
            status: OrderStatus.delivered,
            at: agoHours(3),
            note: 'ส่งถึงแล้ว รอกดยืนยันรับของ',
          ),
        ],
      ),

      // จบงานแล้ว — ไว้ดูว่าหน้าตาตอนไม่มีปุ่มเหลือเป็นยังไง
      Order(
        id: 'o4',
        requestId: 'r7',
        title: 'Royce Nama Chocolate 5 กล่อง',
        category: HaulCategory.snack,
        originName: 'ญี่ปุ่น · ฮอกไกโด',
        requesterName: 'ฟิล์ม',
        carrierName: 'คุณ',
        carrierTier: CarrierTier.banked,
        merchant: const MerchantProfile.physicalWithCard(name: 'Royce Sapporo'),
        goodsCostTHB: 2600,
        serviceFeeTHB: 700,
        shippingTHB: 60,
        status: OrderStatus.completed,
        myRole: OrderActor.carrier,
        createdAt: agoDays(14),
        timeline: [
          OrderEvent(status: OrderStatus.awaitingPayment, at: agoDays(14)),
          OrderEvent(status: OrderStatus.funded, at: agoDays(14)),
          OrderEvent(status: OrderStatus.purchasing, at: agoDays(12)),
          OrderEvent(status: OrderStatus.purchased, at: agoDays(11)),
          OrderEvent(status: OrderStatus.inTransit, at: agoDays(9)),
          OrderEvent(status: OrderStatus.delivered, at: agoDays(8)),
          OrderEvent(
            status: OrderStatus.completed,
            at: agoDays(8),
            note: 'ผู้ฝากกดรับของ ค่าจ้าง ฿644 เข้ากระเป๋า',
          ),
        ],
      ),
    ];
  }
}

final orderListProvider =
    NotifierProvider<OrderNotifier, List<Order>>(OrderNotifier.new);

/// แยกตามบทบาท — แท็บ "ฉันฝาก" กับ "ฉันหิ้ว"
final ordersByRoleProvider = Provider.family<List<Order>, OrderActor>(
  (ref, role) =>
      ref.watch(orderListProvider).where((o) => o.myRole == role).toList(),
);

final orderByIdProvider = Provider.family<Order?, String>((ref, id) {
  for (final o in ref.watch(orderListProvider)) {
    if (o.id == id) return o;
  }
  return null;
});

/// ออเดอร์ที่ยังไม่จบ ใช้ขึ้นป้ายบนแท็บออเดอร์
final activeOrderCountProvider = Provider<int>(
  (ref) => ref.watch(orderListProvider).where((o) => !o.status.isTerminal).length,
);
