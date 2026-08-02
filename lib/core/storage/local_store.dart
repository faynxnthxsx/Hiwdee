import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// คีย์ทั้งหมดที่เขียนลงเครื่อง รวมไว้ที่เดียวกันพิมพ์ผิด
abstract final class StoreKeys {
  static const user = 'auth.user';
  static const addresses = 'address.list';

  /// เฉพาะคำขอที่ผู้ใช้โพสต์เอง — ของตัวอย่างในฟีดไม่เก็บ
  static const myRequests = 'request.mine';

  /// เก็บแค่ id ที่อ่านแล้ว ไม่ต้องเก็บตัวแจ้งเตือนทั้งก้อน
  static const readNotifications = 'notification.read';
}

/// ที่เก็บข้อมูลบนเครื่อง หุ้ม [SharedPreferences] ไว้ชั้นหนึ่ง
///
/// เขียนแบบ fire-and-forget โดยตั้งใจ — `SharedPreferences` อัปเดตแคชใน
/// หน่วยความจำทันทีแล้วค่อยลงดิสก์เอง ทำให้ `Notifier.build()` ยังเป็น sync ได้
/// ไม่ต้องเปลี่ยนทุกหน้าจอไปรอ `AsyncValue`
class LocalStore {
  const LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async =>
      LocalStore(await SharedPreferences.getInstance());

  Map<String, dynamic>? readMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    return _decode(raw) as Map<String, dynamic>?;
  }

  List<Map<String, dynamic>> readMaps(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return const [];
    final decoded = _decode(raw);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  List<String> readStrings(String key) =>
      _prefs.getStringList(key) ?? const [];

  void write(String key, Object value) =>
      unawaited(_prefs.setString(key, jsonEncode(value)));

  void writeStrings(String key, List<String> values) =>
      unawaited(_prefs.setStringList(key, values));

  void remove(String key) => unawaited(_prefs.remove(key));

  /// ข้อมูลที่เขียนไว้ด้วยเวอร์ชันเก่าอาจอ่านไม่ออก — ปล่อยให้กลับไปเป็นค่าว่าง
  /// ดีกว่าทำแอปพังตอนเปิด
  static Object? _decode(String raw) {
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }
}

/// null = ไม่มีที่เก็บ (เทสต์และตอน preview)
///
/// ทุก notifier ต้องทำงานได้ปกติเมื่อค่านี้เป็น null — เทสต์ทั้งหมดจึงไม่ต้อง
/// mock อะไรเลย และไม่มีสถานะค้างข้ามเคส
final localStoreProvider = Provider<LocalStore?>((ref) => null);
