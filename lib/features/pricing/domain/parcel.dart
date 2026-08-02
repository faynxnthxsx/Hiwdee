import 'dart:math' as math;

/// ขนาดและน้ำหนักของพัสดุ ใช้คิดทั้งค่าหิ้วและค่าขนส่ง
class Parcel {
  const Parcel({
    required this.weightKg,
    this.lengthCm = 0,
    this.widthCm = 0,
    this.heightCm = 0,
    this.quantity = 1,
  });

  final double weightKg;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final int quantity;

  /// น้ำหนักปริมาตร — ของเบาแต่กล่องใหญ่ก็กินที่กระเป๋าเท่าของหนัก
  /// ตัวหาร 5000 เป็นค่ามาตรฐานของสายการบิน/ขนส่งทางอากาศ
  double get volumetricKg {
    if (lengthCm <= 0 || widthCm <= 0 || heightCm <= 0) return 0;
    return (lengthCm * widthCm * heightCm) / 5000;
  }

  /// น้ำหนักที่ใช้คิดเงินจริง = ตัวที่มากกว่าระหว่างน้ำหนักจริงกับน้ำหนักปริมาตร
  double get chargeableKg => math.max(weightKg, volumetricKg);

  /// ขนส่งส่วนใหญ่ปัดขึ้นเป็นช่วงครึ่งกิโล
  double get billableKg => (chargeableKg * 2).ceilToDouble() / 2;

  bool get isVolumetricDriven => volumetricKg > weightKg;

  Parcel copyWith({
    double? weightKg,
    double? lengthCm,
    double? widthCm,
    double? heightCm,
    int? quantity,
  }) {
    return Parcel(
      weightKg: weightKg ?? this.weightKg,
      lengthCm: lengthCm ?? this.lengthCm,
      widthCm: widthCm ?? this.widthCm,
      heightCm: heightCm ?? this.heightCm,
      quantity: quantity ?? this.quantity,
    );
  }
}
