import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/storage/local_store.dart';
import 'core/supabase/supabase_config.dart';
import 'core/supabase/supabase_providers.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // เปิดที่เก็บก่อนสร้างแอป แล้วยัดเข้า provider ทีเดียว
  // ทำแบบนี้เพื่อให้ Notifier.build() ยังเป็น sync อ่านค่าที่เซฟไว้ได้ทันที
  // ไม่ต้องเปลี่ยนทุกหน้าจอไปรอ AsyncValue
  final store = await LocalStore.open();
  final supabase = await _openSupabase();

  runApp(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(store),
        supabaseClientProvider.overrideWithValue(supabase),
      ],
      child: const HiewDeeApp(),
    ),
  );
}

/// ต่อ Supabase ถ้ามีค่าตั้งไว้ — ต่อไม่ได้ก็ไม่เป็นไร แอปถอยไปทำงานออฟไลน์
///
/// จงใจไม่ให้ล้มทั้งแอปเมื่อเน็ตมีปัญหา เพราะทุก repository มีตัวสำรอง
/// ในหน่วยความจำอยู่แล้ว ผู้ใช้ยังเปิดดูของได้
Future<SupabaseClient?> _openSupabase() async {
  if (!SupabaseConfig.isConfigured) return null;

  try {
    final instance = await Supabase.initialize(
      url: SupabaseConfig.url,
      // Supabase เปลี่ยนชื่อเรียกจาก anon key เป็น publishable key
      // ตัวเดียวกัน ค่าเดิมใช้ได้ต่อ
      publishableKey: SupabaseConfig.anonKey,
    );
    return instance.client;
  } on Object catch (e) {
    debugPrint('ต่อ Supabase ไม่ได้ ใช้โหมดออฟไลน์แทน: $e');
    return null;
  }
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
