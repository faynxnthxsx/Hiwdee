import 'dart:math' as math;

import '../../request/domain/haul_request.dart';
import '../data/origin_countries.dart';
import '../data/thai_customs_rules.dart';
import 'cost_breakdown.dart';
import 'customs_category.dart';
import 'import_route.dart';
import 'parcel.dart';
import 'service_fee_policy.dart';

/// ข้อมูลตั้งต้นที่ต้องรู้ก่อนคำนวณราคา
class QuoteInput {
  const QuoteInput({
    required this.category,
    required this.origin,
    required this.goodsForeign,
    required this.parcel,
    this.ratePerKgTHB,
    this.modifiers = const {},
    this.claimLocalTaxRefund = true,
    this.allowanceUsedTHB = 0,
    this.isDivisible = true,
    this.remoteArea = false,
    this.insureShipment = true,
    this.fxSpread = FxRates.defaultSpread,
    this.fxRateTHB,
  });

  final HaulCategory category;
  final OriginCountry origin;

  /// ราคาป้ายรวมทุกชิ้น ในสกุลเงินต้นทาง
  final double goodsForeign;

  final Parcel parcel;

  /// เรทค่าหิ้วต่อกิโลของเส้นทางนี้ ถ้าไม่ระบุจะใช้ค่าแนะนำ
  final double? ratePerKgTHB;

  final Set<FeeModifier> modifiers;

  /// นักหิ้วจะไปขอคืนภาษีต้นทางให้ไหม
  final bool claimLocalTaxRefund;

  /// สิทธิ 20,000 บาทที่นักหิ้วใช้ไปแล้วกับออเดอร์อื่นในทริปเดียวกัน
  final double allowanceUsedTHB;

  /// ของแบ่งชิ้นได้ไหม (ของชิ้นเดียวราคาแพงแบ่งไม่ได้)
  final bool isDivisible;

  final bool remoteArea;
  final bool insureShipment;
  final double fxSpread;

  /// เรทที่ผู้ใช้กรอกเอง (บาทต่อ 1 หน่วยสกุลต้นทาง)
  /// ถ้าไม่ระบุจะใช้ตารางใน [FxRates] — จำเป็นเมื่อเลือก "ประเทศอื่นๆ"
  final double? fxRateTHB;

  bool get isDomestic => origin.code == 'TH';

  QuoteInput copyWith({
    HaulCategory? category,
    OriginCountry? origin,
    double? goodsForeign,
    Parcel? parcel,
    double? ratePerKgTHB,
    Set<FeeModifier>? modifiers,
    bool? claimLocalTaxRefund,
    double? allowanceUsedTHB,
    bool? isDivisible,
    bool? remoteArea,
    bool? insureShipment,
    double? fxSpread,
    double? fxRateTHB,
  }) {
    return QuoteInput(
      category: category ?? this.category,
      origin: origin ?? this.origin,
      goodsForeign: goodsForeign ?? this.goodsForeign,
      parcel: parcel ?? this.parcel,
      ratePerKgTHB: ratePerKgTHB ?? this.ratePerKgTHB,
      modifiers: modifiers ?? this.modifiers,
      claimLocalTaxRefund: claimLocalTaxRefund ?? this.claimLocalTaxRefund,
      allowanceUsedTHB: allowanceUsedTHB ?? this.allowanceUsedTHB,
      isDivisible: isDivisible ?? this.isDivisible,
      remoteArea: remoteArea ?? this.remoteArea,
      insureShipment: insureShipment ?? this.insureShipment,
      fxSpread: fxSpread ?? this.fxSpread,
      fxRateTHB: fxRateTHB ?? this.fxRateTHB,
    );
  }
}

/// เครื่องคำนวณราคาเต็มของออเดอร์หิ้ว
abstract final class PricingEngine {
  /// ค่าธรรมเนียมแพลตฟอร์ม คิดจาก "ค่าหิ้ว" เท่านั้น
  ///
  /// เจตนา: ถ้าคิดจากยอดรวม ของยิ่งแพงแพลตฟอร์มยิ่งได้เยอะทั้งที่ทำงานเท่าเดิม
  /// ผู้ใช้จะรู้สึกโดนขูดแล้วหนีไปโอนกันเอง ซึ่งทำให้ทุกคนไม่ได้รับความคุ้มครอง
  static const platformFeeRate = 0.08;

  /// ค่าธรรมเนียมผู้ให้บริการรับชำระเงิน
  static const paymentFeeRate = 0.0365;

  /// ค่าประกันการขนส่ง คิดจากมูลค่าสินค้า
  static const insuranceRate = 0.01;

  static CostBreakdown quote(QuoteInput input, ImportRoute route) {
    final profile = CustomsProfiles.of(input.category);
    final fxRate =
        input.fxRateTHB ?? FxRates.thbPer(input.origin.currencyCode);

    // ── ต้นทุนสินค้า ────────────────────────────────────────────
    final refundForeign = input.claimLocalTaxRefund
        ? _refundableAmount(input)
        : 0.0;

    final netForeign = input.goodsForeign - refundForeign;
    final goodsTHB = netForeign * fxRate * (1 + input.fxSpread);

    // ── ค่าขนส่ง ────────────────────────────────────────────────
    // ของในประเทศไม่มีขาระหว่างประเทศ แม้ผู้ใช้จะเลือกช่องทางไปรษณีย์
    final shipsInternationally =
        !input.isDomestic && route == ImportRoute.postal;

    final intlFreight = shipsInternationally
        ? _internationalFreight(input.parcel, input.origin)
        : 0.0;

    final insurance = shipsInternationally && input.insureShipment
        ? goodsTHB * insuranceRate
        : 0.0;

    final domestic = DomesticShipping.quote(
      parcel: input.parcel,
      remoteArea: input.remoteArea,
    );

    // ── ค่าหิ้ว ─────────────────────────────────────────────────
    final ratePerKg = input.ratePerKgTHB ??
        ServiceFeePolicy.suggestRatePerKg(isInternational: !input.isDomestic);

    final modifiers = _autoModifiers(input, goodsTHB);

    final serviceFee = ServiceFeePolicy.compute(
      parcel: input.parcel,
      ratePerKgTHB: ratePerKg,
      goodsValueTHB: goodsTHB,
      modifiers: modifiers,
    );

    // ── ภาษีนำเข้า ──────────────────────────────────────────────
    final tax = ThaiCustoms.assess(
      route: input.isDomestic ? ImportRoute.domestic : route,
      profile: profile,
      goodsValueTHB: goodsTHB,
      internationalFreightTHB: intlFreight,
      insuranceTHB: insurance,
      allowanceUsedTHB: input.allowanceUsedTHB,
      isDivisible: input.isDivisible,
    );

    // ── ค่าธรรมเนียม ────────────────────────────────────────────
    final platformFee = serviceFee * platformFeeRate;

    final beforePaymentFee = goodsTHB +
        serviceFee +
        intlFreight +
        insurance +
        domestic +
        tax.total +
        platformFee;

    // gross-up: gateway หัก % จากยอดที่รูด ไม่ใช่จากยอดก่อนหัก
    // ถ้าไม่ gross-up แพลตฟอร์มจะได้เงินไม่ครบตามที่ตั้งไว้
    final paymentFee =
        beforePaymentFee * paymentFeeRate / (1 - paymentFeeRate);

    return CostBreakdown(
      route: input.isDomestic ? ImportRoute.domestic : route,
      currencyCode: input.origin.currencyCode,
      currencySymbol: input.origin.currencySymbol,
      goodsForeign: input.goodsForeign,
      localTaxRefundForeign: refundForeign,
      fxRate: fxRate,
      fxSpread: input.fxSpread,
      goodsTHB: goodsTHB,
      serviceFee: serviceFee,
      internationalFreight: intlFreight,
      insurance: insurance,
      domesticShipping: domestic,
      tax: tax,
      platformFee: platformFee,
      paymentFee: paymentFee,
      serviceFeeExplanation: ServiceFeePolicy.explain(
        parcel: input.parcel,
        ratePerKgTHB: ratePerKg,
        goodsValueTHB: goodsTHB,
      ),
    );
  }

  /// เทียบสองช่องทางให้ผู้ใช้เห็นว่าต่างกันเท่าไหร่
  static RouteComparison compare(QuoteInput input) => RouteComparison(
        handCarry: quote(input, ImportRoute.handCarry),
        postal: quote(input, ImportRoute.postal),
      );

  /// ภาษีต้นทางที่ขอคืนได้จริง — ต้องถึงยอดขั้นต่ำของประเทศนั้นก่อน
  static double _refundableAmount(QuoteInput input) {
    final origin = input.origin;
    if (!origin.taxRefundAvailable) return 0;
    if (input.goodsForeign < origin.minSpendForRefund) return 0;

    // ราคาป้ายรวมภาษีอยู่แล้ว จึงต้องถอดออกจากยอดรวม ไม่ใช่คูณตรงๆ
    final taxIncluded =
        input.goodsForeign * origin.localTaxRate / (1 + origin.localTaxRate);

    // หักค่าดำเนินการของผู้ให้บริการคืนภาษี
    return taxIncluded * 0.85;
  }

  /// ค่าขนส่งระหว่างประเทศโดยประมาณ
  static double _internationalFreight(Parcel parcel, OriginCountry origin) {
    final perKg = switch (origin.code) {
      'JP' || 'KR' || 'CN' || 'TW' || 'HK' || 'SG' => 320.0,
      'US' => 650.0,
      'EU' => 700.0,
      _ => 400.0,
    };
    const handling = 250.0;
    return handling + math.max(0.5, parcel.chargeableKg) * perKg;
  }

  /// เติมตัวคูณอัตโนมัติจากลักษณะของสินค้า
  static Set<FeeModifier> _autoModifiers(QuoteInput input, double goodsTHB) {
    return {
      ...input.modifiers,
      if (goodsTHB > 20000) FeeModifier.highValue,
      if (input.parcel.isVolumetricDriven) FeeModifier.bulky,
    };
  }
}
