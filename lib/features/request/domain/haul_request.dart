/// ของมาจากไหน — ตัวแยกหลักของแอปนี้
enum OriginType {
  abroad('ต่างประเทศ'),
  domestic('ในประเทศ');

  const OriginType(this.text);
  final String text;
}

enum HaulCategory {
  beauty('บิวตี้ / สกินแคร์', '💄'),
  fashion('แฟชั่น / กระเป๋า', '👜'),
  gadget('แกดเจ็ต / อิเล็กทรอนิกส์', '📱'),
  collectible('ของสะสม / ฟิกเกอร์', '🧸'),
  snack('ขนม / อาหารแห้ง', '🍫'),
  supplement('อาหารเสริม / ยา', '💊'),
  local('ของฝากท้องถิ่น', '🎁'),
  other('อื่นๆ', '📦');

  const HaulCategory(this.text, this.emoji);
  final String text;
  final String emoji;
}

enum RequestStatus {
  open('กำลังหานักหิ้ว'),
  matched('ได้นักหิ้วแล้ว'),
  closed('ปิดรับแล้ว');

  const RequestStatus(this.text);
  final String text;
}

/// คำขอฝากหิ้ว 1 รายการ
class HaulRequest {
  const HaulRequest({
    required this.id,
    required this.title,
    required this.category,
    required this.originType,
    required this.originName,
    required this.quantity,
    required this.budgetMax,
    required this.serviceFeeOffer,
    required this.deadline,
    required this.requesterName,
    required this.createdAt,
    this.productUrl,
    this.note = '',
    this.bidCount = 0,
    this.status = RequestStatus.open,
  });

  final String id;
  final String title;
  final HaulCategory category;
  final OriginType originType;

  /// ชื่อสถานที่ต้นทาง เช่น "ญี่ปุ่น · โตเกียว" หรือ "เชียงใหม่"
  final String originName;

  final int quantity;

  /// งบค่าสินค้าสูงสุดที่ผู้ฝากรับได้
  final double budgetMax;

  /// ค่าจ้างหิ้วที่ผู้ฝากเสนอ
  final double serviceFeeOffer;

  final DateTime deadline;
  final String requesterName;
  final DateTime createdAt;

  final String? productUrl;
  final String note;
  final int bidCount;
  final RequestStatus status;

  double get totalOffer => budgetMax + serviceFeeOffer;
  bool get isUrgent => deadline.difference(DateTime.now()).inDays <= 3;
}
