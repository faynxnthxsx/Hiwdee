import 'package:hiewdee/features/auth/data/auth_repository.dart';
import 'package:hiewdee/features/auth/domain/app_user.dart';
import 'package:hiewdee/features/auth/domain/social_provider.dart';

/// ตัวปลอมสำหรับเทสต์ — ไม่หน่วงเวลาเหมือน [MockAuthRepository]
///
/// ของจริงหน่วง 600ms ทุกครั้ง ซึ่งทำให้เทสต์ช้าและเปราะ
/// อยู่ในไฟล์เดียวเพื่อไม่ให้ทุกไฟล์เทสต์ต้องเขียน implements ใหม่
/// ทุกครั้งที่ [AuthRepository] เพิ่มเมธอด
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AppUser? user}) : _template = user;

  /// ผู้ใช้ที่จะคืนหลังล็อกอินสำเร็จ — ไม่ระบุก็สร้างจากเบอร์ที่กรอก
  final AppUser? _template;

  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> authChanges() => const Stream<AppUser?>.empty();

  @override
  Future<void> signInWith(SocialProvider provider) async {
    _current = _template ??
        AppUser(
          id: 'u_${provider.name}',
          displayName: 'ผู้ใช้ ${provider.text}',
          phone: '',
          isVerified: true,
        );
  }

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
    _current = _template ??
        AppUser(
          id: 'u_test',
          displayName: 'ฝ้าย',
          phone: phone,
          isVerified: true,
        );
    return _current!;
  }

  @override
  Future<AppUser> registerWithPhone({
    required String phone,
    required String displayName,
  }) async {
    _current = AppUser(id: 'u_test', displayName: displayName, phone: phone);
    return _current!;
  }

  @override
  Future<void> signOut() async {
    _current = null;
  }
}
