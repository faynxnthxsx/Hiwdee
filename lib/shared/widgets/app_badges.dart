import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/request/domain/haul_request.dart';

/// ป้ายบอกว่าเป็นของนอกหรือของในประเทศ
class OriginBadge extends StatelessWidget {
  const OriginBadge({super.key, required this.type, required this.place});

  final OriginType type;
  final String place;

  @override
  Widget build(BuildContext context) {
    final color =
        type == OriginType.abroad ? AppColors.abroad : AppColors.domestic;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            type == OriginType.abroad ? Icons.flight_takeoff : Icons.place,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            place,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class UrgentBadge extends StatelessWidget {
  const UrgentBadge({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// รูปสินค้าแบบ placeholder — ใช้อีโมจิตามหมวด จะได้ไม่ต้องพึ่งเน็ต
class CategoryThumb extends StatelessWidget {
  const CategoryThumb({super.key, required this.category, this.size = 76});

  final HaulCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      alignment: Alignment.center,
      child: Text(category.emoji, style: TextStyle(fontSize: size * 0.42)),
    );
  }
}

class RatingChip extends StatelessWidget {
  const RatingChip({super.key, required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: AppColors.warning),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 3),
        Text(
          '($count)',
          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
        ),
      ],
    );
  }
}

class VerifiedChip extends StatelessWidget {
  const VerifiedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: AppColors.success),
          SizedBox(width: 3),
          Text(
            'ยืนยันตัวตนแล้ว',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
