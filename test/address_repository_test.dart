import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/address/data/address_repository.dart';
import 'package:hiewdee/features/address/domain/address.dart';

Address makeAddress(String id, {bool isDefault = false}) => Address(
      id: id,
      receiverName: 'ผู้รับ $id',
      phone: '0812345678',
      provinceCode: 10,
      provinceName: 'กรุงเทพมหานคร',
      districtCode: 1001,
      districtName: 'พระนคร',
      subdistrictCode: 100101,
      subdistrictName: 'พระบรมมหาราชวัง',
      postalCode: 10200,
      line1: '99/1',
      isDefault: isDefault,
    );

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  AddressNotifier notifier() =>
      container.read(addressListProvider.notifier);

  test('ยังไม่มีที่อยู่ → defaultAddressProvider เป็น null', () {
    expect(container.read(defaultAddressProvider), isNull);
  });

  test('ที่อยู่แรกที่เพิ่มกลายเป็นค่าเริ่มต้นเสมอ', () {
    notifier().upsert(makeAddress('a1'));

    expect(container.read(defaultAddressProvider)?.id, 'a1');
    expect(container.read(addressListProvider).single.isDefault, isTrue);
  });

  test('ตั้งค่าเริ่มต้นใหม่แล้วอันเก่าต้องถูกยกเลิก', () {
    notifier()
      ..upsert(makeAddress('a1'))
      ..upsert(makeAddress('a2'));

    notifier().setDefault('a2');

    final list = container.read(addressListProvider);
    expect(list.firstWhere((a) => a.id == 'a1').isDefault, isFalse);
    expect(list.firstWhere((a) => a.id == 'a2').isDefault, isTrue);
    expect(list.where((a) => a.isDefault).length, 1);
  });

  test('เพิ่มที่อยู่ใหม่พร้อมติ๊กเป็นค่าเริ่มต้น ต้องย้ายค่าเริ่มต้นมาให้', () {
    notifier()
      ..upsert(makeAddress('a1'))
      ..upsert(makeAddress('a2', isDefault: true));

    expect(container.read(defaultAddressProvider)?.id, 'a2');
    expect(
      container.read(addressListProvider).where((a) => a.isDefault).length,
      1,
    );
  });

  test('แก้ไขที่อยู่เดิมต้องไม่เพิ่มรายการซ้ำ', () {
    notifier().upsert(makeAddress('a1'));
    notifier().upsert(makeAddress('a1').copyWith(receiverName: 'ชื่อใหม่'));

    final list = container.read(addressListProvider);
    expect(list.length, 1);
    expect(list.single.receiverName, 'ชื่อใหม่');
  });

  test('ลบที่อยู่ที่เป็นค่าเริ่มต้น → อันที่เหลือถูกเลื่อนขึ้นมาแทน', () {
    notifier()
      ..upsert(makeAddress('a1'))
      ..upsert(makeAddress('a2'));

    notifier().remove('a1');

    expect(container.read(addressListProvider).length, 1);
    expect(container.read(defaultAddressProvider)?.id, 'a2');
    expect(container.read(defaultAddressProvider)?.isDefault, isTrue);
  });

  test('ลบหมดแล้วกลับไปเป็นไม่มีที่อยู่', () {
    notifier().upsert(makeAddress('a1'));
    notifier().remove('a1');

    expect(container.read(addressListProvider), isEmpty);
    expect(container.read(defaultAddressProvider), isNull);
  });

  test('fullLine ประกอบที่อยู่ตามรูปแบบไทย', () {
    expect(
      makeAddress('a1').fullLine,
      '99/1 ต.พระบรมมหาราชวัง อ.พระนคร จ.กรุงเทพมหานคร 10200',
    );
  });
}
