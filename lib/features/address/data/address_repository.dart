import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/address.dart';

/// สมุดที่อยู่ของผู้ใช้ปัจจุบัน
class AddressNotifier extends Notifier<List<Address>> {
  @override
  List<Address> build() {
    final saved = _store?.readMaps(StoreKeys.addresses) ?? const [];
    return [for (final json in saved) Address.fromJson(json)];
  }

  LocalStore? get _store => ref.read(localStoreProvider);

  /// เขียนทุกครั้งที่ state เปลี่ยน — กติกาที่อยู่เริ่มต้นถูก normalize ไปแล้ว
  /// ตอนนี้จึงเซฟตามที่เห็นได้เลย
  void _persist() => _store?.write(
        StoreKeys.addresses,
        [for (final a in state) a.toJson()],
      );

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
    _persist();
  }

  void remove(String id) {
    final next = state.where((a) => a.id != id).toList();
    state = _normalize(next);
    _persist();
  }

  void setDefault(String id) {
    state = _normalize(state, makeDefault: id);
    _persist();
  }

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
