/// ทริปของนักหิ้ว — ประกาศไว้ว่ากำลังจะไปไหน รับหิ้วได้เท่าไหร่
class Trip {
  const Trip({
    required this.id,
    required this.carrierName,
    required this.fromPlace,
    required this.toPlace,
    required this.departAt,
    required this.returnAt,
    required this.capacityKg,
    required this.usedKg,
    required this.feePerKg,
    this.carrierRating = 0,
    this.carrierReviewCount = 0,
    this.isVerified = false,
    this.note = '',
  });

  final String id;
  final String carrierName;
  final double carrierRating;
  final int carrierReviewCount;
  final bool isVerified;

  /// ต้นทาง เช่น "ญี่ปุ่น · โอซาก้า"
  final String fromPlace;

  /// ปลายทาง เช่น "กรุงเทพฯ"
  final String toPlace;

  final DateTime departAt;
  final DateTime returnAt;

  final double capacityKg;
  final double usedKg;
  final double feePerKg;
  final String note;

  double get remainingKg => (capacityKg - usedKg).clamp(0.0, capacityKg);
  bool get isFull => remainingKg <= 0;
  double get fillRatio =>
      capacityKg == 0 ? 0 : (usedKg / capacityKg).clamp(0.0, 1.0);

  /// ยังรับของเพิ่มได้ และยังไม่ออกเดินทาง
  bool get isAcceptingNow =>
      !isFull && departAt.isAfter(DateTime.now());
}
