import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auth_required_view.dart';
import '../../auth/presentation/auth_controller.dart';

/// แท็บออเดอร์ — guest เข้ามาได้ แต่ต้องล็อกอินถึงจะเห็นรายการ
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ออเดอร์ของฉัน')),
      body: isLoggedIn
          ? const EmptyState(
              icon: Icons.inbox_outlined,
              message: 'ยังไม่มีออเดอร์\nลองฝากหิ้วของสักชิ้นดูสิ',
            )
          : const AuthRequiredView(
              icon: Icons.receipt_long_outlined,
              title: 'ดูออเดอร์ของคุณ',
              message: 'เข้าสู่ระบบเพื่อติดตามสถานะของที่ฝากหิ้ว '
                  'และงานที่รับหิ้วไว้',
              reason: 'เข้าสู่ระบบเพื่อดูออเดอร์',
            ),
    );
  }
}
