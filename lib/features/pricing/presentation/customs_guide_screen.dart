import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// คู่มือภาษีสำหรับนักหิ้วมือใหม่
///
/// เจตนาของหน้านี้: ให้นักหิ้ว **ประหยัดภาษีได้มากที่สุดเท่าที่กฎหมายอนุญาต**
/// และ **ไม่เผลอทำผิดโดยไม่รู้ตัว** — สองอย่างนี้ต้องมาคู่กัน
/// เพราะคนที่ยืนอยู่หน้าเคาน์เตอร์ศุลกากรคือนักหิ้ว ไม่ใช่แพลตฟอร์ม
class CustomsGuideScreen extends StatelessWidget {
  const CustomsGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(title: const Text('คู่มือภาษีสำหรับนักหิ้ว')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _intro(),
          _section(
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            title: 'ประหยัดได้ และถูกกฎหมาย 100%',
            subtitle: 'ทำได้เลย ไม่ต้องกลัวอะไรทั้งนั้น',
            items: _legalWays,
          ),
          _section(
            icon: Icons.block,
            color: AppColors.danger,
            title: 'ห้ามทำเด็ดขาด',
            subtitle: 'ไม่ใช่ "ช่องโหว่" แต่เป็นความผิดตามกฎหมายศุลกากร',
            items: _illegalActs,
          ),
          _section(
            icon: Icons.help_outline,
            color: AppColors.warning,
            title: 'พื้นที่สีเทาที่ต้องรู้ก่อนรับงาน',
            subtitle: 'เรื่องที่คนหิ้วส่วนใหญ่ไม่รู้ แล้วมารู้ตอนโดนเรียกตรวจ',
            items: _greyZone,
          ),
          _checklist(),
          _footer(),
        ],
      ),
    );
  }

  Widget _intro() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สิ่งที่ต้องเข้าใจก่อนอย่างอื่น',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _factRow('VAT ไทย', '7%'),
          _factRow('ยกเว้นของติดตัวผู้โดยสาร', 'ไม่เกิน 20,000 บาท/คน/เที่ยว'),
          _factRow('ยกเว้นอากรของส่งไปรษณีย์', 'CIF ไม่เกิน 1,500 บาท'),
          _factRow('ฐานคำนวณภาษี', 'CIF = ราคาของ + ประกัน + ค่าขนส่ง'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'VAT คิดจาก CIF + อากร ไม่ใช่คิดจากราคาสินค้าเปล่าๆ\n'
              'นี่คือจุดที่คนคำนวณผิดกันมากที่สุด และเป็นเหตุผลว่าทำไม '
              'ภาษีจริงถึงสูงกว่าที่คิดไว้เสมอ',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: AppColors.brandDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _factRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _section({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<_GuideItem> items,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 2),
            child: Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.inkMuted,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _tile(item, color)),
        ],
      ),
    );
  }

  Widget _tile(_GuideItem item, Color color) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: Text(item.emoji, style: const TextStyle(fontSize: 20)),
        title: Text(
          item.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: item.saving.isEmpty
            ? null
            : Text(
                item.saving,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
        children: [
          Text(
            item.detail,
            style: const TextStyle(fontSize: 13, height: 1.65),
          ),
          if (item.penalty.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '⚖️ โทษ: ${item.penalty}',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.55,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _checklist() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เช็คลิสต์ก่อนขึ้นเครื่องกลับไทย',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ..._checklistItems.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_box_outline_blank,
                      size: 18, color: AppColors.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t,
                      style: const TextStyle(fontSize: 13, height: 1.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.line),
      ),
      child: const Text(
        'ข้อมูลในหน้านี้เป็นความรู้ทั่วไปเพื่อช่วยให้วางแผนได้ '
        'ไม่ใช่คำแนะนำทางกฎหมายหรือภาษี '
        'เกณฑ์และอัตราเปลี่ยนแปลงได้ตามประกาศกรมศุลกากร '
        'ก่อนรับงานมูลค่าสูงควรตรวจสอบพิกัดสินค้าที่ระบบ e-Tariff '
        'ของกรมศุลกากรอีกครั้ง',
        style: TextStyle(
          fontSize: 11.5,
          height: 1.6,
          color: AppColors.inkMuted,
        ),
      ),
    );
  }
}

class _GuideItem {
  const _GuideItem({
    required this.emoji,
    required this.title,
    required this.detail,
    this.saving = '',
    this.penalty = '',
  });

  final String emoji;
  final String title;
  final String detail;
  final String saving;
  final String penalty;
}

const _legalWays = <_GuideItem>[
  _GuideItem(
    emoji: '🧾',
    title: 'ขอคืนภาษีต้นทางทุกครั้ง',
    saving: 'ประหยัดทันที 8–15% ของราคาของ',
    detail: 'ญี่ปุ่นและเกาหลีมี VAT 10% ฝังอยู่ในราคาป้ายอยู่แล้ว '
        'ถ้าซื้อร้านที่ร่วมโครงการ tax-free แล้วยื่นพาสปอร์ต '
        'จะได้ยกเว้นทันทีที่เคาน์เตอร์หรือขอคืนที่สนามบิน\n\n'
        'นี่คือเงินที่นักหิ้วมือใหม่ทิ้งไปฟรีๆ บ่อยที่สุด '
        'ของราคา 35,000 เยน คิดเป็นเงินที่หายไปประมาณ 2,700 บาท\n\n'
        'ข้อควรระวัง: ของกินของใช้สิ้นเปลืองจะถูกซีลถุงพลาสติก '
        'ห้ามแกะก่อนออกนอกประเทศ ไม่งั้นโดนเรียกเก็บภาษีคืน',
  ),
  _GuideItem(
    emoji: '✈️',
    title: 'เลือกช่องทางนำเข้าให้ถูก',
    saving: 'ต่างกันได้หลักพันต่อออเดอร์',
    detail: 'ของติดตัวผู้โดยสารได้สิทธิยกเว้นถึง 20,000 บาท '
        'ขณะที่ของส่งไปรษณีย์ยกเว้นแค่ 1,500 บาท — ต่างกัน 13 เท่า\n\n'
        'ของมูลค่ากลางๆ อย่างเครื่องสำอาง 7,000–8,000 บาท '
        'ถ้าหิ้วติดตัวคือภาษีศูนย์ แต่ถ้าส่งไปรษณีย์จะโดนอากร 20% '
        'บวก VAT อีก รวมแล้วประมาณ 2,300 บาท\n\n'
        'เครื่องคำนวณในแอปเทียบสองทางนี้ให้อัตโนมัติทุกครั้ง',
  ),
  _GuideItem(
    emoji: '📱',
    title: 'รู้ว่าของหมวดไหนอากร 0%',
    saving: 'ประหยัดอากร 20–30%',
    detail: 'สินค้าไอทีส่วนใหญ่ — โทรศัพท์ คอมพิวเตอร์ หูฟัง '
        '— มีอัตราอากรขาเข้า 0% ตามความตกลง ITA '
        'เหลือแค่ VAT 7% เท่านั้น\n\n'
        'ต่างจากเสื้อผ้าที่อากรราว 30% หรือเครื่องสำอางราว 20% '
        'ถ้าเลือกได้ว่าจะรับงานหมวดไหน หมวดไอทีมีภาระภาษีต่ำที่สุด\n\n'
        'ข้อควรระวัง: อุปกรณ์สื่อสารบางรุ่นต้องขึ้นทะเบียน กสทช. '
        'ก่อนนำเข้าเชิงพาณิชย์',
  ),
  _GuideItem(
    emoji: '📜',
    title: 'ใช้สิทธิ FTA ถ้าของผลิตในประเทศที่มีความตกลง',
    saving: 'อากรอาจเหลือ 0%',
    detail: 'ไทยมีความตกลงการค้าเสรีกับญี่ปุ่น (JTEPA) เกาหลี (AKFTA) '
        'จีน (ACFTA) และอาเซียน (ATIGA)\n\n'
        'ถ้าสินค้าผลิตในประเทศเหล่านั้นจริง และมีใบรับรองถิ่นกำเนิดสินค้า '
        '(Form JTEPA / Form AK / Form E) อากรขาเข้าอาจลดเหลือ 0%\n\n'
        'ใช้ได้จริงกับงานล็อตใหญ่ที่ซื้อจากผู้ผลิตโดยตรง '
        'ของซื้อปลีกหน้าร้านมักไม่มีเอกสารนี้ให้',
  ),
  _GuideItem(
    emoji: '🧷',
    title: 'พกใบเสร็จตัวจริงเสมอ',
    saving: 'กันโดนตีราคาสูงกว่าจริง',
    detail: 'ถ้าสำแดงราคาโดยไม่มีหลักฐาน ศุลกากรมีอำนาจตีราคาเอง '
        'ตามฐานข้อมูลราคาที่เขามี ซึ่งมักสูงกว่าราคาที่ซื้อจริง '
        'โดยเฉพาะของแบรนด์เนมที่ซื้อตอนลดราคา\n\n'
        'ใบเสร็จตัวจริงคือหลักฐานที่ทำให้คุณเสียภาษีตามราคาที่จ่ายจริง '
        'ไม่ใช่ตามราคาที่เขาเดา\n\n'
        'ในแอปนี้ระบบบังคับถ่ายใบเสร็จอยู่แล้ว '
        'ให้เก็บตัวจริงติดกระเป๋าถือไว้ด้วย',
  ),
  _GuideItem(
    emoji: '🚦',
    title: 'เดินช่องแดงเมื่อของเกินสิทธิ',
    saving: 'ประหยัดค่าปรับ 4 เท่า',
    detail: 'ถ้ารู้ว่าของเกินสิทธิ 20,000 บาท ให้เดินช่องแดง '
        'แล้วสำแดงเอง จะเสียแค่อากรกับ VAT ตามจริง\n\n'
        'ถ้าเดินช่องเขียวแล้วโดนสุ่มตรวจเจอ '
        'จะกลายเป็นการหลีกเลี่ยงภาษี โทษปรับสูงถึง 4 เท่าของอากร '
        'บวกยึดของ\n\n'
        'คำนวณแล้วเดินช่องแดงคุ้มกว่าเสมอ',
  ),
  _GuideItem(
    emoji: '🚬',
    title: 'รู้โควตาปลอดอากรของตัวเอง',
    detail: 'นอกจากสิทธิ 20,000 บาทแล้ว ผู้โดยสารยังมีโควตาเฉพาะ '
        'บุหรี่ไม่เกิน 200 มวน และสุราไม่เกิน 1 ลิตร\n\n'
        'เกินจากนี้คือของต้องสำแดง และบุหรี่เกินโควตามีโทษหนักเป็นพิเศษ '
        'ไม่คุ้มที่จะรับหิ้วเลย',
  ),
];

const _illegalActs = <_GuideItem>[
  _GuideItem(
    emoji: '🚫',
    title: 'สำแดงราคาต่ำกว่าที่ซื้อจริง',
    detail: 'การบอกราคาต่ำกว่าความจริงเพื่อให้เสียภาษีน้อยลง '
        'คือการหลีกเลี่ยงอากร ไม่ใช่การวางแผนภาษี\n\n'
        'ศุลกากรมีฐานข้อมูลราคาสินค้าแบรนด์ดังอยู่แล้ว '
        'และตรวจสอบย้อนกลับกับใบเสร็จหรือประวัติการซื้อได้',
    penalty: 'ปรับสูงสุด 4 เท่าของอากรที่ขาด บวกยึดของ '
        'และมีโทษทางอาญาตาม พ.ร.บ.ศุลกากร',
  ),
  _GuideItem(
    emoji: '🚫',
    title: 'ทำใบเสร็จปลอมหรือแก้ไขใบเสร็จ',
    detail: 'รวมถึงการขอให้ร้านออกใบเสร็จราคาต่ำกว่าจริง '
        'หรือแก้ตัวเลขในใบเสร็จ',
    penalty: 'เป็นการปลอมเอกสารและสำแดงเท็จ '
        'มีโทษทั้งทางศุลกากรและอาญาแยกจากกัน',
  ),
  _GuideItem(
    emoji: '🚫',
    title: 'แกะกล่อง ลอกป้าย เพื่ออำพรางว่าเป็นของใช้แล้ว',
    detail: 'การทำให้ของใหม่ดูเหมือนของใช้ส่วนตัวที่ใช้แล้ว '
        'เพื่อให้ผ่านช่องเขียว คือการอำพรางของต้องสำแดง\n\n'
        'ข้อนี้คนแนะนำกันเยอะในกลุ่มหิ้วของ แต่มันผิดกฎหมายชัดเจน',
    penalty: 'ถือเป็นการหลีกเลี่ยงอากรเช่นเดียวกับการสำแดงเท็จ',
  ),
  _GuideItem(
    emoji: '🚫',
    title: 'แบ่งพัสดุย่อยให้แต่ละชิ้นต่ำกว่า 1,500 บาท',
    detail: 'การจงใจซอยคำสั่งซื้อเดียวออกเป็นหลายพัสดุ '
        'เพื่อให้แต่ละชิ้นอยู่ใต้เกณฑ์ยกเว้น เรียกว่า splitting\n\n'
        'ศุลกากรรวมพัสดุที่ผู้ส่งและผู้รับเดียวกันในช่วงเวลาใกล้กัน '
        'เข้าด้วยกันเพื่อประเมินภาษีได้',
    penalty: 'ถูกประเมินภาษีย้อนหลังจากมูลค่ารวม พร้อมเบี้ยปรับ',
  ),
  _GuideItem(
    emoji: '🚫',
    title: 'ให้คนอื่นถือของแทนเพื่อยืมสิทธิ 20,000 ของเขา',
    detail: 'สิทธิยกเว้นเป็นสิทธิเฉพาะตัวสำหรับ "ของใช้ส่วนตัวของผู้โดยสารคนนั้น" '
        'การให้เพื่อนร่วมทริปถือของที่ไม่ใช่ของเขา '
        'เพื่อกระจายมูลค่าให้แต่ละคนไม่เกินสิทธิ ไม่ใช่การใช้สิทธิโดยชอบ',
    penalty: 'ทั้งคนถือและคนวางแผนมีความผิด '
        'คนที่ถือของตอนโดนตรวจคือคนที่รับโทษก่อน',
  ),
];

const _greyZone = <_GuideItem>[
  _GuideItem(
    emoji: '⚠️',
    title: 'ของที่รับจ้างหิ้ว ในทางเทคนิคไม่ใช่ "ของใช้ส่วนตัว"',
    detail: 'สิทธิยกเว้น 20,000 บาท เขียนไว้สำหรับ '
        '"ของใช้ส่วนตัวของผู้โดยสาร ในปริมาณสมควรแก่ฐานะ"\n\n'
        'ของที่หิ้วมาให้คนอื่นโดยได้ค่าจ้าง '
        'ศุลกากรตีความเป็นของเชิงพาณิชย์ได้ '
        'ซึ่งจะไม่เข้าเงื่อนไขยกเว้นตั้งแต่แรก\n\n'
        'ในทางปฏิบัติของจำนวนไม่มากมักผ่านไปได้ '
        'แต่นักหิ้วควรรู้ว่านี่คือความเสี่ยงที่มีอยู่จริง '
        'ไม่ใช่สิทธิที่การันตี',
  ),
  _GuideItem(
    emoji: '⚠️',
    title: '"ปริมาณสมควร" คือเกณฑ์ที่ตัดสินหน้างาน',
    detail: 'ลิปสติก 2 แท่งคือของใช้ส่วนตัว '
        'ลิปสติก 40 แท่งสีเดียวกันไม่ใช่แน่นอน '
        'แม้มูลค่ารวมจะไม่ถึง 20,000 บาทก็ตาม\n\n'
        'ของชนิดเดียวกันจำนวนมากคือสัญญาณของการค้า '
        'และเป็นเหตุผลอันดับหนึ่งที่ทำให้โดนเรียกตรวจ\n\n'
        'เวลารับงาน ให้ดูจำนวนชิ้นด้วย ไม่ใช่ดูแค่มูลค่า',
  ),
  _GuideItem(
    emoji: '⚠️',
    title: 'คนที่รับผิดคือคนที่ถือของ',
    detail: 'ถ้าโดนจับที่ด่าน ผู้ถือของคือผู้ต้องรับผิดชอบ '
        'ไม่ใช่คนที่ฝากหิ้ว และไม่ใช่แพลตฟอร์ม\n\n'
        'ก่อนรับงานควรถามให้ชัดว่าของคืออะไร '
        'และปฏิเสธงานที่รู้สึกไม่ชอบมาพากล\n\n'
        'ห้ามรับหิ้วของที่ไม่ได้เห็นด้วยตาตัวเองโดยเด็ดขาด',
  ),
  _GuideItem(
    emoji: '⚠️',
    title: 'อาหารเสริมและยาคือหมวดที่เสี่ยงที่สุด',
    detail: 'ไม่ใช่เรื่องภาษี แต่เป็นเรื่องใบอนุญาต '
        'อาหารเสริมและยานำเข้าต้องผ่าน อย. '
        'ถ้าไม่มีใบอนุญาตจะถูกยึดแม้คุณยินดีจ่ายภาษีเต็มจำนวน\n\n'
        'ของบางอย่างที่ขายทั่วไปในญี่ปุ่นจัดเป็นยาควบคุมในไทย\n\n'
        'ค่าหิ้วไม่กี่ร้อยบาทไม่คุ้มกับความเสี่ยงตรงนี้เลย',
  ),
];

const _checklistItems = <String>[
  'ขอคืนภาษีต้นทางครบทุกใบเสร็จแล้ว',
  'ใบเสร็จตัวจริงอยู่ในกระเป๋าถือ ไม่ได้โหลดใต้เครื่อง',
  'ถ่ายรูปสินค้าและใบเสร็จเข้าแอปครบทุกออเดอร์แล้ว',
  'รวมมูลค่าของทุกออเดอร์ในทริปนี้แล้ว รู้ว่าเกิน 20,000 บาทหรือยัง',
  'ถ้าเกินสิทธิ เตรียมเดินช่องแดงและมีเงินสำรองจ่ายภาษีแล้ว',
  'ไม่มีของหมวดต้องขออนุญาต (อาหารเสริม ยา เครื่องสำอางล็อตใหญ่)',
  'ไม่มีของชนิดเดียวกันจำนวนมากผิดปกติ',
  'ถุงซีล tax-free ยังไม่ถูกแกะ',
];
