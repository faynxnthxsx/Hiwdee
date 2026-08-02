import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/address.dart';

/// สมุดที่อยู่ของผู้ใช้ปัจจุบัน (ตอนนี้เก็บในหน่วยความจำ)
class AddressNotifier extends Notifier<List<Address>> {
  @override
  List<Address> build() => const [];

  Address? get defaultAddress {
    if (state.isEmpty) return null;
    for (final a in state) {
      if (a.isDefault) return a;
    }
    return state.first;
  }

  void upsert(Address address) {
    final next = [...state];
    final index = next.indexWhere((a) => a.id == address.id);
    if (index >= 0) {
      next[index] = address;
    } else {
      next.add(address);
    }
    state = _normalize(next, makeDefault: address.isDefault ? address.id : null);
  }

  void remove(String id) {
    final next = state.where((a) => a.id != id).toList();
    state = _normalize(next);
  }

  void setDefault(String id) => state = _normalize(state, makeDefault: id);

  /// ให้มีค่าเริ่มต้นได้แค่รายการเดียวเสมอ และถ้าไม่มีเลยให้อันแรกเป็นค่าเริ่มต้น
  List<Address> _normalize(List<Address> list, {String? makeDefault}) {
    if (list.isEmpty) return const [];
    final targetId = makeDefault ??
        (list.any((a) => a.isDefault)
            ? list.firstWhere((a) => a.isDefault).id
            : list.first.id);
    return [
      for (final a in list) a.copyWith(isDefault: a.id == targetId),
    ];
  }
}

final addressListProvider =
    NotifierProvider<AddressNotifier, List<Address>>(AddressNotifier.new);

/// ที่อยู่เริ่มต้น — null แปลว่ายังไม่เคยกรอก (ต้องเด้งฟอร์มก่อนสั่ง)
final defaultAddressProvider = Provider<Address?>((ref) {
  final list = ref.watch(addressListProvider);
  if (list.isEmpty) return null;
  for (final a in list) {
    if (a.isDefault) return a;
  }
  return list.first;
});
