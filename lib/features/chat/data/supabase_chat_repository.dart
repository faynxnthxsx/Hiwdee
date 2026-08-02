import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/message.dart';
import 'chat_repository.dart';

/// แชทของจริงบน Supabase Realtime
///
/// `.stream()` เปิด websocket ให้เอง แล้วยิงลิสต์ใหม่ทุกครั้งที่ตารางเปลี่ยน
/// จึงไม่ต้องเขียน polling เอง และไม่ต้อง refresh หน้าจอ
///
/// ต้องเปิด Realtime ให้ตาราง `messages` ใน Supabase ก่อน — คำสั่งอยู่ท้าย
/// `supabase/migrations/0001_init.sql`
class SupabaseChatRepository implements ChatRepository {
  const SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'messages';

  @override
  Stream<List<Message>> watch(String orderId) {
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('order_id', orderId)
        .order('sent_at')
        .map((rows) => rows.map(Message.fromJson).toList());
  }

  @override
  Future<List<Message>> history(String orderId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('order_id', orderId)
        .order('sent_at');

    return rows.map(Message.fromJson).toList();
  }

  @override
  Future<void> send(Message message) async {
    // ไม่ส่ง id ไป ให้ฐานข้อมูลสร้างเอง กัน id ชนกันเวลาสองเครื่องพิมพ์พร้อมกัน
    final json = message.toJson()..remove('id');
    await _client.from(_table).insert(json);
  }

  @override
  Future<void> postSystemNote(String orderId, String text) async {
    await _client.from(_table).insert({
      'order_id': orderId,
      'sender_id': 'system',
      'sender_name': 'ระบบ',
      'sent_at': DateTime.now().toIso8601String(),
      'kind': MessageKind.system.name,
      'text': text,
    });
  }
}
