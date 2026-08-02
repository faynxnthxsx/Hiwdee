import 'dart:async';

import '../domain/message.dart';
import 'chat_repository.dart';

/// แชทในหน่วยความจำ ใช้ตอนยังไม่ได้ต่อ Supabase
///
/// ยังคืน stream เหมือนของจริง เพื่อให้ UI เขียนแบบเดียวกันทั้งสองโหมด
/// ถ้าตัวจำลองคืน List เฉยๆ พอสลับไปของจริงจะต้องรื้อหน้าจอใหม่ทั้งหมด
class MemoryChatRepository implements ChatRepository {
  MemoryChatRepository() {
    _seed();
  }

  final _byOrder = <String, List<Message>>{};
  final _controllers = <String, StreamController<List<Message>>>{};

  StreamController<List<Message>> _controllerFor(String orderId) =>
      _controllers.putIfAbsent(
        orderId,
        () => StreamController<List<Message>>.broadcast(),
      );

  List<Message> _listFor(String orderId) =>
      _byOrder.putIfAbsent(orderId, () => []);

  @override
  Stream<List<Message>> watch(String orderId) {
    final controller = _controllerFor(orderId);
    // ยิงค่าปัจจุบันให้ทันทีที่ subscribe ไม่งั้นหน้าจอจะว่างจนกว่าจะมีคนพิมพ์
    scheduleMicrotask(() {
      if (!controller.isClosed) controller.add(List.of(_listFor(orderId)));
    });
    return controller.stream;
  }

  @override
  Future<List<Message>> history(String orderId) async =>
      List.of(_listFor(orderId));

  @override
  Future<void> send(Message message) async {
    _listFor(message.orderId).add(message);
    _controllerFor(message.orderId).add(List.of(_listFor(message.orderId)));
  }

  @override
  Future<void> postSystemNote(String orderId, String text) => send(
        Message(
          id: 'm${DateTime.now().microsecondsSinceEpoch}',
          orderId: orderId,
          senderId: 'system',
          senderName: 'ระบบ',
          sentAt: DateTime.now(),
          kind: MessageKind.system,
          text: text,
        ),
      );

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
  }

  /// บทสนทนาตัวอย่างของออเดอร์ที่ seed ไว้ ให้เปิดมาแล้วมีอะไรให้ดู
  void _seed() {
    final now = DateTime.now();
    DateTime agoMin(int m) => now.subtract(Duration(minutes: m));
    DateTime agoHours(int h) => now.subtract(Duration(hours: h));

    _byOrder['o1'] = [
      Message(
        id: 'm1',
        orderId: 'o1',
        senderId: 'system',
        senderName: 'ระบบ',
        sentAt: agoHours(72),
        kind: MessageKind.system,
        text: 'ผู้ฝากชำระเงินเข้าระบบแล้ว เงินถูกถือไว้จนกว่าจะกดรับของ',
      ),
      Message(
        id: 'm2',
        orderId: 'o1',
        senderId: 'u_carrier',
        senderName: 'ก้อง',
        sentAt: agoHours(70),
        text: 'สั่งจาก Yodobashi แล้วนะครับ ได้ใบเสร็จเต็มรูปแบบมาด้วย '
            'เผื่อเคลมประกันในไทย',
      ),
      Message(
        id: 'm3',
        orderId: 'o1',
        senderId: 'u_requester',
        senderName: 'ปอนด์',
        sentAt: agoHours(69),
        text: 'ขอบคุณมากครับ สีดำใช่ไหมครับ',
      ),
      Message(
        id: 'm4',
        orderId: 'o1',
        senderId: 'u_carrier',
        senderName: 'ก้อง',
        sentAt: agoHours(68),
        text: 'ใช่ครับ สีดำ ตามที่ระบุเลย',
      ),
      Message(
        id: 'm5',
        orderId: 'o1',
        senderId: 'system',
        senderName: 'ระบบ',
        sentAt: agoHours(20),
        kind: MessageKind.system,
        text: 'ส่งเข้าระบบขนส่งแล้ว · Kerry TH8891042271',
      ),
    ];

    _byOrder['o2'] = [
      Message(
        id: 'm6',
        orderId: 'o2',
        senderId: 'system',
        senderName: 'ระบบ',
        sentAt: agoHours(5),
        kind: MessageKind.system,
        text: 'โอนเงินสำรอง ฿945 เข้ากระเป๋านักหิ้วแล้ว '
            'ต้องอัปสลิปและรูปสินค้าภายใน 48 ชม.',
      ),
      Message(
        id: 'm7',
        orderId: 'o2',
        senderId: 'u_requester',
        senderName: 'ต้น',
        sentAt: agoMin(40),
        text: 'ฝากขอแบบสุญญากาศด้วยนะครับ จะได้ส่งไปรษณีย์ได้',
      ),
    ];
  }
}
