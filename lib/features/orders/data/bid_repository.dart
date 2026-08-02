import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../payments/domain/funding_policy.dart';
import '../domain/bid.dart';

/// ข้อเสนอรับหิ้วทั้งหมด — ตอนนี้อยู่ในหน่วยความจำ
class BidNotifier extends Notifier<List<Bid>> {
  @override
  List<Bid> build() => _seed();

  void submit(Bid bid) => state = [bid, ...state];

  /// ผู้ฝากรับข้อเสนอใบหนึ่ง — ใบที่เหลือของคำขอนั้นตกไปโดยอัตโนมัติ
  /// (คำขอหนึ่งใบมีนักหิ้วได้คนเดียว ไม่งั้นของจะมาซ้ำ)
  void accept(String bidId) {
    final target = byId(bidId);
    if (target == null) return;

    state = [
      for (final b in state)
        if (b.id == bidId)
          b.copyWith(status: BidStatus.accepted)
        else if (b.requestId == target.requestId && b.isOpen)
          b.copyWith(status: BidStatus.rejected)
        else
          b,
    ];
  }

  void withdraw(String bidId) => state = [
        for (final b in state)
          b.id == bidId ? b.copyWith(status: BidStatus.withdrawn) : b,
      ];

  Bid? byId(String id) {
    for (final b in state) {
      if (b.id == id) return b;
    }
    return null;
  }

  static List<Bid> _seed() {
    final now = DateTime.now();
    DateTime inDays(int d) => now.add(Duration(days: d));
    DateTime agoHours(int h) => now.subtract(Duration(hours: h));

    return [
      Bid(
        id: 'b1',
        requestId: 'r1',
        carrierName: 'ปาล์ม',
        carrierTier: CarrierTier.trusted,
        merchant: const MerchantProfile.onlineStore(name: 'Rakuten'),
        carrierRating: 4.9,
        completedTrips: 47,
        serviceFeeTHB: 780,
        deliverBy: inDays(11),
        note: 'บินโตเกียวอยู่แล้ว แวะ Matsumoto Kiyoshi ให้ได้ '
            'ซื้อที่ร้าน Tax-Free ประหยัดได้อีก 10%',
        createdAt: agoHours(1),
      ),
      Bid(
        id: 'b2',
        requestId: 'r1',
        carrierName: 'มิ้นท์',
        carrierTier: CarrierTier.banked,
        merchant: const MerchantProfile.physicalWithCard(
          name: 'Matsumoto Kiyoshi',
        ),
        carrierRating: 4.6,
        completedTrips: 12,
        serviceFeeTHB: 850,
        deliverBy: inDays(9),
        note: 'รับได้เลยค่ะ กลับวันที่ 9 ส่งต่อทันที',
        createdAt: agoHours(3),
      ),
      Bid(
        id: 'b3',
        requestId: 'r1',
        carrierName: 'เจ',
        carrierTier: CarrierTier.identified,
        merchant: const MerchantProfile.physicalWithCard(name: 'Don Quijote'),
        carrierRating: 4.2,
        completedTrips: 3,
        serviceFeeTHB: 690,
        deliverBy: inDays(14),
        note: 'เพิ่งเริ่มรับหิ้ว ขอราคาถูกหน่อยเพื่อเก็บรีวิวครับ',
        createdAt: agoHours(6),
      ),
      Bid(
        id: 'b4',
        requestId: 'r2',
        carrierName: 'ต่าย',
        carrierTier: CarrierTier.banked,
        merchant: const MerchantProfile.physicalWithCard(name: 'POP MART'),
        carrierRating: 4.8,
        completedTrips: 21,
        serviceFeeTHB: 600,
        deliverBy: inDays(2),
        note: 'อยู่เซี่ยงไฮ้ ไป POP MART ได้ทุกวัน ถ่ายคลิปตอนสุ่มให้ดูด้วย',
        createdAt: agoHours(2),
      ),
      Bid(
        id: 'b5',
        requestId: 'r4',
        carrierName: 'ก้อง',
        carrierTier: CarrierTier.trusted,
        merchant: const MerchantProfile.onlineStore(name: 'Yodobashi.com'),
        carrierRating: 5.0,
        completedTrips: 88,
        serviceFeeTHB: 1200,
        deliverBy: inDays(16),
        note: 'ซื้อที่ Yodobashi อุเมดะ ได้ใบเสร็จเต็มรูปแบบสำหรับเคลมประกัน',
        createdAt: agoHours(10),
      ),
    ];
  }
}

final bidListProvider =
    NotifierProvider<BidNotifier, List<Bid>>(BidNotifier.new);

/// ข้อเสนอของคำขอหนึ่งใบ เรียงถูกที่สุดขึ้นก่อน
final bidsForRequestProvider = Provider.family<List<Bid>, String>((ref, id) {
  final bids = ref
      .watch(bidListProvider)
      .where((b) => b.requestId == id && b.status != BidStatus.withdrawn)
      .toList()
    ..sort((a, b) => a.serviceFeeTHB.compareTo(b.serviceFeeTHB));
  return bids;
});

final bidByIdProvider = Provider.family<Bid?, String>((ref, id) {
  for (final b in ref.watch(bidListProvider)) {
    if (b.id == id) return b;
  }
  return null;
});
