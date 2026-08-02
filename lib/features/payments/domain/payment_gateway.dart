/// วิธีจ่ายเงินที่ผู้ฝากเลือกได้
enum PaymentMethod {
  promptPay('พร้อมเพย์', 'สแกน QR จ่ายจากแอปธนาคาร ค่าธรรมเนียมถูกที่สุด'),
  card('บัตรเครดิต / เดบิต', 'Visa · Mastercard · JCB');

  const PaymentMethod(this.text, this.description);
  final String text;
  final String description;
}

/// ข้อมูลบัตรที่ผู้ใช้กรอก — ส่งไปแลก token เท่านั้น ไม่เก็บลงเครื่องเด็ดขาด
class CardDetails {
  const CardDetails({
    required this.name,
    required this.number,
    required this.expiryMonth,
    required this.expiryYear,
    required this.securityCode,
  });

  final String name;
  final String number;
  final int expiryMonth;
  final int expiryYear;
  final String securityCode;

  /// เลขบัตรที่ผู้ใช้พิมพ์มักมีเว้นวรรค ต้องถอดก่อนส่ง
  String get digitsOnly => number.replaceAll(RegExp(r'\D'), '');

  /// ตรวจด้วย Luhn ก่อนยิงเน็ต — ผู้ใช้พิมพ์ผิดจะได้รู้ทันทีไม่ต้องรอ API
  bool get hasValidNumber {
    final d = digitsOnly;
    if (d.length < 13 || d.length > 19) return false;

    var sum = 0;
    var double = false;
    for (var i = d.length - 1; i >= 0; i--) {
      var n = d.codeUnitAt(i) - 48;
      if (double) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      double = !double;
    }
    return sum % 10 == 0;
  }

  bool get isComplete =>
      name.trim().isNotEmpty &&
      hasValidNumber &&
      expiryMonth >= 1 &&
      expiryMonth <= 12 &&
      expiryYear >= 2020 &&
      securityCode.length >= 3;
}

/// ผลของการพยายามจ่ายเงินหนึ่งครั้ง
sealed class PaymentResult {
  const PaymentResult();
}

/// จ่ายสำเร็จ เงินเข้าระบบแล้ว
class PaymentSuccess extends PaymentResult {
  const PaymentSuccess({required this.chargeId, required this.amountTHB});

  final String chargeId;
  final double amountTHB;
}

/// ต้องให้ผู้ใช้ไปทำอะไรต่อก่อน เช่น สแกน QR พร้อมเพย์
class PaymentPending extends PaymentResult {
  const PaymentPending({
    required this.chargeId,
    required this.instruction,
    this.qrImageUrl,
  });

  final String chargeId;
  final String instruction;
  final String? qrImageUrl;
}

class PaymentFailure extends PaymentResult {
  const PaymentFailure(this.message);
  final String message;
}

/// สัญญาของช่องทางรับชำระเงิน
///
/// มีสองตัวจริง: ตัวจำลองไว้เล่นตอนยังไม่มี key กับตัวที่ต่อ Opn Payments
/// UI เรียกผ่านหน้านี้อย่างเดียว เปลี่ยนเจ้าทีหลังจึงไม่ต้องแก้หน้าจอ
abstract interface class PaymentGateway {
  /// ชื่อที่โชว์ให้ผู้ใช้รู้ว่ากำลังใช้ของจริงหรือของจำลอง
  String get displayName;

  /// true = ยังไม่ได้ต่อของจริง เงินไม่เดิน
  bool get isSimulated;

  Future<PaymentResult> charge({
    required String orderId,
    required double amountTHB,
    required PaymentMethod method,
    CardDetails? card,
  });
}

/// Omise/Opn คิดยอดเป็น **สตางค์** ไม่ใช่บาท
///
/// จุดที่พลาดกันบ่อยที่สุดของการต่อ gateway นี้ — ส่ง 1250 ไปทั้งที่ตั้งใจ
/// จะเก็บ ฿1,250 จะกลายเป็นเก็บจริง ฿12.50
int toSatang(double baht) => (baht * 100).round();

double fromSatang(int satang) => satang / 100;
