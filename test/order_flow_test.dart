import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/orders/domain/order.dart';
import 'package:hiewdee/features/orders/domain/order_status.dart';
import 'package:hiewdee/features/payments/domain/funding_policy.dart';
import 'package:hiewdee/features/request/domain/haul_request.dart';

Order makeOrder({
  OrderStatus status = OrderStatus.awaitingPayment,
  OrderActor myRole = OrderActor.requester,
  CarrierTier tier = CarrierTier.banked,
  MerchantProfile? merchant,
  double goods = 8000,
  double fee = 800,
  double tax = 0,
  double shipping = 60,
}) {
  return Order(
    id: 'o1',
    requestId: 'r1',
    title: 'SK-II Facial Treatment Essence 230ml',
    category: HaulCategory.beauty,
    originName: 'ญี่ปุ่น · โตเกียว',
    requesterName: 'มายด์',
    carrierName: 'ปาล์ม',
    carrierTier: tier,
    merchant: merchant ?? const MerchantProfile.onlineStore(name: 'Rakuten'),
    goodsCostTHB: goods,
    serviceFeeTHB: fee,
    taxTHB: tax,
    shippingTHB: shipping,
    status: status,
    myRole: myRole,
    createdAt: DateTime(2026, 8, 1),
    timeline: const [],
  );
}

void main() {
  group('โครงสร้างตารางสถานะ', () {
    test('ทุกสถานะถูกประกาศไว้ในตาราง ไม่มีตัวไหนตกหล่น', () {
      for (final s in OrderStatus.values) {
        expect(
          () => OrderFlow.from(s),
          returnsNormally,
          reason: '$s ไม่มีในตาราง',
        );
      }
    });

    test('สถานะที่ยังไม่จบต้องมีทางไปต่ออย่างน้อยหนึ่งทาง', () {
      for (final s in OrderStatus.values.where((s) => !s.isTerminal)) {
        expect(OrderFlow.from(s), isNotEmpty, reason: '${s.text} ตัน');
      }
    });

    test('สถานะปลายทางต้องไม่มีทางออก', () {
      expect(OrderFlow.from(OrderStatus.completed), isEmpty);
      expect(OrderFlow.from(OrderStatus.cancelled), isEmpty);
    });

    test('ทุกทางเดินต้องระบุว่าใครกดได้ ห้ามว่าง', () {
      for (final s in OrderStatus.values) {
        for (final t in OrderFlow.from(s)) {
          expect(t.by, isNotEmpty, reason: '${s.text} → ${t.to.text}');
          expect(t.actionText, isNotEmpty);
        }
      }
    });
  });

  group('เส้นทางปกติเดินได้ตลอดสาย', () {
    test('awaitingPayment ไล่ไปถึง completed ได้ทีละขั้น', () {
      final path = OrderFlow.happyPath;

      for (var i = 0; i < path.length - 1; i++) {
        expect(
          OrderFlow.canGo(path[i], path[i + 1]),
          isTrue,
          reason: '${path[i].text} → ${path[i + 1].text} เดินไม่ได้',
        );
      }
    });

    test('ข้ามขั้นไม่ได้ — จ่ายเงินแล้วโดดไปส่งถึงเลยไม่ได้', () {
      expect(
        OrderFlow.canGo(OrderStatus.funded, OrderStatus.delivered),
        isFalse,
      );
      expect(
        OrderFlow.canGo(OrderStatus.awaitingPayment, OrderStatus.completed),
        isFalse,
      );
    });

    test('เดินถอยหลังไม่ได้', () {
      expect(
        OrderFlow.canGo(OrderStatus.inTransit, OrderStatus.purchasing),
        isFalse,
      );
    });
  });

  group('สิทธิ์ตามบทบาท', () {
    test('เงินถูกปล่อยได้ด้วยมือผู้ฝากเท่านั้น', () {
      const from = OrderStatus.delivered;
      const to = OrderStatus.completed;

      expect(OrderFlow.canGo(from, to, by: OrderActor.requester), isTrue);
      expect(OrderFlow.canGo(from, to, by: OrderActor.carrier), isFalse);
    });

    test('นักหิ้วกดจ่ายเงินแทนผู้ฝากไม่ได้', () {
      expect(
        OrderFlow.canGo(
          OrderStatus.awaitingPayment,
          OrderStatus.funded,
          by: OrderActor.carrier,
        ),
        isFalse,
      );
    });

    test('ผู้ฝากกดแทนนักหิ้วว่าซื้อของแล้วไม่ได้', () {
      expect(
        OrderFlow.canGo(
          OrderStatus.purchasing,
          OrderStatus.purchased,
          by: OrderActor.requester,
        ),
        isFalse,
      );
    });

    test('ข้อพิพาทตัดสินได้โดยแพลตฟอร์มเท่านั้น', () {
      for (final actor in [OrderActor.requester, OrderActor.carrier]) {
        expect(
          OrderFlow.forActor(OrderStatus.disputed, actor),
          isEmpty,
          reason: '${actor.text} ไม่ควรตัดสินข้อพิพาทเอง',
        );
      }
      expect(
        OrderFlow.forActor(OrderStatus.disputed, OrderActor.platform).length,
        2,
      );
    });
  });

  group('กติกาเงิน — จุดที่พลาดแล้วเป็นช่องโกง', () {
    test('พอนักหิ้วรับเงินสำรองไปแล้ว คู่กรณีจะยกเลิกฝ่ายเดียวไม่ได้', () {
      final afterAdvance =
          OrderStatus.values.where((s) => s.carrierHasAdvance);

      for (final s in afterAdvance) {
        for (final actor in [OrderActor.requester, OrderActor.carrier]) {
          expect(
            OrderFlow.canGo(s, OrderStatus.cancelled, by: actor),
            isFalse,
            reason: '${actor.text} ไม่ควรยกเลิก "${s.text}" เองได้',
          );
        }
      }
    });

    test('ยกเลิกหลังรับเงินสำรองทำได้ทางเดียว คือแพลตฟอร์มตัดสินข้อพิพาท', () {
      final routes = OrderStatus.values
          .where((s) => s.carrierHasAdvance)
          .where((s) => OrderFlow.canGo(s, OrderStatus.cancelled));

      expect(routes, [OrderStatus.disputed]);
      expect(
        OrderFlow.canGo(
          OrderStatus.disputed,
          OrderStatus.cancelled,
          by: OrderActor.platform,
        ),
        isTrue,
      );
    });

    test('ก่อนนักหิ้วรับเงิน ยกเลิกแล้วคืนเงินได้เต็ม', () {
      expect(
        OrderFlow.canGo(OrderStatus.awaitingPayment, OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderFlow.canGo(OrderStatus.funded, OrderStatus.cancelled),
        isTrue,
      );
    });

    test('ทางเดียวที่จะถึง cancelled หลังซื้อของคือผ่านข้อพิพาท', () {
      expect(
        OrderFlow.canGo(OrderStatus.purchased, OrderStatus.disputed),
        isTrue,
      );
      expect(
        OrderFlow.canGo(
          OrderStatus.disputed,
          OrderStatus.cancelled,
          by: OrderActor.platform,
        ),
        isTrue,
      );
    });

    test('ค่าจ้างถูกปล่อยที่สถานะเดียวคือ completed', () {
      final releasing =
          OrderStatus.values.where((s) => s.releasesCarrierEarning);

      expect(releasing, [OrderStatus.completed]);
    });

    test('เงิน escrow ยังถูกถือไว้ตลอดตอนมีข้อพิพาท', () {
      expect(OrderStatus.disputed.isEscrowFunded, isTrue);
      expect(OrderStatus.disputed.isTerminal, isFalse);
    });
  });

  group('Order — เชื่อมกับนโยบายการเงิน', () {
    test('นักหิ้วไม่ควักเงินตัวเอง ไม่ว่าร้านแบบไหน', () {
      final merchants = [
        const MerchantProfile.onlineStore(),
        const MerchantProfile.physicalWithCard(),
        const MerchantProfile.cashOnly(),
      ];

      for (final m in merchants) {
        final order = makeOrder(merchant: m, goods: 4000);
        expect(order.fundingPlan.carrierOutOfPocket, 0);
        expect(order.fundingPlan.isCarrierRiskFree, isTrue);
      }
    });

    test('เงินสำรองคิดจากค่าของ + ภาษี + ค่าส่ง ไม่รวมค่าจ้าง', () {
      final order = makeOrder(goods: 8000, tax: 500, shipping: 60, fee: 800);

      expect(order.carrierOutlayTHB, 8560);
      expect(order.payout.advanceBeforePurchase, 8560);
    });

    test('ค่าจ้างที่ได้จริงคือค่าหิ้วหักค่าธรรมเนียมแพลตฟอร์ม', () {
      final order = makeOrder(fee: 1000);

      expect(order.platformFeeTHB, closeTo(80, 0.001));
      expect(order.carrierEarningTHB, closeTo(920, 0.001));
      expect(order.payout.earningOnCompletion, closeTo(920, 0.001));
    });

    test('ร้านเงินสดยอดใหญ่เกินเพดานของระดับ → ถูกบล็อกพร้อมบอกทางออก', () {
      final order = makeOrder(
        merchant: const MerchantProfile.cashOnly(name: 'ตลาดนัด'),
        tier: CarrierTier.identified,
        goods: 50000,
      );

      expect(order.fundingPlan.blocked, isTrue);
      expect(order.fundingPlan.blockReason, isNotEmpty);
      expect(order.fundingPlan.carrierOutOfPocket, 0);
    });

    test('ระดับยิ่งสูง ยิ่งถอนเงินได้เร็ว', () {
      final low = makeOrder(tier: CarrierTier.identified);
      final high = makeOrder(tier: CarrierTier.trusted);

      expect(
        high.payout.withdrawalHoldDays,
        lessThan(low.payout.withdrawalHoldDays),
      );
    });
  });

  group('Order — ปุ่มที่โผล่ตามบทบาท', () {
    test('ผู้ฝากเห็นปุ่มจ่ายเงิน นักหิ้วไม่เห็น', () {
      final asRequester = makeOrder(myRole: OrderActor.requester);
      final asCarrier = makeOrder(myRole: OrderActor.carrier);

      expect(
        asRequester.availableActions.any((t) => t.to == OrderStatus.funded),
        isTrue,
      );
      expect(
        asCarrier.availableActions.any((t) => t.to == OrderStatus.funded),
        isFalse,
      );
    });

    test('ออเดอร์ที่จบแล้วไม่มีปุ่มเหลือให้ใคร', () {
      for (final role in OrderActor.values) {
        final done = makeOrder(status: OrderStatus.completed, myRole: role);
        expect(done.availableActions, isEmpty);
      }
    });

    test('เดินสถานะแล้วไทม์ไลน์ถูกต่อท้าย ไม่ทับของเดิม', () {
      final o = makeOrder();
      final paid = o.advanceTo(
        OrderStatus.funded,
        at: DateTime(2026, 8, 2),
        note: 'โอนผ่านพร้อมเพย์',
      );
      final buying =
          paid.advanceTo(OrderStatus.purchasing, at: DateTime(2026, 8, 3));

      expect(o.timeline, isEmpty, reason: 'ของเดิมต้องไม่ถูกแก้');
      expect(buying.timeline.length, 2);
      expect(buying.timeline.first.status, OrderStatus.funded);
      expect(buying.timeline.first.note, 'โอนผ่านพร้อมเพย์');
      expect(buying.status, OrderStatus.purchasing);
    });
  });
}
