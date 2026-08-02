/// ชนิดของข้อความในห้องแชท
enum MessageKind {
  /// ข้อความที่คนพิมพ์
  text,

  /// รูปที่แนบมา เช่น สลิป รูปสินค้า
  image,

  /// ระบบแทรกเอง เช่น "ออเดอร์เปลี่ยนเป็นกำลังนำส่ง"
  ///
  /// มีเพื่อให้ประวัติการคุยกับความเคลื่อนไหวของออเดอร์อยู่ในเส้นเดียวกัน
  /// เวลาเกิดข้อพิพาทจะได้อ่านย้อนได้ว่าเกิดอะไรก่อนหลัง
  system,
}

/// ข้อความหนึ่งบรรทัดในห้องแชทของออเดอร์
class Message {
  const Message({
    required this.id,
    required this.orderId,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    this.kind = MessageKind.text,
    this.text = '',
    this.imageUrl,
  });

  final String id;

  /// ห้องแชทผูกกับออเดอร์ ไม่ใช่ผูกกับคู่สนทนา
  ///
  /// ตั้งใจแบบนี้เพราะคนคู่เดิมอาจทำหลายออเดอร์พร้อมกัน
  /// ถ้ารวมห้องจะแยกไม่ออกว่าพูดถึงของชิ้นไหน และตอนเปิดเคสจะอ้างอิงลำบาก
  final String orderId;

  final String senderId;
  final String senderName;
  final DateTime sentAt;

  final MessageKind kind;
  final String text;
  final String? imageUrl;

  bool get isSystem => kind == MessageKind.system;
  bool get hasImage => kind == MessageKind.image && imageUrl != null;

  /// ข้อความที่เอาไปโชว์ในรายการห้องแชทหรือการแจ้งเตือน
  String get preview => switch (kind) {
        MessageKind.image => '📷 รูปภาพ',
        _ => text,
      };

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'sender_id': senderId,
        'sender_name': senderName,
        'sent_at': sentAt.toIso8601String(),
        'kind': kind.name,
        'text': text,
        'image_url': imageUrl,
      };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        orderId: json['order_id'] as String,
        senderId: json['sender_id'] as String,
        senderName: json['sender_name'] as String? ?? '',
        sentAt: DateTime.parse(json['sent_at'] as String),
        kind: MessageKind.values.byName(
          json['kind'] as String? ?? MessageKind.text.name,
        ),
        text: json['text'] as String? ?? '',
        imageUrl: json['image_url'] as String?,
      );
}
