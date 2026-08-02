/// ค่าตั้งต้นของ Supabase
///
/// อ่านจาก `--dart-define` เหมือนฝั่งการชำระเงิน เพื่อไม่ให้ key เข้า git
/// ใส่ใน `env.json` แล้วรันด้วย `--dart-define-from-file=env.json`
///
/// ไม่ใส่ = แอปทำงานแบบออฟไลน์ด้วย repository ในหน่วยความจำ ครบทุก flow
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');

  /// **anon key เท่านั้น** — ตัวนี้อยู่ในแอปได้โดยตั้งใจ
  ///
  /// ความปลอดภัยของ Supabase ไม่ได้มาจากการซ่อน key แต่มาจาก **RLS**
  /// ที่บังคับกฎรายแถวในฐานข้อมูล anon key ที่ไม่มี RLS คุ้มกัน = เปิดทั้งตาราง
  /// ดังนั้นทุกตารางใน `supabase/migrations/` จึงเปิด RLS ไว้หมด
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// ถังเก็บรูปหลักฐานและรูปในแชท
  static const mediaBucket = 'order-media';

  /// service_role key ข้ามผ่าน RLS ทั้งหมด — อยู่ในแอปไม่ได้เด็ดขาด
  ///
  /// ใครได้ไปก็อ่านและแก้ข้อมูลทุกแถวของทุกคนได้ กันไว้เหมือนที่กัน
  /// secret key ของ Opn
  static bool get hasServiceKeyByMistake =>
      anonKey.contains('service_role') || anonKey.startsWith('sbp_');

  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty && !hasServiceKeyByMistake;
}
