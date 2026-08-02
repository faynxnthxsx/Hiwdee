import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/app_notification.dart';

/// กล่องแจ้งเตือน — ตอนนี้เป็นข้อมูลตัวอย่างในหน่วยความจำ
/// เวลาคำนวณจาก "ตอนนี้" เสมอ ข้อมูลตัวอย่างจะได้ไม่ดูเก่า
/// (แบบเดียวกับ RequestNotifier — ของจริงจะมาจาก Realtime ของ Supabase)
class NotificationNotifier extends Notifier<List<AppNotification>> {
  /// เก็บแค่ "อ่านอันไหนไปแล้ว" ไม่ต้องเก็บตัวแจ้งเตือนทั้งก้อน
  /// เพราะเนื้อหาเป็นข้อมูลตัวอย่างที่สร้างใหม่ทุกครั้งอยู่แล้ว
  @override
  List<AppNotification> build() {
    final read = (_store?.readStrings(StoreKeys.readNotifications) ?? const [])
        .toSet();
    if (read.isEmpty) return _seed();

    return [
      for (final n in _seed())
        read.contains(n.id) ? n.copyWith(isRead: true) : n,
    ];
  }

  LocalStore? get _store => ref.read(localStoreProvider);

  void _persist() => _store?.writeStrings(
        StoreKeys.readNotifications,
        [
          for (final n in state)
            if (n.isRead) n.id,
        ],
      );

  void add(AppNotification n) => state = [n, ...state];

  void markRead(String id) {
    state = [
      for (final n in state) n.id == id ? n.copyWith(isRead: true) : n,
    ];
    _persist();
  }

  void markAllRead() {
    state = [
      for (final n in state) n.copyWith(isRead: true),
    ];
    _persist();
  }

  static List<AppNotification> _seed() {
    final now = DateTime.now();
    DateTime agoMin(int m) => now.subtract(Duration(minutes: m));
    DateTime agoHours(int h) => now.subtract(Duration(hours: h));
    DateTime agoDays(int d) => now.subtract(Duration(days: d));

    return [
      AppNotification(
        id: 'n1',
        kind: NotificationKind.bid,
        title: 'มีนักหิ้วเสนอราคาใหม่',
        body: 'ปาล์ม เสนอรับหิ้ว "SK-II Facial Treatment Essence 230ml" '
            'ค่าหิ้ว ฿780 · บินโตเกียว 12 ส.ค.',
        createdAt: agoMin(14),
        requestId: 'r1',
      ),
      AppNotification(
        id: 'n2',
        kind: NotificationKind.chat,
        title: 'ข้อความใหม่จากบีม',
        body: 'ที่ POP MART สาขา Global Harbor ของหมดครับ '
            'ลองสาขา Joy City ให้ไหม?',
        createdAt: agoHours(2),
        requestId: 'r2',
      ),
      AppNotification(
        id: 'n3',
        kind: NotificationKind.order,
        title: 'นักหิ้วซื้อของเรียบร้อยแล้ว',
        body: 'ไส้อั่ว + แคบหมู ร้านดำรงค์ — อัปสลิปและรูปสินค้าแล้ว '
            'กำลังส่งเข้าระบบขนส่ง',
        createdAt: agoHours(6),
        requestId: 'r3',
      ),
      AppNotification(
        id: 'n4',
        kind: NotificationKind.payout,
        title: 'เงินค่าจ้างเข้ากระเป๋าแล้ว',
        body: '฿1,104 จากออเดอร์ Sony WH-1000XM6 '
            'ถอนได้ในอีก 5 วันตามระดับความน่าเชื่อถือของคุณ',
        createdAt: agoDays(1),
      ),
      AppNotification(
        id: 'n5',
        kind: NotificationKind.system,
        title: 'สิทธิยกเว้นภาษีของทริปนี้ใกล้เต็ม',
        body: 'ใช้ไป ฿16,400 จาก ฿20,000 แล้ว '
            'ออเดอร์ถัดไปอาจต้องเสียภาษีนำเข้า ลองกดดูในเครื่องคำนวณก่อนรับงาน',
        createdAt: agoDays(2),
        isRead: true,
      ),
      AppNotification(
        id: 'n6',
        kind: NotificationKind.system,
        title: 'ยืนยันบัตรประชาชนเพื่อปลดเพดานเงินสด',
        body: 'ตอนนี้รับได้เฉพาะร้านออนไลน์กับร้านที่รับบัตร '
            'ยืนยันตัวตนแล้วจะรับงานร้านเงินสดได้ถึง ฿5,000',
        createdAt: agoDays(5),
        isRead: true,
      ),
    ];
  }
}

final notificationListProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(
  NotificationNotifier.new,
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationListProvider).where((n) => !n.isRead).length;
});
