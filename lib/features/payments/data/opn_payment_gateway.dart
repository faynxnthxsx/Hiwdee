import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/payment_gateway.dart';
import 'payment_config.dart';

/// ต่อกับ Opn Payments (เดิมชื่อ Omise)
///
/// ## ทำไมต้องมี backend
///
/// การจ่ายเงินแบ่งเป็นสองท่อน และมีแค่ท่อนแรกที่ทำในแอปได้:
///
/// 1. **แลกเลขบัตรเป็น token** — ยิงตรงไป `vault.omise.co` ด้วย *public key*
///    เลขบัตรจริงจึงไม่เคยผ่านเซิร์ฟเวอร์ของเรา ซึ่งเป็นเรื่องดีมาก
///    เพราะทำให้ขอบเขต PCI-DSS แคบลงเยอะ
///
/// 2. **สร้าง charge จาก token** — ต้องใช้ *secret key* ซึ่ง**ห้ามอยู่ในแอป**
///    เพราะโค้ดฝั่งไคลเอนต์ถอดดูได้เสมอ ไม่ว่าจะซ่อนดีแค่ไหน
///    ใครได้ไปก็สั่งตัดเงิน คืนเงิน หรือดูรายการทั้งหมดในนามคุณได้
///
/// ท่อนที่ 2 จึงยิงไป [PaymentConfig.apiBase] ซึ่งเป็นเซิร์ฟเวอร์ของเราเอง
/// ตัวอย่าง endpoint ที่ backend ต้องมี ดูได้ที่ `docs/payment-backend.md`
class OpnPaymentGateway implements PaymentGateway {
  OpnPaymentGateway({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String get displayName => PaymentConfig.isTestKey
      ? 'Opn Payments · โหมดทดสอบ'
      : 'Opn Payments';

  @override
  bool get isSimulated => PaymentConfig.isTestKey;

  @override
  Future<PaymentResult> charge({
    required String orderId,
    required double amountTHB,
    required PaymentMethod method,
    CardDetails? card,
  }) async {
    if (amountTHB <= 0) {
      return const PaymentFailure('ยอดชำระต้องมากกว่า 0');
    }

    try {
      final String? token;
      if (method == PaymentMethod.card) {
        if (card == null || !card.isComplete) {
          return const PaymentFailure('ข้อมูลบัตรไม่ครบ');
        }
        token = await _tokenize(card);
        if (token == null) {
          return const PaymentFailure('บัตรใบนี้ใช้ไม่ได้ ลองตรวจเลขอีกครั้ง');
        }
      } else {
        token = null;
      }

      return await _createCharge(
        orderId: orderId,
        amountTHB: amountTHB,
        method: method,
        token: token,
      );
    } on http.ClientException {
      return const PaymentFailure('ต่อเน็ตไม่ได้ ลองใหม่อีกครั้ง');
    } on FormatException {
      return const PaymentFailure('เซิร์ฟเวอร์ตอบกลับมาในรูปแบบที่อ่านไม่ออก');
    }
  }

  /// ขั้นที่ 1 — เลขบัตรไปที่ Opn ตรงๆ ไม่ผ่านเซิร์ฟเวอร์เรา
  Future<String?> _tokenize(CardDetails card) async {
    final auth = base64Encode(utf8.encode('${PaymentConfig.publicKey}:'));

    final res = await _client.post(
      Uri.parse(PaymentConfig.vaultUrl),
      headers: {'Authorization': 'Basic $auth'},
      body: {
        'card[name]': card.name,
        'card[number]': card.digitsOnly,
        'card[expiration_month]': card.expiryMonth.toString(),
        'card[expiration_year]': card.expiryYear.toString(),
        'card[security_code]': card.securityCode,
      },
    );

    if (res.statusCode >= 400) return null;

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) return null;
    return body['id'] as String?;
  }

  /// ขั้นที่ 2 — backend ของเราถือ secret key แล้วสร้าง charge ให้
  ///
  /// ส่ง [orderId] ไปด้วยเพื่อให้ฝั่งเซิร์ฟเวอร์ตรวจยอดเองได้
  /// **อย่าเชื่อยอดที่ไคลเอนต์ส่งมา** — ผู้ใช้แก้ค่าก่อนส่งได้เสมอ
  /// เซิร์ฟเวอร์ต้องเปิดออเดอร์ในฐานข้อมูลแล้วคิดยอดใหม่เอง
  Future<PaymentResult> _createCharge({
    required String orderId,
    required double amountTHB,
    required PaymentMethod method,
    String? token,
  }) async {
    final res = await _client.post(
      Uri.parse('${PaymentConfig.apiBase}/charges'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'orderId': orderId,
        'amount': toSatang(amountTHB),
        'currency': 'THB',
        'method': method.name,
        'token': ?token,
      }),
    );

    final body = jsonDecode(res.body);
    if (body is! Map<String, dynamic>) {
      return const PaymentFailure('เซิร์ฟเวอร์ตอบกลับมาไม่ถูกรูปแบบ');
    }

    if (res.statusCode >= 400) {
      return PaymentFailure(
        body['message'] as String? ?? 'ชำระเงินไม่สำเร็จ',
      );
    }

    final chargeId = body['id'] as String? ?? 'unknown';

    return switch (body['status'] as String?) {
      'successful' => PaymentSuccess(
          chargeId: chargeId,
          amountTHB: fromSatang(body['amount'] as int? ?? 0),
        ),
      'pending' => PaymentPending(
          chargeId: chargeId,
          instruction: 'สแกน QR นี้ในแอปธนาคารเพื่อชำระเงิน',
          qrImageUrl: body['qrImageUrl'] as String?,
        ),
      _ => PaymentFailure(
          body['failureMessage'] as String? ?? 'ชำระเงินไม่สำเร็จ',
        ),
    };
  }
}
