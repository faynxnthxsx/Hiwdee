/// ผู้ให้บริการล็อกอินภายนอก
///
/// เลือกสองเจ้านี้เพราะครอบคนไทยเกือบทั้งหมด และไม่มีค่าใช้จ่ายต่อครั้ง
/// ต่างจาก OTP ทาง SMS ที่จ่ายทุกข้อความ
enum SocialProvider {
  google('Google', 'ต่อได้ทันที ไม่มีค่าใช้จ่าย'),
  facebook('Facebook', 'ต้องผ่าน App Review ของ Meta ก่อนเปิดให้คนทั่วไปใช้');

  const SocialProvider(this.text, this.note);

  final String text;
  final String note;
}

/// เหตุผลที่ล็อกอินไม่สำเร็จ แยกเป็นชนิดเพื่อให้ UI บอกทางแก้ได้ตรงจุด
///
/// ถ้าโยน Exception ก้อนเดียวแล้วเอา `e.toString()` ไปโชว์
/// ผู้ใช้จะเจอข้อความภาษาอังกฤษของ Supabase ซึ่งไม่ได้บอกว่าต้องทำอะไรต่อ
enum AuthFailureKind {
  /// ยังไม่ได้ตั้งค่าผู้ให้บริการนั้นใน Supabase
  providerNotConfigured,

  /// ยังไม่ได้ผูก SMS provider จึงส่ง OTP ไม่ได้
  smsNotConfigured,

  /// รหัส OTP ผิดหรือหมดอายุ
  badOtp,

  /// ผู้ใช้กดยกเลิกกลางทาง
  cancelled,

  /// เน็ตมีปัญหาหรือ Supabase ตอบกลับผิดพลาด
  network,

  other,
}
