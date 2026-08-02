import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';

/// เปิดโหมดนักหิ้ว — ผู้ใช้คนเดิม ไม่ต้องสมัครบัญชีใหม่
/// (แบบเดียวกับที่ Shopee ให้กดเปิดร้านจากบัญชีผู้ซื้อ)
class CarrierOnboardScreen extends ConsumerWidget {
  const CarrierOnboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('เปิดโหมดนักหิ้ว')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Icon(Icons.card_travel,
                    size: 44, color: AppColors.brand),
                const SizedBox(height: 12),
                Text(
                  'สวัสดี ${user?.displayName ?? ''}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'เปลี่ยนทริปของคุณให้เป็นรายได้ '
                  'รับหิ้วของให้คนอื่นระหว่างเดินทาง',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkMuted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'สิ่งที่นักหิ้วต้องรู้',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ..._rules.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(r.$1, size: 20, color: AppColors.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.$2,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.$3,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).enableCarrierMode();
                Navigator.of(context).pop(true);
              },
              child: const Text('ยอมรับเงื่อนไข และเปิดโหมดนักหิ้ว'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ไว้ก่อน'),
            ),
          ],
        ),
      ),
    );
  }

  static const _rules = <(IconData, String, String)>[
    (
      Icons.verified_user_outlined,
      'ยืนยันตัวตนก่อนรับงานใหญ่',
      'อัปโหลดบัตรประชาชนเพื่อรับงานที่มูลค่าเกิน 5,000 บาท',
    ),
    (
      Icons.receipt_long_outlined,
      'ถ่ายหลักฐานทุกขั้นตอน',
      'สลิปตอนซื้อ รูปสินค้าจริง และรูปตอนส่งมอบ',
    ),
    (
      Icons.account_balance_wallet_outlined,
      'เงินเข้าหลังผู้ฝากกดรับของ',
      'ระบบถือเงินไว้ให้ระหว่างทาง หักค่าธรรมเนียมแพลตฟอร์ม 8%',
    ),
    (
      Icons.gavel_outlined,
      'ของต้องห้ามรับหิ้วไม่ได้',
      'ยา อาวุธ ของผิดกฎหมาย และของเกินโควตาศุลกากร',
    ),
  ];
}
