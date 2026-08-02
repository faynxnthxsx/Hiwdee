import '../domain/payment_gateway.dart';

/// ช่องทางจ่ายเงินจำลอง — ใช้ตอนยังไม่มี key ของ Opn
///
/// ไม่ใช่แค่ `return success` เฉยๆ แต่จำลองกรณีที่พังจริงด้วย
/// เพื่อให้ทดสอบ UI ฝั่งข้อความผิดพลาดได้โดยไม่ต้องต่อเน็ต:
///
/// | เลขบัตรลงท้าย | ผลลัพธ์ |
/// |---|---|
/// | `0002` | บัตรถูกปฏิเสธ |
/// | `0003` | วงเงินไม่พอ |
/// | อื่นๆ | สำเร็จ |
///
/// เลขทดสอบชุดนี้ล้อกับของ Omise เพื่อให้พอสลับไปของจริงแล้วยังใช้ได้เหมือนเดิม
class MockPaymentGateway implements PaymentGateway {
  const MockPaymentGateway();

  @override
  String get displayName => 'โหมดทดลอง (เงินไม่เดินจริง)';

  @override
  bool get isSimulated => true;

  @override
  Future<PaymentResult> charge({
    required String orderId,
    required double amountTHB,
    required PaymentMethod method,
    CardDetails? card,
  }) async {
    // หน่วงให้เห็นสถานะกำลังโหลด เหมือนยิงเน็ตจริง
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (amountTHB <= 0) {
      return const PaymentFailure('ยอดชำระต้องมากกว่า 0');
    }

    if (method == PaymentMethod.promptPay) {
      return PaymentPending(
        chargeId: 'chrg_mock_$orderId',
        instruction: 'สแกน QR นี้ในแอปธนาคารเพื่อจ่าย '
            '${amountTHB.toStringAsFixed(2)} บาท '
            '(โหมดทดลอง — กดยืนยันด้านล่างได้เลย)',
      );
    }

    if (card == null) {
      return const PaymentFailure('ยังไม่ได้กรอกข้อมูลบัตร');
    }
    if (!card.hasValidNumber) {
      return const PaymentFailure('เลขบัตรไม่ถูกต้อง');
    }

    return switch (card.digitsOnly) {
      final n when n.endsWith('0002') =>
        const PaymentFailure('บัตรถูกปฏิเสธ ลองใช้บัตรใบอื่น'),
      final n when n.endsWith('0003') =>
        const PaymentFailure('วงเงินไม่พอ'),
      _ => PaymentSuccess(
          chargeId: 'chrg_mock_$orderId',
          amountTHB: amountTHB,
        ),
    };
  }
}
