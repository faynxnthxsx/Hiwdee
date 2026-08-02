import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'media_store.dart';

/// รูปที่ผู้ใช้เพิ่งเลือกหรือถ่าย พร้อมอัปโหลด
class PickedPhoto {
  const PickedPhoto({
    required this.bytes,
    required this.name,
    required this.origin,
  });

  final Uint8List bytes;
  final String name;
  final ImageOrigin origin;

  int get sizeKB => (bytes.lengthInBytes / 1024).round();
}

/// หุ้ม image_picker ไว้ชั้นหนึ่ง
///
/// มีอยู่เพื่อบังคับกติกาข้อเดียวให้อยู่ที่เดียว: **หลักฐานต้องมาจากกล้อง**
/// ถ้าปล่อยให้แต่ละหน้าจอเรียก image_picker เอง สักวันจะมีคนเผลอเปิด
/// gallery ให้หน้าอัปสลิป แล้วระบบหลักฐานทั้งระบบก็หมดความหมาย
abstract final class PhotoPicker {
  static final _picker = ImagePicker();

  /// ย่อก่อนอัปโหลด — รูปจากกล้องมือถือมักใหญ่หลายเมกะไบต์
  /// ซึ่งเปลืองทั้งเน็ตของผู้ใช้และพื้นที่เก็บ
  static const _maxWidth = 1600.0;
  static const _quality = 82;

  static Future<PickedPhoto?> pick(ImageOrigin origin) async {
    final file = await _picker.pickImage(
      source: switch (origin) {
        ImageOrigin.camera => ImageSource.camera,
        ImageOrigin.gallery => ImageSource.gallery,
      },
      maxWidth: _maxWidth,
      imageQuality: _quality,
    );
    if (file == null) return null;

    return PickedPhoto(
      bytes: await file.readAsBytes(),
      name: file.name,
      origin: origin,
    );
  }

  /// ใช้กับหลักฐานการซื้อและหลักฐานการส่ง — ไม่มีทางเลือกอื่นโดยตั้งใจ
  static Future<PickedPhoto?> captureEvidence() => pick(ImageOrigin.camera);
}
