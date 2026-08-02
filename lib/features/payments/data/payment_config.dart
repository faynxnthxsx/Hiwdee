/// ค่าตั้งต้นของระบบรับชำระเงิน
///
/// อ่านจาก `--dart-define` ไม่ใช่จากไฟล์ในโปรเจกต์ เพื่อไม่ให้ key
/// หลุดเข้า git ตอนเผลอ commit
///
/// เปิดโหมดของจริง:
/// ```
/// flutter run -d chrome \
///   --dart-define=OPN_PUBLIC_KEY=pkey_test_xxxxx \
///   --dart-define=PAYMENT_API_BASE=http://localhost:8080
/// ```
///
/// ไม่ใส่อะไรเลย = ใช้ตัวจำลอง แอปยังเล่นได้ครบทุก flow
abstract final class PaymentConfig {
  /// public key ของ Opn — อยู่ในแอปได้ ใช้แลก token เท่านั้น
  static const publicKey = String.fromEnvironment('OPN_PUBLIC_KEY');

  /// URL ของ backend ที่ถือ secret key ไว้สร้าง charge
  ///
  /// **ห้ามใส่ secret key ในแอปเด็ดขาด** ใครเปิด DevTools ก็เห็น
  /// แล้วสั่งตัดเงินในนามคุณได้
  static const apiBase = String.fromEnvironment('PAYMENT_API_BASE');

  /// ต่อของจริงได้ก็ต่อเมื่อมีครบทั้งสองอย่าง
  static bool get isLive => publicKey.isNotEmpty && apiBase.isNotEmpty;

  /// key ของ Opn ขึ้นต้นด้วย pkey_test_ ตอนอยู่ใน sandbox
  static bool get isTestKey => publicKey.startsWith('pkey_test_');

  static const vaultUrl = 'https://vault.omise.co/tokens';
}
