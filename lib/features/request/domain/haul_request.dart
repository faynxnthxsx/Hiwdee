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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'originType': originType.name,
        'originName': originName,
        'quantity': quantity,
        'budgetMax': budgetMax,
        'serviceFeeOffer': serviceFeeOffer,
        'deadline': deadline.toIso8601String(),
        'requesterName': requesterName,
        'createdAt': createdAt.toIso8601String(),
        'productUrl': productUrl,
        'note': note,
        'bidCount': bidCount,
        'status': status.name,
      };

  factory HaulRequest.fromJson(Map<String, dynamic> json) => HaulRequest(
        id: json['id'] as String,
        title: json['title'] as String,
        category: HaulCategory.values.byName(json['category'] as String),
        originType: OriginType.values.byName(json['originType'] as String),
        originName: json['originName'] as String,
        quantity: json['quantity'] as int,
        budgetMax: (json['budgetMax'] as num).toDouble(),
        serviceFeeOffer: (json['serviceFeeOffer'] as num).toDouble(),
        deadline: DateTime.parse(json['deadline'] as String),
        requesterName: json['requesterName'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        productUrl: json['productUrl'] as String?,
        note: json['note'] as String? ?? '',
        bidCount: json['bidCount'] as int? ?? 0,
        status: RequestStatus.values.byName(
          json['status'] as String? ?? RequestStatus.open.name,
        ),
      );
}
