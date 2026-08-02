import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// ที่มาของรูป — สำคัญกว่าที่คิดสำหรับแอปนี้
///
/// หลักฐานการซื้อต้องบังคับ [camera] เท่านั้น เลือกจากแกลเลอรีไม่ได้
/// เพราะรูปจากแกลเลอรีอาจเป็นรูปที่โหลดมาจากอินเทอร์เน็ตหรือของออเดอร์อื่น
/// ซึ่งทำให้ "หลักฐาน" ไม่มีความหมายเลย
/// (ตรงกับมาตรการใน FundingPolicy.controls ที่เขียนไว้ว่า
/// "ถ่ายจากกล้องในแอปเท่านั้น เลือกจากแกลเลอรีไม่ได้")
enum ImageOrigin { camera, gallery }

/// สัญญาของที่เก็บไฟล์
abstract interface class MediaStore {
  /// true = เก็บในหน่วยความจำ หายเมื่อปิดแอป
  bool get isSimulated;

  /// คืน URL ที่เอาไปโชว์ได้ทันที
  Future<String> upload({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/jpeg',
  });
}

/// เก็บในหน่วยความจำ ใช้ตอนยังไม่ได้ต่อ Supabase Storage
///
/// คืนเป็น data URL เพื่อให้ [AppImage] แสดงผลได้เหมือน URL จริงทุกประการ
/// UI จึงไม่ต้องรู้เลยว่ากำลังใช้ของจำลองหรือของจริง
class MemoryMediaStore implements MediaStore {
  const MemoryMediaStore();

  @override
  bool get isSimulated => true;

  @override
  Future<String> upload({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/jpeg',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return 'data:$contentType;base64,${base64Encode(bytes)}';
  }
}

/// แสดงรูปจาก URL ที่อาจเป็น data URL หรือ URL จริงก็ได้
///
/// `Image.network` อ่าน data URL ไม่ได้บนทุกแพลตฟอร์ม จึงต้องแยกทางเอง
/// มีวิดเจ็ตตัวนี้ตัวเดียวทำให้ที่เรียกใช้ไม่ต้องสนใจว่า URL มาจากไหน
class AppImage extends StatelessWidget {
  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = url.startsWith('data:')
        ? Image.memory(
            _decodeDataUrl(url),
            width: width,
            height: height,
            fit: fit,
            errorBuilder: _fallback,
          )
        : Image.network(
            url,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: _fallback,
          );

    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }

  Widget _fallback(BuildContext _, Object _, StackTrace? _) => Container(
        width: width,
        height: height,
        color: const Color(0xFFE5E7EB),
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.white),
      );

  static Uint8List _decodeDataUrl(String url) {
    final comma = url.indexOf(',');
    if (comma < 0) return Uint8List(0);
    try {
      return base64Decode(url.substring(comma + 1));
    } on FormatException {
      return Uint8List(0);
    }
  }
}
