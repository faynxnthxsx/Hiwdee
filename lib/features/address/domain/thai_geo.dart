/// หนึ่งแถวจาก assets/data/thai_geo.json (จังหวัด > อำเภอ > ตำบล + ไปรษณีย์)
class GeoRow {
  const GeoRow({
    required this.provinceCode,
    required this.provinceNameTh,
    required this.districtCode,
    required this.districtNameTh,
    required this.subdistrictCode,
    required this.subdistrictNameTh,
    required this.postalCode,
  });

  final int provinceCode;
  final String provinceNameTh;
  final int districtCode;
  final String districtNameTh;
  final int subdistrictCode;
  final String subdistrictNameTh;
  final int postalCode;

  factory GeoRow.fromJson(Map<String, dynamic> json) => GeoRow(
        provinceCode: json['provinceCode'] as int,
        provinceNameTh: json['provinceNameTh'] as String,
        districtCode: json['districtCode'] as int,
        districtNameTh: json['districtNameTh'] as String,
        subdistrictCode: json['subdistrictCode'] as int,
        subdistrictNameTh: json['subdistrictNameTh'] as String,
        postalCode: json['postalCode'] as int,
      );
}

class Province {
  const Province({required this.code, required this.nameTh});
  final int code;
  final String nameTh;
}

class District {
  const District({
    required this.code,
    required this.nameTh,
    required this.provinceCode,
  });
  final int code;
  final String nameTh;
  final int provinceCode;
}

class Subdistrict {
  const Subdistrict({
    required this.code,
    required this.nameTh,
    required this.districtCode,
    required this.postalCode,
  });
  final int code;
  final String nameTh;
  final int districtCode;
  final int postalCode;
}
