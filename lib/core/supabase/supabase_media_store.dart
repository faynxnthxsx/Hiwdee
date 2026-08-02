import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/media_store.dart';
import 'supabase_config.dart';

/// เก็บไฟล์บน Supabase Storage
///
/// ถังถูกตั้งเป็น public อ่านได้ แต่ **เขียนได้เฉพาะคนที่เกี่ยวข้องกับออเดอร์**
/// ตาม policy ใน `supabase/migrations/0001_init.sql`
///
/// ตั้งชื่อไฟล์เป็น `orders/<orderId>/<เวลา>-<ชื่อ>` เพื่อให้ policy
/// ตรวจสิทธิ์จากส่วนแรกของ path ได้
class SupabaseMediaStore implements MediaStore {
  const SupabaseMediaStore(this._client);

  final SupabaseClient _client;

  @override
  bool get isSimulated => false;

  @override
  Future<String> upload({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    final storage = _client.storage.from(SupabaseConfig.mediaBucket);

    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        // หลักฐานห้ามถูกเขียนทับ ไม่งั้นแก้ประวัติย้อนหลังได้
        upsert: false,
      ),
    );

    return storage.getPublicUrl(path);
  }
}
