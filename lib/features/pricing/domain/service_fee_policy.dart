import 'dart:math' as math;

import 'parcel.dart';

/// ปัจจัยที่ทำให้งานหิ้วยากขึ้น → ค่าหิ้วสูงขึ้น
enum FeeModifier {
  fragile('ของเปราะ / ขวดแก้ว', 1.15),
  coldChain('ต้องคุมความเย็น', 1.40),
  specialTrip('ต้องไปร้านเฉพาะ ไม่ใช่ทางผ่าน', 1.20),
  urgent('ด่วนภายใน 3 วัน', 1.30),
  highValue('มูลค่าสูงเกิน 20,000 บาท', 1.25),
  bulky('ขนาดใหญ่กินพื้นที่กระเป๋า', 1.20);

  const FeeModifier(this.text, this.multiplier);
  final String text;
  final double multiplier;
}

/// สูตรคิดค่าจ้างหิ้ว
///
/// หลักคิด: ต้นทุนของนักหิ้วมีสองแบบที่ไม่เกี่ยวกันเลย
///  1. **พื้นที่กระเป๋า** — ของหนักหรือใหญ่กินโควตาสัมภาระ
///  2. **ความรับผิดชอบ** — ของแพงพังแล้วชดใช้หนัก
/// จึงคิดทั้งสองฐานแล้วเอาตัวที่มากกว่า ไม่ใช่บวกกัน
/// (ถ้าบวกกัน ของเล็กแต่แพงจะโดนคิดสองเด้งโดยไม่มีเหตุผล)
abstract final class ServiceFeePolicy {
  /// ค่าเริ่มต้นครอบคลุมเวลาที่เสียไปกับการเดินไปร้านและสื่อสาร
  static const baseFeeTHB = 150.0;

  /// เปอร์เซ็นต์จากมูลค่าสินค้า สะท้อนความเสี่ยงที่นักหิ้วแบก
  static const valueRate = 0.05;

  /// เพดานกันค่าหิ้วพุ่งจนไร้เหตุผลเวลาของแพงมาก
  static const valueComponentCapTHB = 3000.0;

  static double compute({
    required Parcel parcel,
    required double ratePerKgTHB,
    required double goodsValueTHB,
    Set<FeeModifier> modifiers = const {},
  }) {
    final byWeight = parcel.billableKg * ratePerKgTHB;

    final byValue = baseFeeTHB +
        math.min(goodsValueTHB * valueRate, valueComponentCapTHB);

    final base = math.max(byWeight, byValue);

    var multiplier = 1.0;
    for (final m in modifiers) {
      multiplier *= m.multiplier;
    }

    return _roundTo5(base * multiplier);
  }

  /// แยกให้ดูว่าฐานไหนเป็นตัวกำหนดราคา เอาไว้อธิบายผู้ใช้
  static String explain({
    required Parcel parcel,
    required double ratePerKgTHB,
    required double goodsValueTHB,
  }) {
    final byWeight = parcel.billableKg * ratePerKgTHB;
    final byValue = baseFeeTHB +
        math.min(goodsValueTHB * valueRate, valueComponentCapTHB);

    if (byWeight >= byValue) {
      final basis = parcel.isVolumetricDriven ? 'ขนาดกล่อง' : 'น้ำหนัก';
      return 'คิดตาม$basis ${parcel.billableKg.toStringAsFixed(1)} กก. '
          '× ${ratePerKgTHB.round()} บาท/กก.';
    }
    return 'คิดตามมูลค่าสินค้า '
        '(ค่าเริ่มต้น ${baseFeeTHB.round()} + '
        '${(valueRate * 100).round()}% ของราคาของ)';
  }

  /// ปัดขึ้นเป็นหลัก 5 บาท ให้ตัวเลขดูเป็นราคาจริง
  static double _roundTo5(double v) => (v / 5).ceilToDouble() * 5;

  /// เสนออัตราต่อกิโลตามระยะทางของเส้นทาง
  static double suggestRatePerKg({required bool isInternational}) =>
      isInternational ? 350 : 120;
}

/// ค่าขนส่งภายในประเทศจากนักหิ้วถึงบ้านลูกค้า
abstract final class DomesticShipping {
  /// ตารางน้ำหนัก → ราคา (อ้างอิงเรทขนส่งเอกชนทั่วไป)
  static const _tiers = <(double maxKg, double priceTHB)>[
    (0.5, 35),
    (1.0, 45),
    (2.0, 60),
    (3.0, 75),
    (5.0, 100),
    (10.0, 155),
    (20.0, 260),
  ];

  /// พื้นที่ห่างไกล/เกาะ มีค่าบริการเพิ่ม
  static const remoteAreaSurchargeTHB = 50.0;

  static double quote({
    required Parcel parcel,
    bool remoteArea = false,
    bool codRequired = false,
  }) {
    final kg = parcel.chargeableKg;
    var price = _tiers.last.$2;

    for (final (maxKg, tierPrice) in _tiers) {
      if (kg <= maxKg) {
        price = tierPrice;
        break;
      }
    }

    // เกิน 20 กก. คิดเพิ่มเป็นกิโล
    if (kg > 20) {
      price = _tiers.last.$2 + (kg - 20).ceilToDouble() * 15;
    }

    if (remoteArea) price += remoteAreaSurchargeTHB;

    // เก็บเงินปลายทางมีค่าธรรมเนียม แต่ในระบบ escrow ไม่ควรใช้
    if (codRequired) price += 20;

    return price;
  }
}
