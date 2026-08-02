import '../domain/message.dart';

/// สัญญาของชั้นแชท
///
/// [watch] คืน stream เพราะแชทต้องเด้งเองเมื่ออีกฝ่ายพิมพ์
/// ตัวในหน่วยความจำจำลองด้วย broadcast stream ส่วนของจริงใช้ Realtime
/// ของ Supabase — UI เรียกผ่านหน้านี้อย่างเดียวจึงไม่ต้องแก้ตอนสลับ
abstract interface class ChatRepository {
  Stream<List<Message>> watch(String orderId);

  Future<List<Message>> history(String orderId);

  Future<void> send(Message message);

  /// ระบบแทรกเองตอนออเดอร์เปลี่ยนสถานะ
  Future<void> postSystemNote(String orderId, String text);
}
