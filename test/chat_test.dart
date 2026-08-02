import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/chat/data/memory_chat_repository.dart';
import 'package:hiewdee/features/chat/domain/message.dart';

Message msg(
  String id, {
  String orderId = 'o1',
  String senderId = 'u1',
  MessageKind kind = MessageKind.text,
  String text = 'สวัสดีครับ',
  String? imageUrl,
}) =>
    Message(
      id: id,
      orderId: orderId,
      senderId: senderId,
      senderName: 'ฝ้าย',
      sentAt: DateTime(2026, 8, 2, 10),
      kind: kind,
      text: text,
      imageUrl: imageUrl,
    );

void main() {
  group('Message', () {
    test('แปลงเป็น json แล้วกลับมาได้ครบ', () {
      final original = msg(
        'm1',
        kind: MessageKind.image,
        text: '',
        imageUrl: 'https://example.com/a.jpg',
      );

      final round = Message.fromJson(original.toJson());

      expect(round.id, original.id);
      expect(round.orderId, original.orderId);
      expect(round.kind, MessageKind.image);
      expect(round.imageUrl, original.imageUrl);
      expect(round.sentAt, original.sentAt);
    });

    test('ข้อความรูปโชว์ preview เป็นไอคอน ไม่ใช่ค่าว่าง', () {
      final image = msg('m1', kind: MessageKind.image, text: '');

      expect(image.preview, isNotEmpty);
      expect(msg('m2', text: 'ทักครับ').preview, 'ทักครับ');
    });

    test('รูปที่ไม่มี url ไม่ถือว่ามีรูป', () {
      expect(msg('m1', kind: MessageKind.image).hasImage, isFalse);
      expect(
        msg('m2', kind: MessageKind.image, imageUrl: 'x').hasImage,
        isTrue,
      );
    });

    test('ข้อความระบบถูกแยกออกจากข้อความคน', () {
      expect(msg('m1', kind: MessageKind.system).isSystem, isTrue);
      expect(msg('m2').isSystem, isFalse);
    });

    test('json ที่ไม่มีฟิลด์ไม่บังคับ ยังอ่านได้', () {
      final json = {
        'id': 'm1',
        'order_id': 'o1',
        'sender_id': 'u1',
        'sent_at': DateTime(2026, 8, 2).toIso8601String(),
      };

      final m = Message.fromJson(json);

      expect(m.kind, MessageKind.text);
      expect(m.text, '');
      expect(m.senderName, '');
    });
  });

  group('MemoryChatRepository', () {
    late MemoryChatRepository repo;

    setUp(() => repo = MemoryChatRepository());
    tearDown(() => repo.dispose());

    test('ห้องแยกตามออเดอร์ ไม่ปนกัน', () async {
      await repo.send(msg('m1', orderId: 'oA', text: 'ของ A'));
      await repo.send(msg('m2', orderId: 'oB', text: 'ของ B'));

      final a = await repo.history('oA');
      final b = await repo.history('oB');

      expect(a.single.text, 'ของ A');
      expect(b.single.text, 'ของ B');
    });

    test('ส่งแล้ว stream ยิงค่าใหม่ออกมา', () async {
      final seen = <List<Message>>[];
      final sub = repo.watch('oNew').listen(seen.add);

      await repo.send(msg('m1', orderId: 'oNew', text: 'ทัก'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, isNotEmpty);
      expect(seen.last.single.text, 'ทัก');

      await sub.cancel();
    });

    test('subscribe แล้วได้ค่าปัจจุบันทันที ไม่ต้องรอคนพิมพ์', () async {
      final first = await repo.watch('o1').first;

      expect(first, isNotEmpty, reason: 'o1 มีบทสนทนาตัวอย่างอยู่');
    });

    test('บันทึกของระบบถูกติดธงว่าเป็น system', () async {
      await repo.postSystemNote('oX', 'ออเดอร์เปลี่ยนสถานะ');

      final history = await repo.history('oX');

      expect(history.single.isSystem, isTrue);
      expect(history.single.senderId, 'system');
    });

    test('ประวัติที่คืนมาเป็นสำเนา แก้แล้วไม่กระทบของจริง', () async {
      await repo.send(msg('m1', orderId: 'oY'));

      final copy = await repo.history('oY');
      copy.clear();

      expect((await repo.history('oY')).length, 1);
    });

    test('ห้องที่ไม่เคยมีข้อความคืนลิสต์ว่าง ไม่ throw', () async {
      expect(await repo.history('ไม่มีอยู่จริง'), isEmpty);
    });
  });
}
