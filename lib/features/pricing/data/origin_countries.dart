/// สกุลเงินที่เลือกจ่ายได้
///
/// แยกออกจาก [OriginCountry] เพราะ "ประเทศที่ซื้อ" กับ "สกุลเงินที่จ่าย"
/// ไม่ได้ผูกกันเสมอไป — ร้านออนไลน์ญี่ปุ่นหลายเจ้าคิดเงินเป็น USD
/// และร้านในดูไบก็รับ USD ปนกับ AED
class Currency {
  const Currency({
    required this.code,
    required this.symbol,
    required this.nameTh,
  });

  final String code;
  final String symbol;
  final String nameTh;
}

abstract final class Currencies {
  static const jpy = Currency(code: 'JPY', symbol: '¥', nameTh: 'เยนญี่ปุ่น');
  static const krw = Currency(code: 'KRW', symbol: '₩', nameTh: 'วอนเกาหลี');
  static const cny = Currency(code: 'CNY', symbol: '¥', nameTh: 'หยวนจีน');
  static const twd = Currency(code: 'TWD', symbol: 'NT\$', nameTh: 'ดอลลาร์ไต้หวัน');
  static const sgd = Currency(code: 'SGD', symbol: 'S\$', nameTh: 'ดอลลาร์สิงคโปร์');
  static const hkd = Currency(code: 'HKD', symbol: 'HK\$', nameTh: 'ดอลลาร์ฮ่องกง');
  static const usd = Currency(code: 'USD', symbol: '\$', nameTh: 'ดอลลาร์สหรัฐ');
  static const eur = Currency(code: 'EUR', symbol: '€', nameTh: 'ยูโร');
  static const gbp = Currency(code: 'GBP', symbol: '£', nameTh: 'ปอนด์สเตอร์ลิง');
  static const aud = Currency(code: 'AUD', symbol: 'A\$', nameTh: 'ดอลลาร์ออสเตรเลีย');
  static const vnd = Currency(code: 'VND', symbol: '₫', nameTh: 'ดองเวียดนาม');
  static const myr = Currency(code: 'MYR', symbol: 'RM', nameTh: 'ริงกิตมาเลเซีย');
  static const aed = Currency(code: 'AED', symbol: 'AED', nameTh: 'ดีแรห์มยูเออี');
  static const thb = Currency(code: 'THB', symbol: '฿', nameTh: 'บาทไทย');

  static const all = <Currency>[
    jpy, krw, cny, twd, sgd, hkd,
    usd, eur, gbp, aud,
    vnd, myr, aed, thb,
  ];

  static Currency byCode(String code) =>
      all.firstWhere((c) => c.code == code, orElse: () => usd);
}

/// ประเทศต้นทางที่นิยมหิ้ว พร้อมข้อมูลที่ใช้ลดต้นทุนได้ *อย่างถูกกฎหมาย*
///
/// การขอคืนภาษีต้นทาง (tax-free / VAT refund) คือช่องประหยัดที่ถูกต้อง
/// ตามกฎหมายเต็มร้อย และเป็นเงินก้อนที่นักหิ้วมือใหม่มักลืมไปเฉยๆ
///
/// ลิสต์นี้ **แพลตฟอร์มคุมเอง** ไม่เปิดให้ผู้ใช้เพิ่ม เพราะ [localTaxRate]
/// กับ [minSpendForRefund] เป็นข้อมูลกฎหมายที่กรอกผิดแล้วคำนวณเพี้ยนเงียบๆ
/// ประเทศนอกลิสต์ให้ใช้ [OriginCountries.other] ซึ่งติดป้ายไว้ชัดว่าประมาณการ
class OriginCountry {
  const OriginCountry({
    required this.code,
    required this.nameTh,
    required this.currencyCode,
    required this.currencySymbol,
    required this.localTaxRate,
    required this.taxRefundAvailable,
    this.minSpendForRefund = 0,
    this.refundNote = '',
    this.ftaWithThailand,
    this.isCustom = false,
  });

  final String code;
  final String nameTh;
  final String currencyCode;
  final String currencySymbol;

  /// อัตราภาษีการบริโภคของประเทศนั้น (ญี่ปุ่น 10%, เกาหลี 10%)
  final double localTaxRate;

  /// ขอคืนได้ไหมสำหรับนักท่องเที่ยว
  final bool taxRefundAvailable;

  /// ยอดซื้อขั้นต่ำต่อใบเสร็จที่จะขอคืนได้ (สกุลท้องถิ่น)
  final double minSpendForRefund;

  final String refundNote;

  /// ชื่อความตกลงการค้าเสรีกับไทย — ถ้ามีใบรับรองถิ่นกำเนิดอาจลดอากรได้
  final String? ftaWithThailand;

  /// true = ผู้ใช้กรอกเอง ยังไม่ผ่านการตรวจสอบ ต้องติดป้ายเตือนใน UI
  final bool isCustom;

  /// อัตราที่ขอคืนได้จริง — ปกติได้ไม่เต็มเพราะโดนหักค่าดำเนินการ
  double get effectiveRefundRate =>
      taxRefundAvailable ? localTaxRate * 0.85 : 0;

  /// ใช้ตอนผู้ใช้เลือกจ่ายด้วยสกุลอื่นที่ไม่ใช่สกุลประจำประเทศ
  OriginCountry copyWith({
    String? currencyCode,
    String? currencySymbol,
    double? minSpendForRefund,
  }) {
    return OriginCountry(
      code: code,
      nameTh: nameTh,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      localTaxRate: localTaxRate,
      taxRefundAvailable: taxRefundAvailable,
      minSpendForRefund: minSpendForRefund ?? this.minSpendForRefund,
      refundNote: refundNote,
      ftaWithThailand: ftaWithThailand,
      isCustom: isCustom,
    );
  }
}

abstract final class OriginCountries {
  static const japan = OriginCountry(
    code: 'JP',
    nameTh: 'ญี่ปุ่น',
    currencyCode: 'JPY',
    currencySymbol: '¥',
    localTaxRate: 0.10,
    taxRefundAvailable: true,
    minSpendForRefund: 5000,
    refundNote: 'ซื้อที่ร้านติดป้าย Tax-Free ยอดรวม ¥5,000 ขึ้นไป '
        'ยื่นพาสปอร์ตตอนจ่ายเงิน ได้ยกเว้นภาษีทันทีที่เคาน์เตอร์ '
        'ของกินของใช้สิ้นเปลืองจะถูกซีลถุง ห้ามแกะก่อนออกนอกประเทศ',
    ftaWithThailand: 'JTEPA / AJCEP',
  );

  static const korea = OriginCountry(
    code: 'KR',
    nameTh: 'เกาหลีใต้',
    currencyCode: 'KRW',
    currencySymbol: '₩',
    localTaxRate: 0.10,
    taxRefundAvailable: true,
    minSpendForRefund: 15000,
    refundNote: 'ยอด ₩15,000 ขึ้นไปขอ Tax Refund ได้ '
        'ร้านใหญ่อย่าง Olive Young คืนทันทีหน้าร้าน '
        'ที่เหลือไปรับที่ตู้คีออสสนามบินก่อนเช็คอิน',
    ftaWithThailand: 'AKFTA',
  );

  static const china = OriginCountry(
    code: 'CN',
    nameTh: 'จีน',
    currencyCode: 'CNY',
    currencySymbol: '¥',
    localTaxRate: 0.13,
    taxRefundAvailable: true,
    minSpendForRefund: 500,
    refundNote: 'ขอคืนได้เฉพาะร้านที่ร่วมโครงการ ยอด ¥500 ขึ้นไปต่อวันต่อร้าน '
        'คืนจริงประมาณ 9–11% หลังหักค่าดำเนินการ',
    ftaWithThailand: 'ACFTA / RCEP',
  );

  static const taiwan = OriginCountry(
    code: 'TW',
    nameTh: 'ไต้หวัน',
    currencyCode: 'TWD',
    currencySymbol: 'NT\$',
    localTaxRate: 0.05,
    taxRefundAvailable: true,
    minSpendForRefund: 2000,
    refundNote: 'ยอด NT\$2,000 ขึ้นไปต่อวันต่อร้าน ขอคืนที่สนามบิน',
  );

  static const singapore = OriginCountry(
    code: 'SG',
    nameTh: 'สิงคโปร์',
    currencyCode: 'SGD',
    currencySymbol: 'S\$',
    localTaxRate: 0.09,
    taxRefundAvailable: true,
    minSpendForRefund: 100,
    refundNote: 'GST 9% ขอคืนผ่านระบบ eTRS ยอด S\$100 ขึ้นไป',
    ftaWithThailand: 'ATIGA (อาเซียน)',
  );

  static const hongkong = OriginCountry(
    code: 'HK',
    nameTh: 'ฮ่องกง',
    currencyCode: 'HKD',
    currencySymbol: 'HK\$',
    localTaxRate: 0.0,
    taxRefundAvailable: false,
    refundNote: 'ฮ่องกงไม่มี VAT อยู่แล้ว ราคาป้ายคือราคาสุทธิ '
        'จึงไม่มีอะไรต้องขอคืน',
  );

  static const usa = OriginCountry(
    code: 'US',
    nameTh: 'สหรัฐอเมริกา',
    currencyCode: 'USD',
    currencySymbol: '\$',
    localTaxRate: 0.07,
    taxRefundAvailable: false,
    refundNote: 'sales tax ต่างกันไปตามรัฐและปกติขอคืนไม่ได้ '
        'รัฐอย่าง Oregon, Delaware, New Hampshire ไม่มี sales tax เลย '
        'ถ้าเลือกซื้อได้ให้ซื้อรัฐพวกนี้',
  );

  static const europe = OriginCountry(
    code: 'EU',
    nameTh: 'ยุโรป',
    currencyCode: 'EUR',
    currencySymbol: '€',
    localTaxRate: 0.20,
    taxRefundAvailable: true,
    minSpendForRefund: 100,
    refundNote: 'VAT refund ประมาณ 12–15% หลังหักค่าดำเนินการ '
        'ต้องขอ tax-free form ที่ร้าน แล้วประทับตราศุลกากรก่อนออกจาก EU',
  );

  static const uk = OriginCountry(
    code: 'GB',
    nameTh: 'อังกฤษ',
    currencyCode: 'GBP',
    currencySymbol: '£',
    localTaxRate: 0.20,
    taxRefundAvailable: false,
    refundNote: 'อังกฤษยกเลิก VAT refund สำหรับนักท่องเที่ยวตั้งแต่ปี 2021 '
        'ราคาป้ายรวม VAT 20% แล้วขอคืนไม่ได้ '
        'ถ้าของชิ้นนั้นซื้อใน EU ได้ ให้ซื้อฝั่ง EU แทนจะถูกกว่า',
  );

  static const australia = OriginCountry(
    code: 'AU',
    nameTh: 'ออสเตรเลีย',
    currencyCode: 'AUD',
    currencySymbol: 'A\$',
    localTaxRate: 0.10,
    taxRefundAvailable: true,
    minSpendForRefund: 300,
    refundNote: 'ขอคืน GST ผ่านระบบ TRS ยอด A\$300 ขึ้นไปต่อร้าน '
        'ซื้อภายใน 60 วันก่อนบิน และต้องหิ้วของขึ้นเครื่องไปแสดงที่เคาน์เตอร์',
    ftaWithThailand: 'TAFTA',
  );

  static const vietnam = OriginCountry(
    code: 'VN',
    nameTh: 'เวียดนาม',
    currencyCode: 'VND',
    currencySymbol: '₫',
    localTaxRate: 0.10,
    taxRefundAvailable: true,
    minSpendForRefund: 2000000,
    refundNote: 'ยอด ₫2,000,000 ขึ้นไปต่อร้านต่อวัน ขอคืนที่สนามบิน '
        'คืนจริงประมาณ 8.5% หลังหักค่าดำเนินการ',
    ftaWithThailand: 'ATIGA (อาเซียน) / RCEP',
  );

  static const malaysia = OriginCountry(
    code: 'MY',
    nameTh: 'มาเลเซีย',
    currencyCode: 'MYR',
    currencySymbol: 'RM',
    localTaxRate: 0.10,
    taxRefundAvailable: false,
    refundNote: 'มาเลเซียเลิกใช้ GST ไปแล้ว ใช้ SST แทนซึ่งขอคืนไม่ได้ '
        'แต่มีเขตปลอดภาษีอย่างลังกาวีและลาบวนที่ราคาถูกกว่าปกติ',
    ftaWithThailand: 'ATIGA (อาเซียน) / RCEP',
  );

  static const uae = OriginCountry(
    code: 'AE',
    nameTh: 'สหรัฐอาหรับเอมิเรตส์',
    currencyCode: 'AED',
    currencySymbol: 'AED',
    localTaxRate: 0.05,
    taxRefundAvailable: true,
    minSpendForRefund: 250,
    refundNote: 'VAT 5% ขอคืนได้ยอด AED 250 ขึ้นไป '
        'ผ่านตู้ Planet Tax Free ที่สนามบิน',
  );

  static const thailand = OriginCountry(
    code: 'TH',
    nameTh: 'ไทย',
    currencyCode: 'THB',
    currencySymbol: '฿',
    localTaxRate: 0.07,
    taxRefundAvailable: false,
  );

  /// ตัวเลือกสำรองสำหรับประเทศนอกลิสต์
  ///
  /// อากรขาเข้ายังคำนวณได้ถูกต้อง เพราะผูกกับพิกัดศุลกากรของ *สินค้า*
  /// ไม่ใช่ประเทศ สิ่งที่หายไปคือข้อมูลคืนภาษีต้นทางกับสิทธิ FTA
  /// ผู้ใช้ต้องเลือกสกุลเงินและใส่เรทเองในหน้าคำนวณ
  static const other = OriginCountry(
    code: 'XX',
    nameTh: 'ประเทศอื่นๆ',
    currencyCode: 'USD',
    currencySymbol: '\$',
    localTaxRate: 0,
    taxRefundAvailable: false,
    isCustom: true,
    refundNote: 'ยังไม่มีข้อมูลคืนภาษีของประเทศนี้ในระบบ '
        'ถ้าประเทศนั้นคืน VAT ให้นักท่องเที่ยว จะประหยัดได้อีกโดยที่ยอดนี้ยังไม่รวมให้',
  );

  static const all = <OriginCountry>[
    japan,
    korea,
    china,
    taiwan,
    singapore,
    hongkong,
    vietnam,
    malaysia,
    usa,
    europe,
    uk,
    australia,
    uae,
    thailand,
    other,
  ];

  static OriginCountry byCode(String code) => all.firstWhere(
        (c) => c.code == code,
        orElse: () => thailand,
      );
}

/// อัตราแลกเปลี่ยนตัวอย่าง (บาทต่อ 1 หน่วยสกุลนั้น)
///
/// ของจริงต้องดึงจาก API ธนาคาร แล้ว cache ไว้ไม่เกิน 15 นาที
/// ค่าที่ใส่ไว้นี้เป็นค่าประมาณเพื่อให้ scaffold คำนวณได้ทันที
abstract final class FxRates {
  static const _table = <String, double>{
    'JPY': 0.23,
    'KRW': 0.026,
    'CNY': 4.90,
    'TWD': 1.10,
    'SGD': 26.50,
    'HKD': 4.55,
    'USD': 35.50,
    'EUR': 38.50,
    'GBP': 45.00,
    'AUD': 23.00,
    'VND': 0.0014,
    'MYR': 8.10,
    'AED': 9.67,
    'THB': 1.0,
  };

  /// ส่วนต่างที่บวกกันเรทแกว่งระหว่างวันที่รับงานกับวันที่ซื้อจริง
  static const defaultSpread = 0.02;

  static double thbPer(String currencyCode) => _table[currencyCode] ?? 1.0;

  /// รู้จักสกุลนี้ไหม — ถ้าไม่รู้จักต้องให้ผู้ใช้กรอกเรทเอง
  static bool knows(String currencyCode) => _table.containsKey(currencyCode);
}
