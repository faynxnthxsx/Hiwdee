import '../../request/domain/haul_request.dart';

/// โปรไฟล์ศุลกากรของสินค้าแต่ละหมวด
///
/// ⚠️ อัตราอากรที่ใส่ไว้เป็น **ค่าประมาณเพื่อแสดงผล** เท่านั้น
/// อัตราจริงผูกกับพิกัดศุลกากร (HS Code) ระดับ 8 หลักของสินค้าชิ้นนั้นๆ
/// และเปลี่ยนแปลงได้ตามประกาศกรมศุลกากร — ก่อนใช้งานจริงต้องตรวจสอบพิกัด
/// ที่ e-Tariff ของกรมศุลกากรทุกครั้ง
class CustomsProfile {
  const CustomsProfile({
    required this.category,
    required this.hsChapter,
    required this.dutyRate,
    this.exciseRate = 0,
    this.requiresFdaPermit = false,
    this.commonlyInspected = false,
    this.ftaEligible = true,
    this.note = '',
  });

  final HaulCategory category;

  /// ตอนของพิกัดศุลกากร ใช้เป็นตัวชี้ให้ผู้ใช้ไปตรวจต่อ
  final String hsChapter;

  /// อัตราอากรขาเข้าโดยประมาณ (0.20 = 20%)
  final double dutyRate;

  /// ภาษีสรรพสามิต ถ้ามี (น้ำหอม เครื่องดื่มแอลกอฮอล์ ฯลฯ)
  final double exciseRate;

  /// ต้องมีใบอนุญาต อย. — ถ้าไม่มี เสี่ยงโดนยึดแม้จะยอมเสียภาษี
  final bool requiresFdaPermit;

  /// หมวดที่ศุลกากรมักเปิดตรวจ
  final bool commonlyInspected;

  /// มีโอกาสใช้สิทธิลดอากรตามความตกลงการค้าเสรีได้ ถ้ามีใบรับรองถิ่นกำเนิด
  final bool ftaEligible;

  final String note;
}

/// ตารางอ้างอิงต่อหมวดสินค้าในแอป
abstract final class CustomsProfiles {
  static const _table = <HaulCategory, CustomsProfile>{
    HaulCategory.beauty: CustomsProfile(
      category: HaulCategory.beauty,
      hsChapter: '3303–3307',
      dutyRate: 0.20,
      exciseRate: 0,
      commonlyInspected: true,
      note: 'น้ำหอมบางพิกัดมีภาษีสรรพสามิตเพิ่ม '
          'เครื่องสำอางนำเข้าเชิงพาณิชย์ต้องจดแจ้ง อย.',
    ),
    HaulCategory.fashion: CustomsProfile(
      category: HaulCategory.fashion,
      hsChapter: '4202 / 6401–6405',
      dutyRate: 0.20,
      note: 'กระเป๋าหนังแท้และรองเท้าอัตราต่างกัน ตรวจพิกัดก่อน',
    ),
    HaulCategory.gadget: CustomsProfile(
      category: HaulCategory.gadget,
      hsChapter: '8517 / 8471 / 8518',
      dutyRate: 0.00,
      note: 'สินค้า IT ส่วนใหญ่อากร 0% ตามความตกลง ITA '
          'แต่ยังต้องเสีย VAT 7% — อุปกรณ์สื่อสารบางรุ่นต้องขึ้นทะเบียน กสทช.',
    ),
    HaulCategory.collectible: CustomsProfile(
      category: HaulCategory.collectible,
      hsChapter: '9503',
      dutyRate: 0.20,
      note: 'ของเล่นกล่องใหญ่มักโดนคิดตามน้ำหนักปริมาตร',
    ),
    HaulCategory.snack: CustomsProfile(
      category: HaulCategory.snack,
      hsChapter: '1704–1806 / 2106',
      dutyRate: 0.30,
      requiresFdaPermit: true,
      commonlyInspected: true,
      note: 'อาหารนำเข้าเชิงพาณิชย์ต้องมีเลข อย. '
          'ของสด/เนื้อสัตว์/นม มักห้ามนำเข้าติดตัวโดยเด็ดขาด',
    ),
    HaulCategory.supplement: CustomsProfile(
      category: HaulCategory.supplement,
      hsChapter: '2106 / 3004',
      dutyRate: 0.20,
      requiresFdaPermit: true,
      commonlyInspected: true,
      note: '⚠️ ความเสี่ยงสูงสุดในบรรดาของหิ้ว — '
          'อาหารเสริมและยาต้องมีใบอนุญาต อย. '
          'ถ้าเข้าข่ายยาต้องมีใบสั่งแพทย์ ไม่งั้นยึดทันทีแม้ยอมจ่ายภาษี',
    ),
    HaulCategory.local: CustomsProfile(
      category: HaulCategory.local,
      hsChapter: '—',
      dutyRate: 0.00,
      ftaEligible: false,
      note: 'ของในประเทศ ไม่มีภาษีนำเข้า',
    ),
    HaulCategory.other: CustomsProfile(
      category: HaulCategory.other,
      hsChapter: 'ต้องระบุ',
      dutyRate: 0.20,
      note: 'ยังไม่ระบุพิกัด ใช้อัตรากลาง 20% เป็นค่าประมาณอย่างระมัดระวัง',
    ),
  };

  static CustomsProfile of(HaulCategory category) =>
      _table[category] ?? _table[HaulCategory.other]!;

  static List<CustomsProfile> get all => _table.values.toList(growable: false);
}
