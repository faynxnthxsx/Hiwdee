import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../data/auth_repository.dart';
import '../domain/app_user.dart';
import '../domain/social_provider.dart';

class AuthState {
  const AuthState({this.user, this.isBusy = false, this.error});

  final AppUser? user;
  final bool isBusy;
  final String? error;

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    AppUser? user,
    bool? isBusy,
    String? error,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  /// กู้เซสชันเดิมกลับมา — รีเฟรชหน้าเว็บแล้วไม่หลุดล็อกอิน
  ///
  /// ลำดับความน่าเชื่อถือ: เซสชันจริงจาก Supabase มาก่อนค่าที่เซฟไว้ในเครื่อง
  /// เพราะฝั่งเซิร์ฟเวอร์อาจเพิกถอนเซสชันไปแล้วโดยที่เครื่องยังไม่รู้
  @override
  AuthState build() {
    // OAuth บนเว็บ redirect กลับมาแล้วโหลดหน้าใหม่ทั้งหน้า
    // ผลการล็อกอินจึงมาทาง stream ไม่ใช่ค่าคืนจากปุ่มที่กด
    final sub = _repo.authChanges().listen((user) {
      state = user == null ? const AuthState() : AuthState(user: user);
      _persist(user);
    });
    ref.onDispose(sub.cancel);

    final live = _repo.currentUser;
    if (live != null) return AuthState(user: live);

    final saved = _store?.readMap(StoreKeys.user);
    if (saved == null) return const AuthState();
    return AuthState(user: AppUser.fromJson(saved));
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  LocalStore? get _store => ref.read(localStoreProvider);

  void _persist(AppUser? user) {
    final store = _store;
    if (store == null) return;
    if (user == null) {
      store.remove(StoreKeys.user);
    } else {
      store.write(StoreKeys.user, user.toJson());
    }
  }

  /// ล็อกอินด้วย Google หรือ Facebook
  ///
  /// บนเว็บจะ redirect ออกไป โค้ดหลังบรรทัดนี้อาจไม่ได้ทำงานเลย
  /// ผลลัพธ์จริงมาทาง stream ที่ subscribe ไว้ใน [build]
  Future<bool> signInWith(SocialProvider provider) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _repo.signInWith(provider);

      // ตัวปลอมล็อกอินเสร็จทันทีโดยไม่ redirect จึงต้องหยิบผลมาเอง
      final user = _repo.currentUser;
      if (user != null) {
        state = AuthState(user: user);
        _persist(user);
        return true;
      }

      state = state.copyWith(isBusy: false);
      return true;
    } on Object catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
      return false;
    }
  }

  Future<bool> requestOtp(String phone) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await _repo.requestOtp(phone);
      state = state.copyWith(isBusy: false);
      return true;
    } on Object catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp({required String phone, required String otp}) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _repo.verifyOtp(phone: phone, otp: otp);
      state = AuthState(user: user);
      _persist(user);
      return true;
    } on Object catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register({
    required String phone,
    required String displayName,
  }) async {
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final user = await _repo.registerWithPhone(
        phone: phone,
        displayName: displayName,
      );
      state = AuthState(user: user);
      _persist(user);
      return true;
    } on Object catch (e) {
      state = state.copyWith(isBusy: false, error: e.toString());
      return false;
    }
  }

  /// สลับเป็นโหมดนักหิ้ว (ผู้ใช้คนเดิม ไม่ต้องสมัครใหม่)
  void enableCarrierMode() {
    final user = state.user;
    if (user == null) return;
    final next = user.copyWith(isCarrier: true);
    state = state.copyWith(user: next);
    _persist(next);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthState();
    _persist(null);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authControllerProvider).user,
);

final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).isLoggedIn,
);
