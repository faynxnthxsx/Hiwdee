import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/pricing/data/thai_customs_rules.dart';
import 'package:hiewdee/features/pricing/domain/customs_category.dart';
import 'package:hiewdee/features/pricing/domain/import_route.dart';
import 'package:hiewdee/features/request/domain/haul_request.dart';

void main() {
  final beauty = CustomsProfiles.of(HaulCategory.beauty); // อากร 20%
  final gadget = CustomsProfiles.of(HaulCategory.gadget); // อากร 0%
  final supplement = CustomsProfiles.of(HaulCategory.supplement);

  group('ของในประเทศ', () {
    test('ไม่มีภาษีนำเข้าเลย', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.domestic,
        profile: beauty,
        goodsValueTHB: 50000,
      );

      expect(tax.total, 0);
      expect(tax.isExempt, isTrue);
    });
  });

  group('หิ้วติดตัวผู้โดยสาร', () {
    test('ไม่เกินสิทธิ 20,000 บาท → ยกเว้นทั้งอากรและ VAT', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.handCarry,
        profile: beauty,
        goodsValueTHB: 7500,
      );

      expect(tax.isExempt, isTrue);
      expect(tax.importDuty, 0);
      expect(tax.vat, 0);
      expect(tax.total, 0);
    });

    test('ตรงเพดานพอดี 20,000 บาท ยังได้รับยกเว้น', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.handCarry,
        profile: beauty,
        goodsValueTHB: 20000,
      );

      expect(tax.isExempt, isTrue);
      expect(tax.total, 0);
    });

    test('ของแบ่งชิ้นได้ เกินสิทธิ → เสียภาษีเฉพาะส่วนเกิน', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.handCarry,
        profile: beauty,
        goodsValueTHB: 25000,
      );

      expect(tax.taxableBase, 5000);
      expect(tax.importDuty, closeTo(1000, 0.01)); // 5000 × 20%
      expect(tax.vatBase, closeTo(6000, 0.01)); // 5000 + 1000
      expect(tax.vat, closeTo(420, 0.01)); // 6000 × 7%
      expect(tax.total, closeTo(1420, 0.01));
    });

    test('ของชิ้นเดียวแบ่งไม่ได้ เกินสิทธิ → เสียภาษีเต็มมูลค่า', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.handCarry,
        profile: beauty,
        goodsValueTHB: 25000,
        isDivisible: false,
      );

      expect(tax.taxableBase, 25000);
      expect(tax.importDuty, closeTo(5000, 0.01));
      expect(tax.vat, closeTo(2100, 0.01)); // (25000+5000) × 7%
      expect(tax.total, closeTo(7100, 0.01));
    });

    test('สิทธิถูกใช้ไปแล้วบางส่วนในทริปเดียวกัน', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.handCarry,
        profile: beauty,
        goodsValueTHB: 8000,
        allowanceUsedTHB: 15000, // เหลือสิทธิ 5,000
      );

      expect(tax.isExempt, isFalse);
      expect(tax.taxableBase, 3000); // 8000 - 5000
    });

    test('สิทธิถูกใช้จนหมดแล้ว → เสียภาษีเต็มจำนวน', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.handCarry,
        profile: beauty,
        goodsValueTHB: 4000,
        allowanceUsedTHB: 25000,
      );

      expect(tax.taxableBase, 4000);
    });
  });

  group('ส่งทางไปรษณีย์', () {
    test('CIF ไม่เกิน 1,500 → ไม่มีอากร แต่ยังเก็บ VAT', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.postal,
        profile: beauty,
        goodsValueTHB: 1000,
      );

      expect(tax.importDuty, 0);
      expect(tax.vat, closeTo(70, 0.01)); // 1000 × 7%
    });

    test('ค่าขนส่งดันให้ CIF ทะลุเกณฑ์ยกเว้น', () {
      // ของ 1,400 อยู่ใต้เกณฑ์ แต่พอบวกค่าส่ง 300 แล้ว CIF = 1,700
      final tax = ThaiCustoms.assess(
        route: ImportRoute.postal,
        profile: beauty,
        goodsValueTHB: 1400,
        internationalFreightTHB: 300,
      );

      expect(tax.cif, 1700);
      expect(tax.isExempt, isFalse);
      expect(tax.importDuty, closeTo(340, 0.01)); // 1700 × 20%
    });

    test('เกินเกณฑ์ → VAT ต้องคิดทับอากร ไม่ใช่คิดจากราคาสินค้าเปล่า', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.postal,
        profile: beauty,
        goodsValueTHB: 10000,
        internationalFreightTHB: 1000,
      );

      expect(tax.cif, 11000);
      expect(tax.importDuty, closeTo(2200, 0.01));
      expect(tax.vatBase, closeTo(13200, 0.01)); // CIF + อากร
      expect(tax.vat, closeTo(924, 0.01));

      // ถ้าคิด VAT จากราคาสินค้าเปล่าจะได้ 700 ซึ่งผิด
      expect(tax.vat, isNot(closeTo(700, 1)));
      expect(tax.total, closeTo(3124, 0.01));
    });

    test('สินค้าอากร 0% ยังต้องเสีย VAT อยู่ดี', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.postal,
        profile: gadget,
        goodsValueTHB: 20000,
      );

      expect(tax.importDuty, 0);
      expect(tax.vat, closeTo(1400, 0.01)); // 20000 × 7%
      expect(tax.total, closeTo(1400, 0.01));
    });

    test('ค่าประกันถูกนับรวมในฐาน CIF', () {
      final withInsurance = ThaiCustoms.assess(
        route: ImportRoute.postal,
        profile: beauty,
        goodsValueTHB: 10000,
        insuranceTHB: 500,
      );

      expect(withInsurance.cif, 10500);
    });
  });

  group('คำเตือนที่ไม่เกี่ยวกับตัวเงิน', () {
    test('อาหารเสริมต้องเตือนเรื่องใบอนุญาต อย.', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.handCarry,
        profile: supplement,
        goodsValueTHB: 3000,
      );

      // ยกเว้นภาษีก็จริง แต่ยังมีความเสี่ยงโดนยึด
      expect(tax.isExempt, isTrue);
      expect(tax.warnings.any((w) => w.contains('อย.')), isTrue);
    });

    test('หมวดที่ใช้สิทธิ FTA ได้ ต้องบอกผู้ใช้', () {
      final tax = ThaiCustoms.assess(
        route: ImportRoute.postal,
        profile: beauty,
        goodsValueTHB: 10000,
      );

      expect(tax.warnings.any((w) => w.contains('FTA')), isTrue);
    });
  });

  test('effectiveRateOn บอกภาระภาษีเทียบราคาสินค้า', () {
    final tax = ThaiCustoms.assess(
      route: ImportRoute.postal,
      profile: beauty,
      goodsValueTHB: 10000,
    );

    // อากร 2000 + VAT 840 = 2840 จาก 10000
    expect(tax.effectiveRateOn(10000), closeTo(0.284, 0.001));
  });
}
