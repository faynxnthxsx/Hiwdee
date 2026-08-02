import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/admin/presentation/admin_screen.dart';
import 'package:hiewdee/features/auth/data/auth_repository.dart';
import 'package:hiewdee/features/auth/domain/app_user.dart';
import 'package:hiewdee/features/auth/presentation/auth_controller.dart';
import 'package:hiewdee/features/orders/data/order_repository.dart';
import 'package:hiewdee/features/orders/domain/order_status.dart';

import 'support/fake_auth_repository.dart';

const _admin = AppUser(
  id: 'u_admin',
  displayName: 'เจ้าหน้าที่',
  phone: '0899999999',
  isVerified: true,
  isAdmin: true,
);

const _normal = AppUser(
  id: 'u_normal',
  displayName: 'ฝ้าย',
  phone: '0812345678',
);

void main() {
  group('สิทธิ์เดินสถานะข้อพิพาท', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    OrderNotifier orders() => container.read(orderListProvider.notifier);

    /// พา o1 (ผู้ฝาก · กำลังนำส่ง) เข้าสู่ข้อพิพาท
    void openDispute() {
      final moved = orders().advance(
        'o1',
        OrderStatus.disputed,
        note: 'ของไม่ตรงปก',
      );
      expect(moved, isTrue, reason: 'ผู้ฝากเปิดเคสได้');
    }

    test('คู่กรณีปิดเคสเองไม่ได้ ทั้งสองทาง', () {
      openDispute();

      expect(
        orders().advance('o1', OrderStatus.completed),
        isFalse,
        reason: 'ผู้ฝากตัดสินให้ตัวเองไม่ได้',
      );
      expect(
        orders().advance('o1', OrderStatus.cancelled),
        isFalse,
      );
      expect(
        container.read(orderByIdProvider('o1'))!.status,
        OrderStatus.disputed,
        reason: 'สถานะต้องไม่ขยับเลย',
      );
    });

    test('แพลตฟอร์มตัดสินให้นักหิ้วได้', () {
      openDispute();

      final moved = orders().advance(
        'o1',
        OrderStatus.completed,
        by: OrderActor.platform,
        note: 'แอดมินตัดสิน',
      );

      expect(moved, isTrue);
      expect(
        container.read(orderByIdProvider('o1'))!.status,
        OrderStatus.completed,
      );
    });

    test('แพลตฟอร์มตัดสินคืนเงินผู้ฝากได้', () {
      openDispute();

      expect(
        orders().advance(
          'o1',
          OrderStatus.cancelled,
          by: OrderActor.platform,
        ),
        isTrue,
      );
    });

    test('แพลตฟอร์มก็ข้ามขั้นตอนปกติไม่ได้', () {
      // ยังไม่ได้เปิดเคส o1 อยู่ที่ inTransit
      expect(
        orders().advance(
          'o1',
          OrderStatus.completed,
          by: OrderActor.platform,
        ),
        isFalse,
        reason: 'อำนาจแอดมินมีเฉพาะตอนอยู่ในข้อพิพาท',
      );
    });

    test('คำตัดสินถูกบันทึกลงไทม์ไลน์', () {
      openDispute();
      orders().advance(
        'o1',
        OrderStatus.completed,
        by: OrderActor.platform,
        note: 'แอดมินตัดสิน: จ่ายค่าจ้างนักหิ้ว',
      );

      final last = container.read(orderByIdProvider('o1'))!.timeline.last;

      expect(last.status, OrderStatus.completed);
      expect(last.note, contains('แอดมิน'));
    });
  });

  group('หน้าแอดมิน — ใครเข้าได้', () {
    Future<void> pump(WidgetTester tester, ProviderContainer container) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AdminScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('ยังไม่ล็อกอิน → ขอให้เข้าสู่ระบบก่อน', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await pump(tester, container);

      expect(find.text('เฉพาะเจ้าหน้าที่'), findsOneWidget);
      expect(find.text('คิวข้อพิพาท'), findsNothing);
    });

    testWidgets('ผู้ใช้ทั่วไป → ถูกกั้น ไม่เห็นคิว', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: _normal)),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: _normal.phone, otp: MockAuthRepository.demoOtp);

      await pump(tester, container);

      expect(find.textContaining('ไม่มีสิทธิ์'), findsOneWidget);
    });

    testWidgets('แอดมิน → เห็นคิว และขึ้นว่าไม่มีเคสรอ', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: _admin)),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: _admin.phone, otp: MockAuthRepository.demoOtp);

      await pump(tester, container);

      expect(find.text('คิวข้อพิพาท'), findsOneWidget);
      expect(find.textContaining('ไม่มีข้อพิพาท'), findsOneWidget);
    });

    testWidgets('มีเคสค้าง → การ์ดเคสโผล่พร้อมปุ่มตัดสินสองทาง',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: _admin)),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: _admin.phone, otp: MockAuthRepository.demoOtp);

      container
          .read(orderListProvider.notifier)
          .advance('o1', OrderStatus.disputed);

      await pump(tester, container);

      expect(find.text('รอตัดสิน'), findsOneWidget);
      expect(find.text('ตัดสินให้ผู้ฝาก'), findsOneWidget);
      expect(find.text('ตัดสินให้นักหิ้ว'), findsOneWidget);
    });
  });
}
