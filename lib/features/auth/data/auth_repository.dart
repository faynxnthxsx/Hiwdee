import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../domain/app_user.dart';
import '../domain/social_provider.dart';
import 'supabase_auth_repository.dart';

/// สัญญาของชั้น data
///
/// รองรับสามทาง: Google · Facebook · เบอร์โทร + OTP
/// UI เรียกผ่านหน้านี้อย่างเดียว ตอนสลับจาก mock ไป Supabase จึงไม่ต้องแก้หน้าจอ
abstract interface class AuthRepository {
  /// เซสชันปัจจุบัน — ใช้กู้สถานะตอนเปิดแอปหรือหลัง OAuth พากลับมา
  AppUser? get currentUser;

  /// เปลี่ยนทุกครั้งที่ล็อกอิน/ล็อกเอาต์
  ///
  /// จำเป็นสำหรับ OAuth เพราะบนเว็บมันพาออกไปหน้าผู้ให้บริการแล้วค่อย
  /// redirect กลับมา — โค้ดที่กดปุ่มไม่ได้อยู่รอรับผลลัพธ์แล้ว
  Stream<AppUser?> authChanges();

  /// พาไปหน้าล็อกอินของ Google/Facebook
  ///
  /// บนเว็บจะ redirect ออกไป ผลลัพธ์จริงมาทาง [authChanges]
  /// จึงคืนแค่ว่าเริ่ม flow ได้ไหม ไม่ได้คืน [AppUser]
  Future<void> signInWith(SocialProvider provider);

  Future<void> requestOtp(String phone);

  Future<AppUser> verifyOtp({required String phone, required String otp});

  Future<AppUser> registerWithPhone({
    required String phone,
    required String displayName,
  });

  Future<void> signOut();
}

/// ตัวปลอมไว้ใช้ตอนยังไม่ได้ต่อ Supabase — OTP ที่ถูกต้องคือ 123456
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

  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authChanges() => const Stream<AppUser?>.empty();

  /// จำลองล็อกอินโซเชียลให้สำเร็จทันที เพื่อให้เดิน flow ต่อได้ตอนยังไม่มี key
  @override
  Future<void> signInWith(SocialProvider provider) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _current = AppUser(
      id: 'u_${provider.name}',
      displayName: 'ผู้ใช้ ${provider.text}',
      phone: '',
      isVerified: true,
    );
  }

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
    _current = _known[phone] ??
        AppUser(
          id: 'u_${phone.hashCode.abs()}',
          displayName: 'ผู้ใช้ ${phone.substring(phone.length - 4)}',
          phone: phone,
        );
    return _current!;
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
    _current = user;
    return user;
  }

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _current = null;
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message, [this.kind = AuthFailureKind.other]);

  final String message;
  final AuthFailureKind kind;

  @override
  String toString() => message;
}

/// ต่อ Supabase อยู่ → ใช้ auth ของจริง ไม่งั้นใช้ตัวปลอม
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return MockAuthRepository();
  return SupabaseAuthRepository(client);
});
