import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/storage/local_store.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // เปิดที่เก็บก่อนสร้างแอป แล้วยัดเข้า provider ทีเดียว
  // ทำแบบนี้เพื่อให้ Notifier.build() ยังเป็น sync อ่านค่าที่เซฟไว้ได้ทันที
  // ไม่ต้องเปลี่ยนทุกหน้าจอไปรอ AsyncValue
  final store = await LocalStore.open();

  runApp(
    ProviderScope(
      overrides: [localStoreProvider.overrideWithValue(store)],
      child: const HiewDeeApp(),
    ),
  );
}

class HiewDeeApp extends ConsumerWidget {
  const HiewDeeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'HiewDee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
