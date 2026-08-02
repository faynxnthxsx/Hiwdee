import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/payments/domain/funding_policy.dart';

void main() {
  group('นโยบายหลัก: นักหิ้วไม่ควักเงินตัวเอง', () {
    test('ทุกวิธีจ่ายเงิน carrierOutOfPocket ต้องเป็นศูนย์เสมอ', () {
      final merchants = [
        const MerchantProfile.onlineStore(),
        const MerchantProfile.physicalWithCard(),
        const MerchantProfile.cashOnly(),
      ];

      for (final tier in CarrierTier.values) {
        for (final merchant in merchants) {
          for (final amount in [500.0, 5000.0, 25000.0, 90000.0]) {
            final plan = FundingPolicy.decide(
              outlayTHB: amount,
              merchant: merchant,
              tier: tier,
            );

            expect(
              plan.carrierOutOfPocket,
              0,
              reason: 'tier=${tier.name} '
                  'online=${merchant.isOnline} card=${merchant.acceptsCard} '
                  'amount=$amount',
            );
            expect(plan.isCarrierRiskFree, isTrue);
          }
        }
      }
    });
  });

  group('เลือกวิธีจ่ายตามลักษณะร้าน', () {
    test('ร้านออนไลน์ → แพลตฟอร์มจ่ายร้านเอง ไม่มีเงินผ่านมือนักหิ้ว', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 15000,
        merchant: const MerchantProfile.onlineStore(name: 'Rakuten'),
        tier: CarrierTier.identified,
      );

      expect(plan.method, FundingMethod.platformDirect);
      expect(plan.advanceAmount, 0);
      expect(plan.bondRequired, 0);
      expect(plan.blocked, isFalse);
    });

    test('ร้านรับบัตร → บัตรเสมือน ไม่ต้องวางเงินค้ำ', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 15000,
        merchant: const MerchantProfile.physicalWithCard(name: 'Don Quijote'),
        tier: CarrierTier.identified,
      );

      expect(plan.method, FundingMethod.virtualCard);
      expect(plan.advanceAmount, 15000);
      expect(plan.bondRequired, 0);
    });

    test('บัตรเสมือนใช้ได้แม้ยอดเกินเพดานเงินสด เพราะถอนเป็นเงินสดไม่ได้', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 80000, // เกินเพดานเงินสดของระดับ identified (5,000)
        merchant: const MerchantProfile.physicalWithCard(),
        tier: CarrierTier.identified,
      );

      expect(plan.blocked, isFalse);
      expect(plan.method, FundingMethod.virtualCard);
      expect(plan.controls.any((c) => c.contains('เพดานเงินสด')), isTrue);
    });

    test('ร้านรับแต่เงินสด และอยู่ในเพดาน → โอนล่วงหน้าเต็มจำนวน', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 20000,
        merchant: const MerchantProfile.cashOnly(name: 'ตลาดนัด'),
        tier: CarrierTier.banked, // เพดาน 30,000
      );

      expect(plan.method, FundingMethod.cashAdvance);
      expect(plan.advanceAmount, 20000);
      expect(plan.blocked, isFalse);
    });
  });

  group('เพดานและเงินค้ำ', () {
    test('ยังไม่ยืนยันตัวตน รับงานไม่ได้เลย', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 1000,
        merchant: const MerchantProfile.onlineStore(),
        tier: CarrierTier.unverified,
      );

      expect(plan.blocked, isTrue);
      expect(plan.blockReason, contains('ยืนยันบัตรประชาชน'));
    });

    test('เงินสดเกินเพดานของระดับ → บล็อกพร้อมบอกทางออก', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 50000,
        merchant: const MerchantProfile.cashOnly(),
        tier: CarrierTier.banked, // เพดาน 30,000
      );

      expect(plan.blocked, isTrue);
      expect(plan.advanceAmount, 0);
      expect(plan.blockReason, contains('รับบัตร'));
    });

    test('ยอดเล็กไม่ต้องวางเงินค้ำ', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 2500,
        merchant: const MerchantProfile.cashOnly(),
        tier: CarrierTier.identified,
      );

      expect(plan.bondRequired, 0);
    });

    test('ยอดใหญ่ขึ้นต้องวางเงินค้ำตามระดับ', () {
      final identified = FundingPolicy.decide(
        outlayTHB: 5000,
        merchant: const MerchantProfile.cashOnly(),
        tier: CarrierTier.identified, // bondRate 10%
      );

      expect(identified.bondRequired, 500);
    });

    test('ระดับยิ่งสูง เงินค้ำยิ่งน้อย', () {
      final identified = FundingPolicy.decide(
        outlayTHB: 20000,
        merchant: const MerchantProfile.cashOnly(),
        tier: CarrierTier.banked, // 5%
      );
      final trusted = FundingPolicy.decide(
        outlayTHB: 20000,
        merchant: const MerchantProfile.cashOnly(),
        tier: CarrierTier.trusted, // 0%
      );

      expect(identified.bondRequired, 1000);
      expect(trusted.bondRequired, 0);
    });

    test('เงินค้ำลดความเสี่ยงที่แพลตฟอร์มแบก', () {
      final plan = FundingPolicy.decide(
        outlayTHB: 20000,
        merchant: const MerchantProfile.cashOnly(),
        tier: CarrierTier.banked,
      );

      expect(plan.platformExposure, 20000 - plan.bondRequired);
    });
  });

  group('งวดการจ่ายเงิน', () {
    test('ต้นทุนจ่ายก่อนซื้อ กำไรจ่ายหลังผู้ฝากรับของ', () {
      final schedule = PayoutSchedule.forOrder(
        carrierAdvance: 8000,
        carrierEarning: 500,
        tier: CarrierTier.banked,
      );

      expect(schedule.advanceBeforePurchase, 8000);
      expect(schedule.earningOnCompletion, 500);
      expect(schedule.total, 8500);
    });

    test('ระดับยิ่งสูง ยิ่งถอนเงินได้เร็ว', () {
      int holdFor(CarrierTier tier) => PayoutSchedule.forOrder(
            carrierAdvance: 1000,
            carrierEarning: 100,
            tier: tier,
          ).withdrawalHoldDays;

      expect(holdFor(CarrierTier.trusted),
          lessThan(holdFor(CarrierTier.identified)));
      expect(holdFor(CarrierTier.banked),
          lessThan(holdFor(CarrierTier.identified)));
    });
  });
}
