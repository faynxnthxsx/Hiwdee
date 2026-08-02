/// ช่องทางที่ของเข้าประเทศ — ตัวแปรที่ทำให้ภาษีต่างกันมากที่สุด
enum ImportRoute {
  /// หิ้วติดตัวผู้โดยสาร ใช้สิทธิของใช้ส่วนตัว
  handCarry('หิ้วติดตัว', 'ของติดตัวผู้โดยสารทางอากาศ'),

  /// ส่งทางไปรษณีย์ / ขนส่งด่วนระหว่างประเทศ
  postal('ส่งไปรษณีย์', 'ของส่งทางไปรษณีย์หรือขนส่งด่วน'),

  /// ต้นทางอยู่ในไทย ไม่มีพิธีการศุลกากร
  domestic('ในประเทศ', 'ขนส่งภายในประเทศ ไม่มีภาษีนำเข้า');

  const ImportRoute(this.text, this.description);
  final String text;
  final String description;
}

/// ผลการประเมินภาษีนำเข้าของ 1 ออเดอร์
class TaxAssessment {
  const TaxAssessment({
    required this.route,
    required this.cif,
    required this.taxableBase,
    required this.dutyRate,
    required this.importDuty,
    required this.excise,
    required this.vatBase,
    required this.vat,
    required this.isExempt,
    required this.reason,
    this.warnings = const [],
  });

  final ImportRoute route;

  /// Cost + Insurance + Freight — ฐานที่ศุลกากรใช้ ไม่ใช่ราคาสินค้าเปล่าๆ
  final double cif;

  /// ส่วนที่ต้องเสียภาษีจริง หลังหักสิทธิยกเว้นแล้ว
  final double taxableBase;

  final double dutyRate;
  final double importDuty;
  final double excise;

  /// ฐานคำนวณ VAT = CIF + อากร + สรรพสามิต (VAT คิดทับอากรอีกที)
  final double vatBase;
  final double vat;

  final bool isExempt;

  /// เหตุผลที่ยกเว้นหรือไม่ยกเว้น เอาไว้โชว์ให้ผู้ใช้เข้าใจ
  final String reason;

  /// ข้อควรระวังที่ไม่เกี่ยวกับตัวเงิน เช่น ต้องมี อย.
  final List<String> warnings;

  double get total => importDuty + excise + vat;

  /// ภาษีคิดเป็นกี่ % ของราคาสินค้า
  double effectiveRateOn(double goodsValue) =>
      goodsValue <= 0 ? 0 : total / goodsValue;

  static const zero = TaxAssessment(
    route: ImportRoute.domestic,
    cif: 0,
    taxableBase: 0,
    dutyRate: 0,
    importDuty: 0,
    excise: 0,
    vatBase: 0,
    vat: 0,
    isExempt: true,
    reason: 'ของในประเทศ ไม่มีภาษีนำเข้า',
  );
}
