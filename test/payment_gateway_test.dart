import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/payments/data/mock_payment_gateway.dart';
import 'package:hiewdee/features/payments/domain/payment_gateway.dart';

CardDetails card(String number) => CardDetails(
      name: 'FAI NANTHASA',
      number: number,
      expiryMonth: 12,
      expiryYear: 2030,
      securityCode: '123',
    );

void main() {
  group('แปลงบาทเป็นสตางค์', () {
    test('Opn คิดยอดเป็นสตางค์ ไม่ใช่บาท', () {
      expect(toSatang(1250), 125000);
      expect(toSatang(1), 100);
      expect(toSatang(0.5), 50);
    });

    test('ปัดเศษทศนิยมที่เกินสองตำแหน่ง ไม่ปล่อยให้ยอดเพี้ยน', () {
      // ค่าธรรมเนียม gross-up ทำให้ได้เลขทศนิยมยาวๆ เสมอ
      expect(toSatang(1234.567), 123457);
      expect(toSatang(99.994), 9999);
      expect(toSatang(99.995), 10000);
    });

    test('แปลงกลับไปกลับมาแล้วยอดต้องไม่หาย', () {
      for (final baht in [0.0, 1.0, 99.99, 1250.5, 88888.88]) {
        expect(fromSatang(toSatang(baht)), closeTo(baht, 0.005));
      }
    });
  });

  group('ตรวจเลขบัตรด้วย Luhn ก่อนยิงเน็ต', () {
    test('เลขบัตรทดสอบของ Omise ผ่าน', () {
      expect(card('4242424242424242').hasValidNumber, isTrue);
      expect(card('4242 4242 4242 4242').hasValidNumber, isTrue,
          reason: 'เว้นวรรคต้องถูกถอดออกก่อนตรวจ');
    });

    test('พิมพ์ผิดหนึ่งหลักต้องจับได้', () {
      expect(card('4242424242424243').hasValidNumber, isFalse);
    });

    test('สั้นหรือยาวเกินไปไม่ผ่าน', () {
      expect(card('424242').hasValidNumber, isFalse);
      expect(card('42424242424242424242').hasValidNumber, isFalse);
    });

    test('ข้อมูลไม่ครบถือว่ายังกรอกไม่เสร็จ', () {
      const noName = CardDetails(
        name: '  ',
        number: '4242424242424242',
        expiryMonth: 12,
        expiryYear: 2030,
        securityCode: '123',
      );
      const badMonth = CardDetails(
        name: 'FAI',
        number: '4242424242424242',
        expiryMonth: 13,
        expiryYear: 2030,
        securityCode: '123',
      );

      expect(noName.isComplete, isFalse);
      expect(badMonth.isComplete, isFalse);
      expect(card('4242424242424242').isComplete, isTrue);
    });
  });

  group('ช่องทางจำลอง', () {
    const gateway = MockPaymentGateway();

    Future<PaymentResult> pay({
      double amount = 1250,
      PaymentMethod method = PaymentMethod.card,
      CardDetails? withCard,
    }) =>
        gateway.charge(
          orderId: 'o1',
          amountTHB: amount,
          method: method,
          card: withCard ?? card('4242424242424242'),
        );

    test('บัตรปกติจ่ายผ่าน และยอดที่คืนมาตรงกับที่ขอ', () async {
      final result = await pay();

      expect(result, isA<PaymentSuccess>());
      expect((result as PaymentSuccess).amountTHB, 1250);
      expect(result.chargeId, isNotEmpty);
    });

    test('บัตรลงท้าย 0002 ถูกปฏิเสธ', () async {
      final result = await pay(withCard: card('4111111111110002'));

      expect(result, isA<PaymentFailure>());
    });

    test('ยอดเป็นศูนย์หรือติดลบจ่ายไม่ได้', () async {
      expect(await pay(amount: 0), isA<PaymentFailure>());
      expect(await pay(amount: -100), isA<PaymentFailure>());
    });

    test('เลขบัตรผิดถูกจับตั้งแต่ก่อนถึง gateway', () async {
      final result = await pay(withCard: card('1234567812345678'));

      expect(result, isA<PaymentFailure>());
    });

    test('พร้อมเพย์ได้สถานะรอจ่าย ไม่ใช่สำเร็จทันที', () async {
      final result = await pay(method: PaymentMethod.promptPay);

      expect(result, isA<PaymentPending>());
      expect((result as PaymentPending).instruction, isNotEmpty);
    });

    test('ติดธงไว้ชัดว่าเป็นของจำลอง เงินไม่เดินจริง', () {
      expect(gateway.isSimulated, isTrue);
      expect(gateway.displayName, contains('ทดลอง'));
    });
  });
}
