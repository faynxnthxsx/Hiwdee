import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/thai_geo.dart';

/// อ่านข้อมูลเขตการปกครองไทยทั้งประเทศ (7,436 ตำบล) จาก asset
/// แล้วทำ index ไว้ในหน่วยความจำ เพื่อให้ค้นหาแบบ cascading ได้ทันที
class ThaiGeoRepository {
  ThaiGeoRepository(this._rows) {
    for (final row in _rows) {
      _provinces.putIfAbsent(
        row.provinceCode,
        () => Province(code: row.provinceCode, nameTh: row.provinceNameTh),
      );
      _districts.putIfAbsent(
        row.districtCode,
        () => District(
          code: row.districtCode,
          nameTh: row.districtNameTh,
          provinceCode: row.provinceCode,
        ),
      );
      _subdistricts.putIfAbsent(
        row.subdistrictCode,
        () => Subdistrict(
          code: row.subdistrictCode,
          nameTh: row.subdistrictNameTh,
          districtCode: row.districtCode,
          postalCode: row.postalCode,
        ),
      );
    }
  }

  final List<GeoRow> _rows;
  final _provinces = <int, Province>{};
  final _districts = <int, District>{};
  final _subdistricts = <int, Subdistrict>{};

  static Future<ThaiGeoRepository> load() async {
    final raw = await rootBundle.loadString('assets/data/thai_geo.json');
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => GeoRow.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return ThaiGeoRepository(list);
  }

  /// กรุงเทพฯ ขึ้นก่อน แล้วเรียงตามตัวอักษรไทย (เหมือนช้อปปี้)
  List<Province> provinces({String query = ''}) {
    final all = _provinces.values.where((p) => _match(p.nameTh, query)).toList()
      ..sort((a, b) {
        if (a.code == _bangkokCode) return -1;
        if (b.code == _bangkokCode) return 1;
        return a.nameTh.compareTo(b.nameTh);
      });
    return all;
  }

  List<District> districtsOf(int provinceCode, {String query = ''}) {
    final all = _districts.values
        .where((d) => d.provinceCode == provinceCode && _match(d.nameTh, query))
        .toList()
      ..sort((a, b) => a.nameTh.compareTo(b.nameTh));
    return all;
  }

  List<Subdistrict> subdistrictsOf(int districtCode, {String query = ''}) {
    final all = _subdistricts.values
        .where((s) => s.districtCode == districtCode && _match(s.nameTh, query))
        .toList()
      ..sort((a, b) => a.nameTh.compareTo(b.nameTh));
    return all;
  }

  Province? province(int code) => _provinces[code];
  District? district(int code) => _districts[code];
  Subdistrict? subdistrict(int code) => _subdistricts[code];

  static const _bangkokCode = 10;

  static bool _match(String value, String query) =>
      query.isEmpty || value.contains(query.trim());
}

/// โหลดครั้งเดียวแล้ว cache ไว้ตลอดอายุแอป
final thaiGeoRepositoryProvider = FutureProvider<ThaiGeoRepository>(
  (ref) => ThaiGeoRepository.load(),
);
