import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/core/router/auth_gate.dart';
import 'package:hiewdee/features/address/data/address_repository.dart';
import 'package:hiewdee/features/address/domain/address.dart';
import 'package:hiewdee/features/auth/data/auth_repository.dart';
import 'package:hiewdee/features/auth/domain/app_user.dart';
import 'package:hiewdee/features/auth/presentation/auth_controller.dart';

/// ตัวปลอมแบบไม่หน่วงเวลา — ของจริงหน่วง 600ms ทุกครั้งซึ่งทำให้เทสต์ช้าและเปราะ
class _InstantAuth implements AuthRepository {
  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<AppUser> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    if (otp != MockAuthRepository.demoOtp) {
      throw const AuthFailure('รหัส OTP ไม่ถูกต้อง');
    }
    return AppUser(
      id: 'u_test',
      displayName: 'ฝ้าย',
      phone: phone,
      isVerified: true,
    );
  }

  @override
  Future<AppUser> registerWithPhone({
    required String phone,
    required String displayName,
  }) async =>
      AppUser(id: 'u_test', displayName: displayName, phone: phone);

  @override
  Future<void> signOut() async {}
}

Address _address(String id) => Address(
      id: id,
      receiverName: 'ฝ้าย',
      phone: '0812345678',
      provinceCode: 10,
      provinceName: 'กรุงเทพมหานคร',
      districtCode: 1001,
      districtName: 'พระนคร',
      subdistrictCode: 100101,
      subdistrictName: 'พระบรมมหาราชวัง',
      postalCode: 10200,
      line1: '99/1',
    );

/// ปุ่มสมมติที่เรียก AuthGate เหมือนปุ่มจริงในแอป
class _Harness extends ConsumerWidget {
  const _Harness({required this.onTap});

  final Future<void> Function(BuildContext, WidgetRef) onTap;

  static const label = 'ทำสิ่งที่ต้องล็อกอิน';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => onTap(context, ref),
          child: const Text(label),
        ),
      ),
    );
  }
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(_InstantAuth())],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pumpHarness(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef) onTap,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: _Harness(onTap: onTap)),
      ),
    );
  }

  Future<void> signIn() => container
      .read(authControllerProvider.notifier)
      .verifyOtp(phone: '0812345678', otp: MockAuthRepository.demoOtp);

  void popSheet(WidgetTester tester) {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  }

  group('ensureSignedIn', () {
    testWidgets('ยังไม่ล็อกอิน → เด้ง sheet พร้อมบอกเหตุผล', (tester) async {
      await pumpHarness(
        tester,
        (context, ref) => ref.ensureSignedIn(
          context,
          reason: 'เข้าสู่ระบบเพื่อฝากหิ้วของ',
        ),
      );

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();

      expect(find.text('เข้าสู่ระบบ / สมัครสมาชิก'), findsOneWidget);
      expect(find.text('เข้าสู่ระบบเพื่อฝากหิ้วของ'), findsOneWidget);
    });

    testWidgets('ปิด sheet ทิ้ง → คืน false และยังไม่ล็อกอิน', (tester) async {
      bool? result;
      await pumpHarness(tester, (context, ref) async {
        result = await ref.ensureSignedIn(context);
      });

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();
      popSheet(tester);
      await tester.pumpAndSettle();

      expect(result, isFalse);
      expect(container.read(isLoggedInProvider), isFalse);
    });

    testWidgets('ล็อกอินอยู่แล้ว → ไม่เด้ง sheet คืน true ทันที',
        (tester) async {
      await signIn();

      bool? result;
      await pumpHarness(tester, (context, ref) async {
        result = await ref.ensureSignedIn(context);
      });

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text('เข้าสู่ระบบ / สมัครสมาชิก'), findsNothing);
    });

    testWidgets('ล็อกอินสำเร็จผ่าน sheet → sheet ปิดเอง แล้วคืน true',
        (tester) async {
      bool? result;
      await pumpHarness(tester, (context, ref) async {
        result = await ref.ensureSignedIn(context);
      });

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0812345678');
      await tester.pump();
      await tester.tap(find.text('ขอรหัส OTP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), MockAuthRepository.demoOtp);
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(container.read(isLoggedInProvider), isTrue);
      expect(find.text('ยืนยันรหัส OTP'), findsNothing);
    });

    testWidgets('ใส่ OTP ผิด → ยังอยู่ที่ sheet และขึ้นข้อความผิดพลาด',
        (tester) async {
      await pumpHarness(
        tester,
        (context, ref) => ref.ensureSignedIn(context),
      );

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '0899999999');
      await tester.pump();
      await tester.tap(find.text('ขอรหัส OTP'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.pumpAndSettle();

      expect(container.read(isLoggedInProvider), isFalse);
      expect(find.text('รหัส OTP ไม่ถูกต้อง'), findsOneWidget);
    });
  });

  group('ensureAddress', () {
    testWidgets('ล็อกอินแล้วและมีที่อยู่เริ่มต้น → คืนที่อยู่นั้นเลย',
        (tester) async {
      await signIn();
      container.read(addressListProvider.notifier).upsert(_address('a1'));

      Address? picked;
      await pumpHarness(tester, (context, ref) async {
        picked = await ref.ensureAddress(context);
      });

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();

      expect(picked?.id, 'a1');
    });

    testWidgets('ยังไม่ล็อกอินแล้วปิด sheet → คืน null ไม่พาไปกรอกที่อยู่',
        (tester) async {
      Address? picked;
      var completed = false;
      await pumpHarness(tester, (context, ref) async {
        picked = await ref.ensureAddress(context);
        completed = true;
      });

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();
      popSheet(tester);
      await tester.pumpAndSettle();

      expect(completed, isTrue, reason: 'flow ต้องจบเงียบๆ ไม่ค้าง');
      expect(picked, isNull);
    });
  });

  group('ensureCarrier', () {
    testWidgets('เปิดโหมดนักหิ้วไว้แล้ว → ผ่านเลย ไม่ต้องเข้าหน้าสมัคร',
        (tester) async {
      await signIn();
      container.read(authControllerProvider.notifier).enableCarrierMode();

      bool? result;
      await pumpHarness(tester, (context, ref) async {
        result = await ref.ensureCarrier(context);
      });

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('ยังไม่ล็อกอินแล้วปิด sheet → คืน false', (tester) async {
      bool? result;
      await pumpHarness(tester, (context, ref) async {
        result = await ref.ensureCarrier(context);
      });

      await tester.tap(find.text('ทำสิ่งที่ต้องล็อกอิน'));
      await tester.pumpAndSettle();
      popSheet(tester);
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });
}
