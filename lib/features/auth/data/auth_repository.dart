import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';

/// สัญญาของชั้น data — ตอนย้ายไป Supabase ให้เขียน implementation ใหม่
/// ตัวเดียว ส่วน UI ทั้งหมดไม่ต้องแก้
abstract interface class AuthRepository {
  Future<void> requestOtp(String phone);
  Future<AppUser> verifyOtp({required String phone, required String otp});
  Future<AppUser> registerWithPhone({
    required String phone,
    required String displayName,
  });
  Future<void> signOut();
}

/// ตัวปลอมไว้ใช้ระหว่างยังไม่มี backend — OTP ที่ถูกต้องคือ 123456
class MockAuthRepository implements AuthRepository {
  static const demoOtp = '123456';

  final _known = <String, AppUser>{
    '0812345678': const AppUser(
      id: 'u_demo',
      displayName: 'ฝ้าย',
      phone: '0812345678',
      isCarrier: true,
      isVerified: true,
      rating: 4.9,
      reviewCount: 128,
      walletBalance: 2500,
    ),
    // บัญชีแอดมินสำหรับลองหน้าตัดสินข้อพิพาท
    // ของจริงสิทธิ์นี้ต้องมาจากเซิร์ฟเวอร์ ไม่ใช่ค่าที่ไคลเอนต์ถืออยู่
    '0899999999': const AppUser(
      id: 'u_admin',
      displayName: 'เจ้าหน้าที่',
      phone: '0899999999',
      isVerified: true,
      isAdmin: true,
    ),
  };

  @override
  Future<void> requestOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Future<AppUser> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (otp != demoOtp) {
      throw const AuthFailure('รหัส OTP ไม่ถูกต้อง');
    }
    return _known[phone] ??
        AppUser(
          id: 'u_${phone.hashCode.abs()}',
          displayName: 'ผู้ใช้ ${phone.substring(phone.length - 4)}',
          phone: phone,
        );
  }

  @override
  Future<AppUser> registerWithPhone({
    required String phone,
    required String displayName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final user = AppUser(
      id: 'u_${phone.hashCode.abs()}',
      displayName: displayName,
      phone: phone,
    );
    _known[phone] = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => MockAuthRepository(),
);
