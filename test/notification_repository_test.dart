import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiewdee/features/notifications/data/notification_repository.dart';
import 'package:hiewdee/features/notifications/domain/app_notification.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  NotificationNotifier notifier() =>
      container.read(notificationListProvider.notifier);

  int unread() => container.read(unreadNotificationCountProvider);

  test('ตัวนับนับเฉพาะรายการที่ยังไม่ได้อ่าน', () {
    final items = container.read(notificationListProvider);
    final expected = items.where((n) => !n.isRead).length;

    expect(unread(), expected);
    expect(unread(), lessThan(items.length), reason: 'ข้อมูลตัวอย่างต้องมีทั้งที่อ่านแล้วและยังไม่อ่าน');
  });

  test('อ่านทีละอันแล้วตัวนับลดลงทีละหนึ่ง', () {
    final target = container
        .read(notificationListProvider)
        .firstWhere((n) => !n.isRead);
    final before = unread();

    notifier().markRead(target.id);

    expect(unread(), before - 1);
    expect(
      container.read(notificationListProvider).firstWhere((n) => n.id == target.id).isRead,
      isTrue,
    );
  });

  test('อ่านอันเดิมซ้ำไม่ทำให้ตัวนับเพี้ยน', () {
    final target = container
        .read(notificationListProvider)
        .firstWhere((n) => !n.isRead);

    notifier().markRead(target.id);
    final after = unread();
    notifier().markRead(target.id);

    expect(unread(), after);
  });

  test('กด "อ่านทั้งหมด" แล้วเหลือศูนย์', () {
    notifier().markAllRead();

    expect(unread(), 0);
    expect(
      container.read(notificationListProvider).every((n) => n.isRead),
      isTrue,
    );
  });

  test('ของใหม่เข้ามาอยู่บนสุดและนับเป็นยังไม่อ่าน', () {
    notifier().markAllRead();

    notifier().add(
      AppNotification(
        id: 'n-new',
        kind: NotificationKind.bid,
        title: 'มีข้อเสนอใหม่',
        body: 'ทดสอบ',
        createdAt: DateTime.now(),
      ),
    );

    expect(container.read(notificationListProvider).first.id, 'n-new');
    expect(unread(), 1);
  });

  test('รายการที่ผูกกับคำขอถึงจะกดเข้าไปดูต่อได้', () {
    final items = container.read(notificationListProvider);

    expect(
      items.where((n) => n.isActionable).every((n) => n.requestId != null),
      isTrue,
    );
    expect(items.any((n) => n.isActionable), isTrue);
    expect(items.any((n) => !n.isActionable), isTrue);
  });
}
