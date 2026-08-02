/// ประเภทการแจ้งเตือน — ฝั่ง presentation เอาไปแมปเป็นไอคอนกับสี
/// เก็บเป็น enum ไม่ใช่ string อิสระ เพื่อให้เพิ่มชนิดใหม่แล้ว switch ฟ้องทันที
enum NotificationKind {
  bid('ข้อเสนอรับหิ้ว'),
  order('ความคืบหน้าออเดอร์'),
  payout('เงินเข้ากระเป๋า'),
  chat('ข้อความใหม่'),
  system('ประกาศจากระบบ');

  const NotificationKind(this.text);
  final String text;
}

/// การแจ้งเตือน 1 รายการ
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.requestId,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// ถ้ามีค่า แปลว่ากดแล้วเปิดหน้ารายละเอียดคำขอนั้นได้เลย
  final String? requestId;

  bool get isActionable => requestId != null;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        requestId: requestId,
      );
}
