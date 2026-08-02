/// ตัวช่วยจัดรูปแบบข้อความที่ใช้ซ้ำทั้งแอป
/// (ยังไม่พึ่ง intl เพื่อให้ scaffold รันได้เร็ว — เปลี่ยนไปใช้ intl ได้ภายหลัง)
abstract final class Fmt {
  /// 1250 -> "1,250"
  static String number(num value) {
    final whole = value.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
      buf.write(whole[i]);
    }
    return '${value < 0 ? '-' : ''}$buf';
  }

  /// 1250 -> "฿1,250"
  static String baht(num value) => '฿${number(value)}';

  static const _thMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  /// 2026-08-15 -> "15 ส.ค. 69"
  static String thaiDate(DateTime date) {
    final buddhistYear = (date.year + 543) % 100;
    return '${date.day} ${_thMonths[date.month - 1]} '
        '${buddhistYear.toString().padLeft(2, '0')}';
  }

  /// ช่วงวันของทริป -> "10 - 20 ส.ค. 69"
  static String dateRange(DateTime from, DateTime to) {
    if (from.month == to.month && from.year == to.year) {
      return '${from.day} - ${thaiDate(to)}';
    }
    return '${thaiDate(from)} - ${thaiDate(to)}';
  }

  /// นับถอยหลังถึงกำหนด -> "เหลือ 3 วัน"
  static String remaining(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return 'หมดเวลาแล้ว';
    if (diff.inDays > 0) return 'เหลือ ${diff.inDays} วัน';
    if (diff.inHours > 0) return 'เหลือ ${diff.inHours} ชม.';
    return 'เหลือ ${diff.inMinutes} นาที';
  }

  /// เวลาที่ผ่านมาแบบย่อ -> "3 ชม.ที่แล้ว"
  /// เกิน 7 วันแล้วเลิกนับ เพราะ "23 วันที่แล้ว" อ่านยากกว่าวันที่จริง
  static String ago(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.isNegative || diff.inMinutes < 1) return 'เมื่อสักครู่';
    if (diff.inHours < 1) return '${diff.inMinutes} นาทีที่แล้ว';
    if (diff.inDays < 1) return '${diff.inHours} ชม.ที่แล้ว';
    if (diff.inDays <= 7) return '${diff.inDays} วันที่แล้ว';
    return thaiDate(time);
  }

  /// 0812345678 -> "081-234-5678"
  static String phone(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length != 10) return raw;
    return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
  }

  /// ซ่อนเบอร์บางส่วนตอนโชว์ในที่สาธารณะ -> "081-234-**78"
  static String maskedPhone(String raw) {
    final formatted = phone(raw);
    if (formatted.length < 4) return formatted;
    return '${formatted.substring(0, formatted.length - 4)}**'
        '${formatted.substring(formatted.length - 2)}';
  }
}
