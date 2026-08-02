import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/auth/data/auth_repository.dart';
import 'package:hiewdee/features/auth/domain/app_user.dart';
import 'package:hiewdee/features/auth/presentation/auth_controller.dart';
import 'package:hiewdee/features/address/presentation/address_list_screen.dart';
import 'package:hiewdee/features/admin/presentation/admin_screen.dart';
import 'package:hiewdee/features/chat/presentation/chat_screen.dart';
import 'package:hiewdee/features/orders/presentation/order_detail_screen.dart';
import 'package:hiewdee/features/orders/presentation/orders_screen.dart';
import 'package:hiewdee/features/pricing/presentation/cost_calculator_screen.dart';
import 'package:hiewdee/features/pricing/presentation/customs_guide_screen.dart';
import 'package:hiewdee/features/profile/presentation/profile_screen.dart';
import 'package:hiewdee/features/request/presentation/feed_screen.dart';
import 'package:hiewdee/features/request/presentation/request_detail_screen.dart';
import 'package:hiewdee/features/trip/presentation/trip_feed_screen.dart';

/// เทสต์ "เปิดหน้าแล้วไม่พัง"
///
/// มีเพราะเคยพลาดมาแล้วจริงๆ — `ProfileScreen` ใส่ margin ติดลบไว้ ซึ่ง
/// `Container` assert ห้ามไว้ แอปเลยพังทันทีที่กดแท็บ "ฉัน" แต่ไม่มีเทสต์ไหน
/// เคย build หน้านั้นเลย บั๊กจึงรอดมาถึงมือผู้ใช้
///
/// เทสต์กลุ่มนี้ไม่ตรวจว่าหน้าตาถูกไหม แค่ยืนยันว่า build ผ่านโดยไม่มี
/// exception ซึ่งดักบั๊กประเภทนี้ได้ทั้งชุดด้วยโค้ดไม่กี่บรรทัด
class _InstantAuth implements AuthRepository {
  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<AppUser> verifyOtp({
    required String phone,
    required String otp,
  }) async =>
      AppUser(
        id: 'u_test',
        displayName: 'ฝ้าย',
        phone: phone,
        isCarrier: true,
        isVerified: true,
        rating: 4.9,
        reviewCount: 128,
        walletBalance: 2500,
      );

  @override
  Future<AppUser> registerWithPhone({
    required String phone,
    required String displayName,
  }) async =>
      AppUser(id: 'u_test', displayName: displayName, phone: phone);

  @override
  Future<void> signOut() async {}
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(_InstantAuth())],
    );
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn() => container
      .read(authControllerProvider.notifier)
      .verifyOtp(phone: '0812345678', otp: MockAuthRepository.demoOtp);

  final screens = <String, Widget>{
    'ฟีดคำขอ': const FeedScreen(),
    'ทริปนักหิ้ว': const TripFeedScreen(),
    'ออเดอร์': const OrdersScreen(),
    'โปรไฟล์': const ProfileScreen(),
    'เครื่องคำนวณ': const CostCalculatorScreen(),
    'คู่มือภาษี': const CustomsGuideScreen(),
    'สมุดที่อยู่': const AddressListScreen(),
    'รายละเอียดคำขอ': const RequestDetailScreen(requestId: 'r1'),
    'รายละเอียดออเดอร์': const OrderDetailScreen(orderId: 'o3'),
    'ห้องแชท': const ChatScreen(orderId: 'o1'),
    'หน้าแอดมิน': const AdminScreen(),
  };

  group('เปิดแบบยังไม่ล็อกอิน', () {
    screens.forEach((name, screen) {
      testWidgets('$name build ผ่านโดยไม่มี exception', (tester) async {
        await pump(tester, screen);
        expect(tester.takeException(), isNull);
      });
    });
  });

  group('เปิดแบบล็อกอินแล้ว', () {
    screens.forEach((name, screen) {
      testWidgets('$name build ผ่านโดยไม่มี exception', (tester) async {
        await signIn();
        await pump(tester, screen);
        expect(tester.takeException(), isNull);
      });
    });
  });

  testWidgets('แท็บ "ฉัน" โชว์ยอดกระเป๋าเงินของผู้ใช้', (tester) async {
    await signIn();
    await pump(tester, const ProfileScreen());

    expect(find.text('กระเป๋าเงิน'), findsOneWidget);
    expect(find.text('฿2,500'), findsOneWidget);
  });

  testWidgets('แท็บออเดอร์แยกสองฝั่ง ฉันฝาก / ฉันหิ้ว', (tester) async {
    await signIn();
    await pump(tester, const OrdersScreen());

    expect(find.textContaining('ฉันฝาก'), findsOneWidget);
    expect(find.textContaining('ฉันหิ้ว'), findsOneWidget);
  });
}
