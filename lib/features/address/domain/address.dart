/// ที่อยู่จัดส่ง — โครงเดียวกับที่ Shopee/Lazada เก็บ
class Address {
  const Address({
    required this.id,
    required this.receiverName,
    required this.phone,
    required this.provinceCode,
    required this.provinceName,
    required this.districtCode,
    required this.districtName,
    required this.subdistrictCode,
    required this.subdistrictName,
    required this.postalCode,
    required this.line1,
    this.note = '',
    this.label = AddressLabel.home,
    this.isDefault = false,
  });

  final String id;
  final String receiverName;
  final String phone;

  final int provinceCode;
  final String provinceName;
  final int districtCode;
  final String districtName;
  final int subdistrictCode;
  final String subdistrictName;
  final int postalCode;

  /// บ้านเลขที่ / หมู่ / ซอย / ถนน
  final String line1;

  /// หมายเหตุถึงคนส่ง เช่น "ฝากไว้ที่นิติ"
  final String note;

  final AddressLabel label;
  final bool isDefault;

  /// บรรทัดเดียวแบบเต็ม สำหรับโชว์ในการ์ด
  String get fullLine =>
      '$line1 ต.$subdistrictName อ.$districtName จ.$provinceName $postalCode';

  /// เฉพาะส่วนเขตการปกครอง สำหรับโชว์ใต้ช่องเลือก
  String get areaLine =>
      '$subdistrictName, $districtName, $provinceName, $postalCode';

  Address copyWith({
    String? receiverName,
    String? phone,
    int? provinceCode,
    String? provinceName,
    int? districtCode,
    String? districtName,
    int? subdistrictCode,
    String? subdistrictName,
    int? postalCode,
    String? line1,
    String? note,
    AddressLabel? label,
    bool? isDefault,
  }) {
    return Address(
      id: id,
      receiverName: receiverName ?? this.receiverName,
      phone: phone ?? this.phone,
      provinceCode: provinceCode ?? this.provinceCode,
      provinceName: provinceName ?? this.provinceName,
      districtCode: districtCode ?? this.districtCode,
      districtName: districtName ?? this.districtName,
      subdistrictCode: subdistrictCode ?? this.subdistrictCode,
      subdistrictName: subdistrictName ?? this.subdistrictName,
      postalCode: postalCode ?? this.postalCode,
      line1: line1 ?? this.line1,
      note: note ?? this.note,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

enum AddressLabel {
  home('บ้าน'),
  work('ที่ทำงาน'),
  other('อื่นๆ');

  const AddressLabel(this.text);
  final String text;
}
