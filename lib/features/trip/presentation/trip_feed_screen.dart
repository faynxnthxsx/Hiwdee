import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/auth_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_badges.dart';
import '../data/trip_repository.dart';
import '../domain/trip.dart';

/// ทริปของนักหิ้ว — guest ดูได้ กด "ฝากของ" ถึงจะเด้งล็อกอิน
class TripFeedScreen extends ConsumerWidget {
  const TripFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(sortedTripsProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      appBar: AppBar(
        title: const Text('ทริปนักหิ้ว'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.ensureCarrier(
              context,
              reason: 'เข้าสู่ระบบเพื่อประกาศทริปของคุณ',
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('ลงทริป'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: trips.length,
        itemBuilder: (context, i) => _TripCard(trip: trips[i]),
      ),
    );
  }
}

class _TripCard extends ConsumerWidget {
  const _TripCard({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.brandSoft,
                child: Text(
                  trip.carrierName.characters.first,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          trip.carrierName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        if (trip.isVerified) const VerifiedChip(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    RatingChip(
                      rating: trip.carrierRating,
                      count: trip.carrierReviewCount,
                    ),
                  ],
                ),
              ),
              Text(
                '${Fmt.baht(trip.feePerKg)}/กก.',
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.flight_takeoff,
                  size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${trip.fromPlace}  →  ${trip.toPlace}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event, size: 18, color: AppColors.inkMuted),
              const SizedBox(width: 8),
              Text(
                Fmt.dateRange(trip.departAt, trip.returnAt),
                style: const TextStyle(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _capacityBar(),
          if (trip.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              trip.note,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.inkMuted,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: trip.isAcceptingNow
                  ? () => _requestHaul(context, ref)
                  : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
              child: Text(
                trip.isFull
                    ? 'เต็มแล้ว'
                    : (trip.isAcceptingNow ? 'ฝากหิ้วกับทริปนี้' : 'ปิดรับแล้ว'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _capacityBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'พื้นที่คงเหลือ',
              style: TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
            const Spacer(),
            Text(
              '${trip.remainingKg.toStringAsFixed(1)} / '
              '${trip.capacityKg.toStringAsFixed(0)} กก.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: trip.fillRatio,
            minHeight: 6,
            backgroundColor: AppColors.line,
            valueColor: AlwaysStoppedAnimation(
              trip.isFull ? AppColors.danger : AppColors.success,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _requestHaul(BuildContext context, WidgetRef ref) async {
    final address = await ref.ensureAddress(
      context,
      reason: 'เข้าสู่ระบบเพื่อฝากหิ้วกับ${trip.carrierName}',
    );
    if (address == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ส่งคำขอไปที่${trip.carrierName}แล้ว '
            'จัดส่งไปที่ ${address.subdistrictName} ${address.provinceName}'),
      ),
    );
  }
}
