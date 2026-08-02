/// ค่าตั้งต้นของระบบรับชำระเงิน
///
/// อ่านจาก `--dart-define` ไม่ใช่จากไฟล์ในโปรเจกต์ เพื่อไม่ให้ key
/// หลุดเข้า git ตอนเผลอ commit
///
/// วิธีใส่ค่า — ก๊อป `env.example.json` เป็น `env.json` (ถูก gitignore ไว้แล้ว)
/// ใส่ค่าจริง แล้วรัน:
/// ```
/// flutter run -d chrome --dart-define-from-file=env.json
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

  /// เผลอเอา secret key มาใส่ช่อง public key
  ///
  /// เป็นความผิดพลาดที่เกิดง่ายมากเพราะ key สองตัวหน้าตาคล้ายกัน
  /// ต่างกันแค่คำนำหน้า ถ้าปล่อยผ่าน secret key จะถูกคอมไพล์ฝังเข้าไปในแอป
  /// แล้วใครก็เปิดดูได้ จึงกันไว้ตรงนี้แล้วถอยไปใช้ตัวจำลองแทน
  static bool get hasSecretKeyByMistake => publicKey.startsWith('skey_');

  /// ต่อของจริงได้ก็ต่อเมื่อมีครบและเป็น key ถูกประเภท
  static bool get isLive =>
      publicKey.isNotEmpty && apiBase.isNotEmpty && !hasSecretKeyByMistake;

  /// key ของ Opn ขึ้นต้นด้วย pkey_test_ ตอนอยู่ใน sandbox
  static bool get isTestKey => publicKey.startsWith('pkey_test_');

  static const vaultUrl = 'https://vault.omise.co/tokens';
}
