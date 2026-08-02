import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/payment_gateway.dart';
import 'mock_payment_gateway.dart';
import 'opn_payment_gateway.dart';
import 'payment_config.dart';

/// เลือกช่องทางจ่ายเงินจากค่าที่ตั้งไว้ตอนรัน
///
/// ไม่ได้ใส่ key มา → ใช้ตัวจำลอง แอปยังเล่นได้ครบทุก flow
/// ใส่ key ครบ → ต่อ Opn ของจริง โดย UI ไม่ต้องแก้อะไรเลย
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  // ดังๆ ไว้ เพราะถ้าเงียบผู้ใช้จะนึกว่าต่อของจริงได้แล้วทั้งที่ยังไม่ได้ต่อ
  assert(
    !PaymentConfig.hasSecretKeyByMistake,
    'OPN_PUBLIC_KEY ได้รับ secret key (skey_) มา ซึ่งห้ามอยู่ในแอปเด็ดขาด\n'
    'ไปเอา public key (pkey_) จาก Opn Dashboard → Keys มาใส่แทน\n'
    'แล้วไปเพิกถอน secret key ตัวที่หลุดมาด้วย',
  );

  if (!PaymentConfig.isLive) return const MockPaymentGateway();
  return OpnPaymentGateway();
});
