import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/pricing/data/origin_countries.dart';
import 'package:hiewdee/features/pricing/domain/import_route.dart';
import 'package:hiewdee/features/pricing/domain/parcel.dart';
import 'package:hiewdee/features/pricing/domain/pricing_engine.dart';
import 'package:hiewdee/features/pricing/domain/service_fee_policy.dart';
import 'package:hiewdee/features/request/domain/haul_request.dart';

void main() {
  group('Parcel — น้ำหนักที่ใช้คิดเงิน', () {
    test('ของหนักแต่กล่องเล็ก ใช้น้ำหนักจริง', () {
      const p = Parcel(weightKg: 3, lengthCm: 20, widthCm: 15, heightCm: 10);

      expect(p.volumetricKg, closeTo(0.6, 0.001));
      expect(p.chargeableKg, 3);
      expect(p.isVolumetricDriven, isFalse);
    });

    test('ของเบาแต่กล่องใหญ่ ใช้น้ำหนักปริมาตร', () {
      // กล่องฟิกเกอร์ 40×30×25 = 30,000 ÷ 5000 = 6 กก.
      const p = Parcel(weightKg: 0.8, lengthCm: 40, widthCm: 30, heightCm: 25);

      expect(p.volumetricKg, closeTo(6, 0.001));
      expect(p.chargeableKg, 6);
      expect(p.isVolumetricDriven, isTrue);
    });

    test('ปัดขึ้นเป็นช่วงครึ่งกิโล', () {
      expect(const Parcel(weightKg: 0.7).billableKg, 1.0);
      expect(const Parcel(weightKg: 1.1).billableKg, 1.5);
      expect(const Parcel(weightKg: 2.0).billableKg, 2.0);
    });
  });

  group('ค่าหิ้ว', () {
    test('ของหนักราคาถูก → ฐานน้ำหนักเป็นตัวกำหนด', () {
      final fee = ServiceFeePolicy.compute(
        parcel: const Parcel(weightKg: 8),
        ratePerKgTHB: 350,
        goodsValueTHB: 1000,
      );

      // น้ำหนัก 8 × 350 = 2800 ชนะ มูลค่า 150 + 50 = 200
      expect(fee, 2800);
    });

    test('ของเบาราคาแพง → ฐานมูลค่าเป็นตัวกำหนด', () {
      final fee = ServiceFeePolicy.compute(
        parcel: const Parcel(weightKg: 0.2),
        ratePerKgTHB: 350,
        goodsValueTHB: 40000,
      );

      // มูลค่า 150 + 2000 = 2150 ชนะ น้ำหนัก 0.5 × 350 = 175
      expect(fee, 2150);
    });

    test('ไม่บวกสองฐานเข้าด้วยกัน — ใช้ตัวที่มากกว่าเท่านั้น', () {
      final fee = ServiceFeePolicy.compute(
        parcel: const Parcel(weightKg: 8),
        ratePerKgTHB: 350,
        goodsValueTHB: 40000,
      );

      // 2800 กับ 2150 → เอา 2800 ไม่ใช่ 4950
      expect(fee, 2800);
    });

    test('เพดานส่วนที่คิดจากมูลค่า กันค่าหิ้วพุ่งเกินเหตุ', () {
      final fee = ServiceFeePolicy.compute(
        parcel: const Parcel(weightKg: 0.1),
        ratePerKgTHB: 350,
        goodsValueTHB: 500000, // 5% = 25,000 แต่ถูกจำกัดที่ 3,000
      );

      expect(fee, 3150); // 150 + 3000
    });

    test('ตัวคูณความยากคูณสะสมกัน', () {
      final plain = ServiceFeePolicy.compute(
        parcel: const Parcel(weightKg: 2),
        ratePerKgTHB: 300,
        goodsValueTHB: 1000,
      );
      final hard = ServiceFeePolicy.compute(
        parcel: const Parcel(weightKg: 2),
        ratePerKgTHB: 300,
        goodsValueTHB: 1000,
        modifiers: {FeeModifier.fragile, FeeModifier.coldChain},
      );

      expect(plain, 600);
      // 600 × 1.15 × 1.40 = 966 → ปัดขึ้นหลัก 5 = 970
      expect(hard, 970);
    });

    test('ปัดขึ้นเป็นหลัก 5 บาทเสมอ', () {
      final fee = ServiceFeePolicy.compute(
        parcel: const Parcel(weightKg: 0.1),
        ratePerKgTHB: 100,
        goodsValueTHB: 1234,
      );

      expect(fee % 5, 0);
    });
  });

  group('ค่าขนส่งในประเทศ', () {
    test('คิดตามช่วงน้ำหนัก', () {
      expect(DomesticShipping.quote(parcel: const Parcel(weightKg: 0.3)), 35);
      expect(DomesticShipping.quote(parcel: const Parcel(weightKg: 1.0)), 45);
      expect(DomesticShipping.quote(parcel: const Parcel(weightKg: 4.5)), 100);
    });

    test('พื้นที่ห่างไกลมีค่าบริการเพิ่ม', () {
      final normal =
          DomesticShipping.quote(parcel: const Parcel(weightKg: 1));
      final remote = DomesticShipping.quote(
        parcel: const Parcel(weightKg: 1),
        remoteArea: true,
      );

      expect(remote - normal, 50);
    });

    test('เกิน 20 กก. คิดเพิ่มเป็นรายกิโล', () {
      final over = DomesticShipping.quote(parcel: const Parcel(weightKg: 25));
      expect(over, 260 + 5 * 15);
    });
  });

  group('คืนภาษีต้นทาง', () {
    test('ยอดไม่ถึงขั้นต่ำ → ขอคืนไม่ได้', () {
      final q = PricingEngine.quote(
        QuoteInput(
          category: HaulCategory.beauty,
          origin: OriginCountries.japan,
          goodsForeign: 3000, // ต่ำกว่า ¥5,000
          parcel: const Parcel(weightKg: 0.5),
        ),
        ImportRoute.handCarry,
      );

      expect(q.localTaxRefundForeign, 0);
    });

    test('ถอดภาษีออกจากราคาป้าย ไม่ใช่คูณจากราคาป้ายตรงๆ', () {
      final q = PricingEngine.quote(
        QuoteInput(
          category: HaulCategory.beauty,
          origin: OriginCountries.japan,
          goodsForeign: 11000, // ราคารวมภาษี 10% อยู่แล้ว
          parcel: const Parcel(weightKg: 0.5),
        ),
        ImportRoute.handCarry,
      );

      // ภาษีที่ฝังอยู่ = 11000 × 0.1/1.1 = 1000 แล้วหักค่าดำเนินการ 15%
      expect(q.localTaxRefundForeign, closeTo(850, 0.01));
      // ถ้าคูณตรงๆ จะได้ 1100 ซึ่งมากเกินจริง
      expect(q.localTaxRefundForeign, isNot(closeTo(1100, 1)));
    });

    test('ฮ่องกงไม่มี VAT จึงไม่มีอะไรให้ขอคืน', () {
      final q = PricingEngine.quote(
        QuoteInput(
          category: HaulCategory.fashion,
          origin: OriginCountries.hongkong,
          goodsForeign: 5000,
          parcel: const Parcel(weightKg: 1),
        ),
        ImportRoute.handCarry,
      );

      expect(q.localTaxRefundForeign, 0);
    });
  });

  group('ค่าธรรมเนียม', () {
    test('ค่าธรรมเนียมแพลตฟอร์มคิดจากค่าหิ้วเท่านั้น ไม่ใช่ยอดรวม', () {
      final q = PricingEngine.quote(
        QuoteInput(
          category: HaulCategory.gadget,
          origin: OriginCountries.japan,
          goodsForeign: 200000, // ของแพงมาก
          parcel: const Parcel(weightKg: 1),
        ),
        ImportRoute.handCarry,
      );

      expect(q.platformFee, closeTo(q.serviceFee * 0.08, 0.01));
      // ถ้าคิดจากยอดรวมจะกลายเป็นหลักพัน
      expect(q.platformFee, lessThan(q.serviceFee));
    });

    test('ค่าธรรมเนียมชำระเงิน gross-up ให้แพลตฟอร์มได้เงินครบ', () {
      final q = PricingEngine.quote(
        QuoteInput(
          category: HaulCategory.beauty,
          origin: OriginCountries.japan,
          goodsForeign: 20000,
          parcel: const Parcel(weightKg: 1),
        ),
        ImportRoute.handCarry,
      );

      // หัก 3.65% จากยอดที่รูดจริง แล้วต้องเหลือเท่า subtotal พอดี
      final gatewayTakes = q.total * PricingEngine.paymentFeeRate;
      expect(gatewayTakes, closeTo(q.paymentFee, 0.01));
      expect(q.total - q.paymentFee, closeTo(q.subtotal, 0.01));
    });
  });

  group('เทียบสองช่องทาง — เคส SK-II จากโตเกียว', () {
    final input = QuoteInput(
      category: HaulCategory.beauty,
      origin: OriginCountries.japan,
      goodsForeign: 35200, // ¥17,600 × 2 ขวด
      parcel: const Parcel(weightKg: 0.7, quantity: 2),
    );

    test('หิ้วติดตัวได้รับยกเว้นภาษี เพราะไม่ถึงเพดาน 20,000', () {
      final hand = PricingEngine.quote(input, ImportRoute.handCarry);

      expect(hand.goodsTHB, closeTo(7620, 5));
      expect(hand.tax.isExempt, isTrue);
      expect(hand.tax.total, 0);
    });

    test('ส่งไปรษณีย์เสียทั้งอากรและ VAT', () {
      final post = PricingEngine.quote(input, ImportRoute.postal);

      expect(post.tax.isExempt, isFalse);
      expect(post.tax.importDuty, greaterThan(0));
      expect(post.tax.vat, greaterThan(0));
    });

    test('หิ้วติดตัวถูกกว่าอย่างมีนัยสำคัญ', () {
      final cmp = PricingEngine.compare(input);

      expect(cmp.cheaper.route, ImportRoute.handCarry);
      expect(cmp.savings, greaterThan(2000));
      expect(cmp.isSignificant, isTrue);
    });

    test('นักหิ้วไม่ต้องออกเงินเอง — เงินสำรองครอบคลุมทุกรายจ่าย', () {
      final hand = PricingEngine.quote(input, ImportRoute.handCarry);

      final carrierSpends = hand.goodsTHB +
          hand.internationalFreight +
          hand.domesticShipping +
          hand.tax.total;

      expect(hand.carrierAdvance, closeTo(carrierSpends, 0.01));
    });

    test('ค่าจ้างนักหิ้วคือค่าหิ้วหลังหักค่าธรรมเนียม', () {
      final hand = PricingEngine.quote(input, ImportRoute.handCarry);

      expect(
        hand.carrierEarning,
        closeTo(hand.serviceFee - hand.platformFee, 0.01),
      );
      expect(hand.carrierEarning, greaterThan(0));
    });

    test('ยอดรวมเท่ากับผลบวกของทุกบรรทัดที่โชว์ผู้ใช้', () {
      final hand = PricingEngine.quote(input, ImportRoute.handCarry);

      final sumOfLines =
          hand.lines.fold<double>(0, (sum, line) => sum + line.amount);

      expect(sumOfLines, closeTo(hand.total, 0.01));
    });
  });

  group('ของในประเทศ', () {
    test('ไม่มีภาษีและไม่มีค่าขนส่งระหว่างประเทศ', () {
      final q = PricingEngine.quote(
        QuoteInput(
          category: HaulCategory.local,
          origin: OriginCountries.thailand,
          goodsForeign: 900,
          parcel: const Parcel(weightKg: 2),
        ),
        ImportRoute.postal,
      );

      expect(q.route, ImportRoute.domestic);
      expect(q.tax.total, 0);
      expect(q.internationalFreight, 0);
    });
  });

  group('สิทธิยกเว้นถูกใช้ร่วมกันในทริปเดียว', () {
    test('ออเดอร์หลังๆ ในทริปเดียวกันเริ่มเสียภาษี', () {
      final base = QuoteInput(
        category: HaulCategory.beauty,
        origin: OriginCountries.japan,
        goodsForeign: 35200,
        parcel: const Parcel(weightKg: 0.7),
      );

      final first = PricingEngine.quote(base, ImportRoute.handCarry);
      final later = PricingEngine.quote(
        base.copyWith(allowanceUsedTHB: 18000),
        ImportRoute.handCarry,
      );

      expect(first.tax.total, 0);
      expect(later.tax.total, greaterThan(0));
      expect(later.total, greaterThan(first.total));
    });
  });

  group('เลือกสกุลเงินและเรทเอง', () {
    QuoteInput inputWith({String? currencyCode, double? rate}) => QuoteInput(
          category: HaulCategory.gadget,
          origin: currencyCode == null
              ? OriginCountries.japan
              : OriginCountries.japan.copyWith(currencyCode: currencyCode),
          goodsForeign: 1000,
          parcel: const Parcel(weightKg: 1),
          claimLocalTaxRefund: false,
          fxRateTHB: rate,
        );

    test('ไม่ระบุเรท → ใช้ตารางของสกุลนั้น', () {
      final q = PricingEngine.quote(inputWith(), ImportRoute.handCarry);

      // 1000 เยน × 0.23 × (1 + spread 2%)
      expect(q.goodsTHB, closeTo(1000 * 0.23 * 1.02, 0.01));
    });

    test('ระบุเรทเอง → เรทที่กรอกชนะตาราง', () {
      final q =
          PricingEngine.quote(inputWith(rate: 0.25), ImportRoute.handCarry);

      expect(q.goodsTHB, closeTo(1000 * 0.25 * 1.02, 0.01));
    });

    test('สกุลนอกตารางต้องกรอกเรทเอง ไม่งั้นตกไปที่ 1:1', () {
      expect(FxRates.knows('ZZZ'), isFalse);
      expect(FxRates.thbPer('ZZZ'), 1.0);

      final q = PricingEngine.quote(
        inputWith(currencyCode: 'ZZZ', rate: 12.5),
        ImportRoute.handCarry,
      );

      expect(q.goodsTHB, closeTo(1000 * 12.5 * 1.02, 0.01));
      expect(q.currencyCode, 'ZZZ');
    });

    test('เปลี่ยนสกุลแล้วข้อมูลกฎหมายของประเทศยังอยู่ครบ', () {
      final jpyInUsd =
          OriginCountries.japan.copyWith(currencyCode: 'USD', currencySymbol: r'$');

      expect(jpyInUsd.code, 'JP');
      expect(jpyInUsd.localTaxRate, OriginCountries.japan.localTaxRate);
      expect(jpyInUsd.taxRefundAvailable, isTrue);
      expect(jpyInUsd.ftaWithThailand, OriginCountries.japan.ftaWithThailand);
    });
  });

  group('ลิสต์ประเทศต้นทาง', () {
    test('ทุกสกุลเงินที่ประเทศในลิสต์ใช้ ต้องมีเรทในตาราง', () {
      for (final c in OriginCountries.all) {
        expect(
          FxRates.knows(c.currencyCode),
          isTrue,
          reason: '${c.nameTh} ใช้ ${c.currencyCode} แต่ไม่มีเรท',
        );
      }
    });

    test('มีแค่ "ประเทศอื่นๆ" เท่านั้นที่ติดธงว่าผู้ใช้กรอกเอง', () {
      final custom = OriginCountries.all.where((c) => c.isCustom).toList();

      expect(custom.single.code, OriginCountries.other.code);
    });

    test('ประเทศที่คืนภาษีได้ต้องบอกยอดขั้นต่ำและวิธีขอคืนไว้ด้วย', () {
      for (final c in OriginCountries.all.where((c) => c.taxRefundAvailable)) {
        expect(c.minSpendForRefund, greaterThan(0), reason: c.nameTh);
        expect(c.refundNote, isNotEmpty, reason: c.nameTh);
        expect(c.effectiveRefundRate, greaterThan(0), reason: c.nameTh);
      }
    });

    test('ประเทศอื่นๆ ยังคิดอากรได้ เพราะอากรผูกกับพิกัดสินค้าไม่ใช่ประเทศ', () {
      final q = PricingEngine.quote(
        QuoteInput(
          category: HaulCategory.fashion,
          origin: OriginCountries.other,
          goodsForeign: 2000,
          parcel: const Parcel(weightKg: 2),
          fxRateTHB: 35.5,
        ),
        ImportRoute.postal,
      );

      expect(q.tax.total, greaterThan(0));
      expect(q.tax.isExempt, isFalse);
    });
  });
}
