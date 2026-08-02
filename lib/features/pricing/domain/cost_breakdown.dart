import 'import_route.dart';

/// รายการค่าใช้จ่ายหนึ่งบรรทัดในใบเสนอราคา
class CostLine {
  const CostLine({
    required this.label,
    required this.amount,
    this.hint = '',
    this.isDeduction = false,
    this.isHighlight = false,
  });

  final String label;
  final double amount;
  final String hint;

  /// เป็นรายการหักออก เช่น ภาษีต้นทางที่ขอคืนได้
  final bool isDeduction;

  final bool isHighlight;
}

/// ผลการคำนวณราคาเต็มของ 1 ออเดอร์ ตามช่องทางนำเข้าหนึ่งช่องทาง
class CostBreakdown {
  const CostBreakdown({
    required this.route,
    required this.currencyCode,
    required this.currencySymbol,
    required this.goodsForeign,
    required this.localTaxRefundForeign,
    required this.fxRate,
    required this.fxSpread,
    required this.goodsTHB,
    required this.serviceFee,
    required this.internationalFreight,
    required this.insurance,
    required this.domesticShipping,
    required this.tax,
    required this.platformFee,
    required this.paymentFee,
    required this.serviceFeeExplanation,
  });

  final ImportRoute route;

  final String currencyCode;
  final String currencySymbol;

  /// ราคาป้ายที่ต้นทาง (สกุลต่างประเทศ)
  final double goodsForeign;

  /// ภาษีต้นทางที่ขอคืนได้ (สกุลต่างประเทศ) — เงินที่ได้คืนจริง
  final double localTaxRefundForeign;

  final double fxRate;
  final double fxSpread;

  /// ต้นทุนสินค้าเป็นบาทแล้ว หลังหักคืนภาษีและบวก spread
  final double goodsTHB;

  final double serviceFee;
  final double internationalFreight;
  final double insurance;
  final double domesticShipping;

  final TaxAssessment tax;

  final double platformFee;
  final double paymentFee;

  final String serviceFeeExplanation;

  /// ยอดก่อนค่าธรรมเนียมชำระเงิน
  double get subtotal =>
      goodsTHB +
      serviceFee +
      internationalFreight +
      insurance +
      domesticShipping +
      tax.total +
      platformFee;

  /// ยอดที่ผู้ฝากจ่ายจริง
  double get total => subtotal + paymentFee;

  /// เงินที่ต้องโอนให้นักหิ้ว "ก่อน" ออกไปซื้อของ
  /// = ทุกบาทที่นักหิ้วจะต้องจ่ายออกไป นักหิ้วไม่ควักเงินตัวเองเลย
  double get carrierAdvance =>
      goodsTHB + internationalFreight + domesticShipping + tax.total;

  /// ค่าจ้างที่นักหิ้วได้จริงหลังหักค่าธรรมเนียมแพลตฟอร์ม
  /// จ่ายงวดสุดท้ายหลังผู้ฝากกดรับของ
  double get carrierEarning => serviceFee - platformFee;

  /// รายได้ของแพลตฟอร์ม
  double get platformRevenue => platformFee;

  /// ภาษีคิดเป็นสัดส่วนเท่าไหร่ของราคาสินค้า
  double get effectiveTaxRate => tax.effectiveRateOn(goodsTHB);

  List<CostLine> get lines => [
        CostLine(
          label: 'ราคาสินค้าที่ต้นทาง',
          amount: goodsForeign * fxRate,
          hint: '$currencySymbol${goodsForeign.round()} '
              '× $fxRate บาท',
        ),
        if (localTaxRefundForeign > 0)
          CostLine(
            label: 'หักภาษีต้นทางที่ขอคืนได้',
            amount: -localTaxRefundForeign * fxRate,
            hint: 'ขอคืนที่ร้าน tax-free หรือเคาน์เตอร์สนามบิน',
            isDeduction: true,
          ),
        if (fxSpread > 0)
          CostLine(
            label: 'ส่วนต่างอัตราแลกเปลี่ยน',
            amount: (goodsForeign - localTaxRefundForeign) * fxRate * fxSpread,
            hint: 'กันเรทแกว่งระหว่างวันรับงานกับวันซื้อจริง '
                '${(fxSpread * 100).toStringAsFixed(1)}%',
          ),
        CostLine(
          label: 'ค่าจ้างหิ้ว',
          amount: serviceFee,
          hint: serviceFeeExplanation,
          isHighlight: true,
        ),
        if (internationalFreight > 0)
          CostLine(
            label: 'ค่าขนส่งระหว่างประเทศ',
            amount: internationalFreight,
            hint: 'นับรวมเป็นฐาน CIF ที่ใช้คำนวณภาษีด้วย',
          ),
        if (insurance > 0)
          CostLine(label: 'ค่าประกันระหว่างขนส่ง', amount: insurance),
        if (tax.importDuty > 0)
          CostLine(
            label: 'อากรขาเข้า',
            amount: tax.importDuty,
            hint: 'ฐาน CIF ${tax.cif.round()} '
                '× ${(tax.dutyRate * 100).toStringAsFixed(0)}%',
          ),
        if (tax.excise > 0)
          CostLine(label: 'ภาษีสรรพสามิต', amount: tax.excise),
        if (tax.vat > 0)
          CostLine(
            label: 'VAT 7%',
            amount: tax.vat,
            hint: 'คิดจากฐาน ${tax.vatBase.round()} บาท '
                '(CIF + อากร) ไม่ใช่จากราคาสินค้าเปล่า',
          ),
        if (tax.isExempt)
          CostLine(
            label: 'ภาษีนำเข้า',
            amount: 0,
            hint: tax.reason,
            isHighlight: true,
          ),
        CostLine(
          label: 'ค่าขนส่งในประเทศ',
          amount: domesticShipping,
          hint: 'จากนักหิ้วถึงหน้าบ้านคุณ',
        ),
        CostLine(
          label: 'ค่าธรรมเนียมแพลตฟอร์ม',
          amount: platformFee,
          hint: 'คิดจากค่าหิ้วเท่านั้น ไม่คิดจากราคาสินค้า',
        ),
        CostLine(
          label: 'ค่าธรรมเนียมชำระเงิน',
          amount: paymentFee,
          hint: 'ค่าธรรมเนียมของผู้ให้บริการรับชำระเงิน',
        ),
      ];
}

/// ผลเทียบสองช่องทาง — จุดขายหลักของแอป
class RouteComparison {
  const RouteComparison({required this.handCarry, required this.postal});

  final CostBreakdown handCarry;
  final CostBreakdown postal;

  CostBreakdown get cheaper =>
      handCarry.total <= postal.total ? handCarry : postal;

  CostBreakdown get pricier =>
      handCarry.total <= postal.total ? postal : handCarry;

  double get savings => pricier.total - cheaper.total;

  double get savingsRatio =>
      pricier.total <= 0 ? 0 : savings / pricier.total;

  bool get isSignificant => savingsRatio >= 0.05;
}
