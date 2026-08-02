import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/address/data/address_repository.dart';
import '../../features/address/domain/address.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_sheet.dart';
import 'app_routes.dart';

/// ประตูกั้นก่อนทำ action ที่ต้องมีตัวตน
///
/// หัวใจของ flow แบบ guest-first: **ไม่ redirect ทั้งหน้า** แต่เด้ง sheet ขึ้นมา
/// ทำเสร็จแล้วผู้ใช้อยู่หน้าเดิม แล้ว action ที่ค้างไว้ก็ทำงานต่อทันที
extension AuthGate on WidgetRef {
  /// คืน true เมื่อผู้ใช้ล็อกอินเรียบร้อย (หรือล็อกอินอยู่แล้ว)
  Future<bool> ensureSignedIn(BuildContext context, {String? reason}) async {
    if (read(isLoggedInProvider)) return true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LoginSheet(reason: reason),
    );
    return ok ?? false;
  }

  /// ล็อกอิน + ต้องมีที่อยู่จัดส่ง — ใช้ก่อน "สั่งหิ้ว"
  /// คืน null ถ้าผู้ใช้ยกเลิกกลางทาง
  Future<Address?> ensureAddress(
    BuildContext context, {
    String? reason,
  }) async {
    if (!await ensureSignedIn(context, reason: reason)) return null;
    if (!context.mounted) return null;

    final existing = read(defaultAddressProvider);
    if (existing != null) return existing;

    // ยังไม่เคยกรอกที่อยู่ → พาไปกรอกครั้งแรก แล้วเอาผลกลับมาใช้ต่อ
    return context.push<Address>(AppRoutes.addressForm);
  }

  /// ล็อกอิน + เปิดโหมดนักหิ้ว — ใช้ก่อน "รับหิ้ว" / "เสนอราคา"
  Future<bool> ensureCarrier(BuildContext context, {String? reason}) async {
    if (!await ensureSignedIn(context, reason: reason)) return false;
    if (!context.mounted) return false;

    final user = read(currentUserProvider);
    if (user != null && user.isCarrier) return true;

    final accepted = await context.push<bool>(AppRoutes.carrierOnboard);
    return accepted ?? false;
  }
}
