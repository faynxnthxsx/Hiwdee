import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/core/utils/formatters.dart';

void main() {
  group('Fmt.number', () {
    test('ใส่ลูกน้ำคั่นหลักพัน', () {
      expect(Fmt.number(0), '0');
      expect(Fmt.number(999), '999');
      expect(Fmt.number(1000), '1,000');
      expect(Fmt.number(1234567), '1,234,567');
    });

    test('รองรับค่าติดลบ', () {
      expect(Fmt.number(-1500), '-1,500');
    });

    test('ปัดเศษทศนิยม', () {
      expect(Fmt.number(1499.6), '1,500');
    });
  });

  test('Fmt.baht เติมสัญลักษณ์บาท', () {
    expect(Fmt.baht(8500), '฿8,500');
  });

  group('Fmt.thaiDate', () {
    test('แปลงเป็น พ.ศ. สองหลัก', () {
      expect(Fmt.thaiDate(DateTime(2026, 8, 15)), '15 ส.ค. 69');
    });

    test('เดือนมกราคมใช้ตัวย่อถูกต้อง', () {
      expect(Fmt.thaiDate(DateTime(2027, 1, 1)), '1 ม.ค. 70');
    });
  });

  group('Fmt.phone', () {
    test('จัดรูปแบบเบอร์ 10 หลัก', () {
      expect(Fmt.phone('0812345678'), '081-234-5678');
    });

    test('คืนค่าเดิมเมื่อความยาวไม่ถูกต้อง', () {
      expect(Fmt.phone('12345'), '12345');
    });

    test('ซ่อนเลขท้ายตอนโชว์ในที่สาธารณะ', () {
      expect(Fmt.maskedPhone('0812345678'), '081-234-**78');
    });
  });

  group('Fmt.ago', () {
    test('เพิ่งเกิดขึ้นเมื่อกี้', () {
      final justNow = DateTime.now().subtract(const Duration(seconds: 20));
      expect(Fmt.ago(justNow), 'เมื่อสักครู่');
    });

    test('นับเป็นนาที ชั่วโมง แล้วก็วัน', () {
      final now = DateTime.now();
      expect(Fmt.ago(now.subtract(const Duration(minutes: 14))),
          '14 นาทีที่แล้ว');
      expect(Fmt.ago(now.subtract(const Duration(hours: 6))), '6 ชม.ที่แล้ว');
      expect(Fmt.ago(now.subtract(const Duration(days: 2))), '2 วันที่แล้ว');
    });

    test('เกิน 7 วันเลิกนับ กลับไปโชว์วันที่จริง', () {
      final old = DateTime(2026, 1, 5);
      expect(Fmt.ago(old), Fmt.thaiDate(old));
    });

    test('เวลาในอนาคตไม่แสดงเลขติดลบ', () {
      final future = DateTime.now().add(const Duration(hours: 3));
      expect(Fmt.ago(future), 'เมื่อสักครู่');
    });
  });

  group('Fmt.remaining', () {
    test('บอกจำนวนวันที่เหลือ', () {
      final deadline = DateTime.now().add(const Duration(days: 3, hours: 1));
      expect(Fmt.remaining(deadline), 'เหลือ 3 วัน');
    });

    test('บอกว่าหมดเวลาเมื่อเลยกำหนด', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(Fmt.remaining(past), 'หมดเวลาแล้ว');
    });
  });
}
