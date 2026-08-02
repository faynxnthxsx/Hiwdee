import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_badges.dart';
import '../../../shared/widgets/auth_required_view.dart';
import '../../auth/presentation/auth_controller.dart';

/// ระยะที่การ์ดกระเป๋าเงินทับขึ้นไปบนแถบสีแบรนด์
const _walletOverlap = 18.0;

/// แท็บ "ฉัน" — guest กดเข้ามาได้ แต่เห็นปุ่มชวนล็อกอินแทนข้อมูล
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return const Scaffold(
        body: SafeArea(
          child: AuthRequiredView(
            icon: Icons.person_outline,
            title: 'ยังไม่ได้เข้าสู่ระบบ',
            message: 'เข้าสู่ระบบเพื่อดูออเดอร์ กระเป๋าเงิน '
                'และที่อยู่จัดส่งของคุณ',
            reason: 'เข้าสู่ระบบเพื่อดูโปรไฟล์',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppColors.brand,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text(
                    user.displayName.characters.first,
                    style: const TextStyle(
                      fontSize: 24,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Fmt.maskedPhone(user.phone),
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (user.hasReviews) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: RatingChip(
                            rating: user.rating,
                            count: user.reviewCount,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ดันการ์ดขึ้นไปทับแถบสีแบรนด์ให้ดูลอยอยู่บนหัว
          //
          // ต้องใช้ Transform ไม่ใช่ margin ติดลบ — Container ยืนยันไว้ว่า
          // margin ต้องไม่ติดลบ (assert margin.isNonNegative) ใส่ค่าลบแล้ว
          // แอปพังทันทีที่เปิดแท็บนี้
          Transform.translate(
            offset: const Offset(0, -_walletOverlap),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.brand),
                  const SizedBox(width: 10),
                  const Text('กระเป๋าเงิน',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    Fmt.baht(user.walletBalance),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Transform ขยับแค่ตอนวาด ที่ทางใน layout ยังอยู่ที่เดิม
          // ระยะห่างใต้การ์ดจึงกลายเป็น _walletOverlap อยู่แล้ว ไม่ต้องเติมอีก
          _group([
            _tile(
              icon: Icons.location_on_outlined,
              title: 'ที่อยู่ของฉัน',
              onTap: () => context.push(AppRoutes.addresses),
            ),
            _tile(
              icon: Icons.receipt_long_outlined,
              title: 'ประวัติธุรกรรม',
              onTap: () {},
            ),
            _tile(
              icon: Icons.star_border,
              title: 'รีวิวที่ได้รับ',
              onTap: () {},
            ),
            _tile(
              icon: Icons.calculate_outlined,
              title: 'คำนวณค่าหิ้ว + ภาษีนำเข้า',
              onTap: () => context.push(AppRoutes.calculator),
            ),
            _tile(
              icon: Icons.menu_book_outlined,
              title: 'คู่มือภาษีสำหรับนักหิ้ว',
              subtitle: 'ประหยัดยังไงให้ถูกกฎหมาย และอะไรห้ามทำ',
              onTap: () => context.push(AppRoutes.customsGuide),
            ),
            if (user.isAdmin)
              _tile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'คิวข้อพิพาท',
                subtitle: 'ตัดสินเคสที่คู่กรณีตกลงกันไม่ได้',
                color: AppColors.danger,
                onTap: () => context.push(AppRoutes.admin),
              ),
          ]),
          const SizedBox(height: 12),
          _group([
            if (user.isCarrier)
              _tile(
                icon: Icons.card_travel,
                title: 'ทริปของฉัน',
                trailing: const Text(
                  'โหมดนักหิ้วเปิดอยู่',
                  style: TextStyle(fontSize: 12, color: AppColors.success),
                ),
                onTap: () => context.go(AppRoutes.trips),
              )
            else
              _tile(
                icon: Icons.card_travel,
                title: 'เปิดโหมดนักหิ้ว',
                subtitle: 'รับหิ้วของระหว่างเดินทาง สร้างรายได้เสริม',
                onTap: () => ref.ensureCarrier(context),
              ),
            _tile(
              icon: user.isVerified ? Icons.verified : Icons.badge_outlined,
              title: user.isVerified ? 'ยืนยันตัวตนแล้ว' : 'ยืนยันตัวตน',
              trailing: user.isVerified ? const VerifiedChip() : null,
              onTap: () {},
            ),
          ]),
          const SizedBox(height: 12),
          _group([
            _tile(
              icon: Icons.logout,
              title: 'ออกจากระบบ',
              color: AppColors.danger,
              onTap: () => ref.read(authControllerProvider.notifier).signOut(),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Material รับหน้าที่ทาสีพื้นหลังเอง เพื่อให้ ListTile ข้างในวาด
  /// ink splash ทับได้ ถ้าใช้ DecoratedBox ทึบคั่นไว้ เอฟเฟกต์จะถูกบัง
  Widget _group(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.line),
          ),
          child: Column(children: children),
        ),
      );

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    String? subtitle,
    Widget? trailing,
    Color color = AppColors.ink,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppColors.inkMuted),
      onTap: onTap,
    );
  }
}
