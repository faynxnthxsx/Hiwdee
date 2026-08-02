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
  if (!PaymentConfig.isLive) return const MockPaymentGateway();
  return OpnPaymentGateway();
});
