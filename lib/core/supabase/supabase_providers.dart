import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/media_store.dart';
import 'supabase_config.dart';
import 'supabase_media_store.dart';

/// client ของ Supabase — null เมื่อยังไม่ได้ตั้งค่า
///
/// ถูก override ใน `main()` หลัง `Supabase.initialize` สำเร็จ
/// ค่าเริ่มต้นเป็น null เพื่อให้เทสต์ไม่ต้อง mock อะไรเลย
/// (แบบเดียวกับ `localStoreProvider`)
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);

/// ต่อ Supabase อยู่จริงไหม
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(supabaseClientProvider) != null,
);

final mediaStoreProvider = Provider<MediaStore>((ref) {
  assert(
    !SupabaseConfig.hasServiceKeyByMistake,
    'SUPABASE_ANON_KEY ได้รับ service_role key มา ซึ่งข้ามผ่าน RLS ทั้งหมด\n'
    'ไปเอา anon/public key จาก Supabase → Settings → API มาใส่แทน',
  );

  final client = ref.watch(supabaseClientProvider);
  if (client == null) return const MemoryMediaStore();
  return SupabaseMediaStore(client);
});
