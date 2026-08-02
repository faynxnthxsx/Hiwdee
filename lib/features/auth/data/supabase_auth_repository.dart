import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/app_user.dart';
import '../domain/social_provider.dart';
import 'auth_repository.dart';

/// ล็อกอินของจริงผ่าน Supabase Auth
///
/// ## ทำไม OAuth ต้องมี stream
///
/// บนเว็บ `signInWithOAuth` จะพาเบราว์เซอร์ออกไปหน้า Google/Facebook
/// แล้ว redirect กลับมาที่แอป — โค้ดที่กดปุ่มไม่ได้อยู่รอรับผลลัพธ์อีกแล้ว
/// เพราะหน้าถูกโหลดใหม่ทั้งหน้า ผลจึงต้องมาทาง [authChanges]
///
/// ## profiles ถูกสร้างให้อัตโนมัติ
///
/// Supabase สร้างแถวใน `auth.users` ให้เอง แต่ `public.profiles` ที่แอปใช้
/// ต้อง upsert เอง — ทำตอนอ่านผู้ใช้ครั้งแรกหลังล็อกอิน
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Stream<AppUser?> authChanges() => _auth.onAuthStateChange.map((event) {
        final user = event.session?.user;
        if (user == null) return null;

        // ยิงไปสร้าง/อัปเดตโปรไฟล์แบบไม่รอ เพื่อไม่ให้หน้าจอค้าง
        unawaited(_syncProfile(user));
        return _toAppUser(user);
      });

  @override
  Future<void> signInWith(SocialProvider provider) async {
    try {
      final started = await _auth.signInWithOAuth(
        switch (provider) {
          SocialProvider.google => OAuthProvider.google,
          SocialProvider.facebook => OAuthProvider.facebook,
        },
        // กลับมาที่หน้าเดิมหลังล็อกอินเสร็จ
        // ต้องเพิ่ม URL นี้ใน Supabase → Authentication → URL Configuration
        redirectTo: kIsWeb ? Uri.base.origin : null,
      );

      if (!started) {
        throw const AuthFailure(
          'เปิดหน้าล็อกอินไม่ได้',
          AuthFailureKind.cancelled,
        );
      }
    } on AuthException catch (e) {
      throw AuthFailure(_readableProviderError(e, provider), _kindOf(e));
    }
  }

  @override
  Future<void> requestOtp(String phone) async {
    try {
      await _auth.signInWithOtp(phone: _toE164(phone));
    } on AuthException catch (e) {
      throw AuthFailure(_readableSmsError(e), _kindOf(e));
    }
  }

  @override
  Future<AppUser> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    try {
      final res = await _auth.verifyOTP(
        phone: _toE164(phone),
        token: otp,
        type: OtpType.sms,
      );

      final user = res.user;
      if (user == null) {
        throw const AuthFailure('ยืนยันไม่สำเร็จ', AuthFailureKind.badOtp);
      }

      await _syncProfile(user);
      return _toAppUser(user);
    } on AuthException catch (e) {
      throw AuthFailure(
        e.message.contains('expired')
            ? 'รหัสหมดอายุแล้ว ขอรหัสใหม่อีกครั้ง'
            : 'รหัส OTP ไม่ถูกต้อง',
        AuthFailureKind.badOtp,
      );
    }
  }

  /// Supabase สร้างบัญชีให้ตอนยืนยัน OTP อยู่แล้ว
  /// ขั้นนี้จึงเหลือแค่บันทึกชื่อที่ผู้ใช้ตั้ง
  @override
  Future<AppUser> registerWithPhone({
    required String phone,
    required String displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('เซสชันหลุด กรุณาล็อกอินใหม่');
    }

    await _auth.updateUser(
      UserAttributes(data: {'full_name': displayName}),
    );
    await _syncProfile(user, displayName: displayName);

    return _toAppUser(_auth.currentUser ?? user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  // ── ตัวช่วย ──────────────────────────────────────────────────

  /// เบอร์ไทย 10 หลักขึ้นต้น 0 → +66 ตามรูปแบบ E.164 ที่ Supabase ต้องการ
  static String _toE164(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('66')) return '+$digits';
    if (digits.startsWith('0')) return '+66${digits.substring(1)}';
    return '+$digits';
  }

  AppUser _toAppUser(User user) {
    final meta = user.userMetadata ?? const {};

    return AppUser(
      id: user.id,
      displayName: (meta['full_name'] ?? meta['name'] ?? '') as String? ??
          '',
      phone: user.phone ?? '',
      avatarUrl: meta['avatar_url'] as String?,
      // ยืนยันแล้วเมื่อมาจากผู้ให้บริการภายนอกหรือยืนยันเบอร์/อีเมลแล้ว
      isVerified: user.phoneConfirmedAt != null ||
          user.emailConfirmedAt != null ||
          user.appMetadata['provider'] != 'phone',
    );
  }

  /// สร้างหรืออัปเดตแถวใน `public.profiles`
  ///
  /// ไม่ส่ง `is_admin` ไปด้วยโดยตั้งใจ — ฐานข้อมูลมี trigger กันไว้อยู่แล้ว
  /// ว่าไคลเอนต์แก้คอลัมน์นั้นไม่ได้
  Future<void> _syncProfile(User user, {String? displayName}) async {
    final meta = user.userMetadata ?? const {};

    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': displayName ??
            (meta['full_name'] ?? meta['name'] ?? '') as String? ??
            '',
        'phone': user.phone ?? '',
        'avatar_url': meta['avatar_url'],
      });
    } on PostgrestException catch (e) {
      // โปรไฟล์ซิงก์ไม่ได้ไม่ควรทำให้ล็อกอินล้ม ผู้ใช้ยังใช้แอปได้
      debugPrint('ซิงก์โปรไฟล์ไม่สำเร็จ: ${e.message}');
    }
  }

  static AuthFailureKind _kindOf(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('provider') && m.contains('not enabled')) {
      return AuthFailureKind.providerNotConfigured;
    }
    if (m.contains('sms') || m.contains('phone provider')) {
      return AuthFailureKind.smsNotConfigured;
    }
    return AuthFailureKind.other;
  }

  static String _readableProviderError(
    AuthException e,
    SocialProvider provider,
  ) {
    if (_kindOf(e) == AuthFailureKind.providerNotConfigured) {
      return 'ยังไม่ได้เปิด ${provider.text} ใน Supabase\n'
          'ไปที่ Authentication → Providers แล้วเปิดใช้งานก่อน';
    }
    return 'ล็อกอินด้วย ${provider.text} ไม่สำเร็จ: ${e.message}';
  }

  static String _readableSmsError(AuthException e) {
    if (_kindOf(e) == AuthFailureKind.smsNotConfigured) {
      return 'ยังส่ง SMS ไม่ได้ เพราะยังไม่ได้ผูกผู้ให้บริการ SMS\n'
          'ลองใช้ Google หรือ Facebook แทนไปก่อน';
    }
    return 'ขอรหัส OTP ไม่สำเร็จ: ${e.message}';
  }
}
