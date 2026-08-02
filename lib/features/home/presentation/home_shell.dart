import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// โครงหลักของแอป — แถบล่าง 4 แท็บ
/// guest กดได้ทุกแท็บ แท็บที่ต้องมีตัวตนจะโชว์ปุ่มชวนล็อกอินข้างใน
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        indicatorColor: AppColors.brandSoft,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.brand),
            label: 'หน้าแรก',
          ),
          const NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff, color: AppColors.brand),
            label: 'ทริป',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppColors.brand),
            label: 'ออเดอร์',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: !isLoggedIn,
              backgroundColor: AppColors.brand,
              smallSize: 8,
              child: const Icon(Icons.person_outline),
            ),
            selectedIcon: const Icon(Icons.person, color: AppColors.brand),
            label: 'ฉัน',
          ),
        ],
      ),
    );
  }
}
