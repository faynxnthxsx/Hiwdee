import 'dart:math' as math;

import '../domain/customs_category.dart';
import '../domain/import_route.dart';

/// กติกาภาษีนำเข้าของไทย
///
/// ⚠️ **ข้อจำกัดที่ต้องบอกผู้ใช้เสมอ**
/// ตัวเลขที่ได้เป็นการ *ประมาณการ* เพื่อช่วยตัดสินใจเท่านั้น
/// อำนาจชี้ขาดพิกัด ราคา และค่าภาษี เป็นของเจ้าหน้าที่ศุลกากรที่หน้าด่าน
/// ศุลกากรมีสิทธิตีราคาใหม่ (customs valuation) ถ้าเห็นว่าราคาที่สำแดงต่ำผิดปกติ
abstract final class ThaiCustoms {
  /// ภาษีมูลค่าเพิ่ม
  static const vatRate = 0.07;

  /// ของส่งทางไปรษณีย์ที่ราคา CIF ไม่เกินนี้ ได้รับยกเว้น *อากรขาเข้า*
  static const postalDutyFreeThresholdTHB = 1500.0;

  /// ตั้งแต่ปี 2567 มีการเก็บ VAT กับของนำเข้ามูลค่าต่ำที่เดิมเคยไม่เก็บ
  /// เปิดเป็นสวิตช์ไว้ เพราะเป็นมาตรการที่แก้ไขได้บ่อย
  static const collectVatBelowThreshold = true;

  /// ของใช้ส่วนตัวติดตัวผู้โดยสาร มูลค่ารวมไม่เกินนี้ได้รับยกเว้น
  /// เงื่อนไข: ต้องเป็น "ของใช้ส่วนตัว" และ "ปริมาณสมควรแก่ฐานะ"
  static const travellerAllowanceTHB = 20000.0;

  /// โทษปรับกรณีสำแดงเท็จ — ใส่ไว้เพื่อเตือนในแอป ไม่ได้ใช้คำนวณ
  static const falseDeclarationPenaltyMultiplier = 4;

  /// ประเมินภาษีนำเข้า
  ///
  /// [goodsValueTHB] ราคาสินค้าที่ซื้อจริง (ราคาที่จะสำแดง)
  /// [internationalFreightTHB] ค่าขนส่งระหว่างประเทศ — เป็นส่วนหนึ่งของ CIF
  /// [insuranceTHB] ค่าประกันระหว่างขนส่ง — เป็นส่วนหนึ่งของ CIF
  /// [allowanceUsedTHB] สิทธิ 20,000 บาทที่นักหิ้วใช้ไปแล้วในทริปนี้
  /// [isDivisible] ของแยกชิ้นได้ไหม (ซื้อ 5 ชิ้นเท่ากัน = แยกได้)
  ///               ของชิ้นเดียวที่ราคาเกินสิทธิ จะถูกคิดภาษีเต็มจำนวน
  static TaxAssessment assess({
    required ImportRoute route,
    required CustomsProfile profile,
    required double goodsValueTHB,
    double internationalFreightTHB = 0,
    double insuranceTHB = 0,
    double allowanceUsedTHB = 0,
    bool isDivisible = true,
  }) {
    if (route == ImportRoute.domestic) return TaxAssessment.zero;

    final warnings = _warningsFor(profile);
    final cif = goodsValueTHB + internationalFreightTHB + insuranceTHB;

    return switch (route) {
      ImportRoute.handCarry => _assessHandCarry(
          profile: profile,
          goodsValueTHB: goodsValueTHB,
          cif: cif,
          allowanceUsedTHB: allowanceUsedTHB,
          isDivisible: isDivisible,
          warnings: warnings,
        ),
      ImportRoute.postal => _assessPostal(
          profile: profile,
          cif: cif,
          warnings: warnings,
        ),
      ImportRoute.domestic => TaxAssessment.zero,
    };
  }

  static TaxAssessment _assessHandCarry({
    required CustomsProfile profile,
    required double goodsValueTHB,
    required double cif,
    required double allowanceUsedTHB,
    required bool isDivisible,
    required List<String> warnings,
  }) {
    final remaining =
        math.max(0.0, travellerAllowanceTHB - allowanceUsedTHB);

    if (goodsValueTHB <= remaining) {
      return TaxAssessment(
        route: ImportRoute.handCarry,
        cif: cif,
        taxableBase: 0,
        dutyRate: profile.dutyRate,
        importDuty: 0,
        excise: 0,
        vatBase: 0,
        vat: 0,
        isExempt: true,
        reason: 'อยู่ในสิทธิของใช้ส่วนตัวติดตัวผู้โดยสาร '
            '(ใช้ไป ${_thb(allowanceUsedTHB + goodsValueTHB)} '
            'จากสิทธิ ${_thb(travellerAllowanceTHB)})',
        warnings: warnings,
      );
    }

    // ของแยกชิ้นได้ → เสียภาษีเฉพาะส่วนที่เกินสิทธิ
    // ของชิ้นเดียวราคาเกินสิทธิ → เสียเต็มจำนวน แบ่งไม่ได้
    final taxableBase = isDivisible ? goodsValueTHB - remaining : goodsValueTHB;

    final duty = taxableBase * profile.dutyRate;
    final excise = (taxableBase + duty) * profile.exciseRate;
    final vatBase = taxableBase + duty + excise;

    return TaxAssessment(
      route: ImportRoute.handCarry,
      cif: cif,
      taxableBase: taxableBase,
      dutyRate: profile.dutyRate,
      importDuty: duty,
      excise: excise,
      vatBase: vatBase,
      vat: vatBase * vatRate,
      isExempt: false,
      reason: isDivisible
          ? 'เกินสิทธิ ${_thb(travellerAllowanceTHB)} '
              'เสียภาษีเฉพาะส่วนเกิน ${_thb(taxableBase)}'
          : 'ของชิ้นเดียวราคาเกินสิทธิ แบ่งส่วนไม่ได้ '
              'จึงคิดภาษีจากมูลค่าเต็ม',
      warnings: warnings,
    );
  }

  static TaxAssessment _assessPostal({
    required CustomsProfile profile,
    required double cif,
    required List<String> warnings,
  }) {
    if (cif <= postalDutyFreeThresholdTHB) {
      final vat = collectVatBelowThreshold ? cif * vatRate : 0.0;
      return TaxAssessment(
        route: ImportRoute.postal,
        cif: cif,
        taxableBase: collectVatBelowThreshold ? cif : 0,
        dutyRate: profile.dutyRate,
        importDuty: 0,
        excise: 0,
        vatBase: collectVatBelowThreshold ? cif : 0,
        vat: vat,
        isExempt: !collectVatBelowThreshold,
        reason: collectVatBelowThreshold
            ? 'CIF ไม่เกิน ${_thb(postalDutyFreeThresholdTHB)} '
                'ยกเว้นอากรขาเข้า แต่ยังเสีย VAT 7%'
            : 'CIF ไม่เกิน ${_thb(postalDutyFreeThresholdTHB)} ได้รับยกเว้น',
        warnings: warnings,
      );
    }

    final duty = cif * profile.dutyRate;
    final excise = (cif + duty) * profile.exciseRate;
    final vatBase = cif + duty + excise;

    return TaxAssessment(
      route: ImportRoute.postal,
      cif: cif,
      taxableBase: cif,
      dutyRate: profile.dutyRate,
      importDuty: duty,
      excise: excise,
      vatBase: vatBase,
      vat: vatBase * vatRate,
      isExempt: false,
      reason: 'CIF ${_thb(cif)} เกินเกณฑ์ยกเว้น '
          '${_thb(postalDutyFreeThresholdTHB)} '
          'คิดอากร ${(profile.dutyRate * 100).toStringAsFixed(0)}% แล้วบวก VAT ทับ',
      warnings: warnings,
    );
  }

  static List<String> _warningsFor(CustomsProfile profile) => [
        if (profile.requiresFdaPermit)
          'หมวดนี้ต้องมีใบอนุญาต อย. สำหรับการนำเข้าเชิงพาณิชย์ '
              'ถ้าไม่มีอาจถูกยึดแม้ยินดีเสียภาษี',
        if (profile.commonlyInspected)
          'เป็นหมวดที่ศุลกากรเปิดตรวจบ่อย ควรพกใบเสร็จตัวจริงติดตัว',
        if (profile.ftaEligible)
          'ถ้ามีใบรับรองถิ่นกำเนิดสินค้า (Form E / Form AK / JTEPA) '
              'อาจใช้สิทธิลดอากรตาม FTA ได้',
        if (profile.note.isNotEmpty) profile.note,
      ];

  static String _thb(double v) => '${v.round()} บาท';
}
