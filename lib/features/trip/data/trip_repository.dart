import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/trip.dart';

class TripNotifier extends Notifier<List<Trip>> {
  @override
  List<Trip> build() => _seed();

  void add(Trip trip) => state = [trip, ...state];

  static List<Trip> _seed() {
    final now = DateTime.now();
    DateTime inDays(int d) => now.add(Duration(days: d));

    return [
      Trip(
        id: 't1',
        carrierName: 'ฝ้าย',
        carrierRating: 4.9,
        carrierReviewCount: 128,
        isVerified: true,
        fromPlace: 'ญี่ปุ่น · โตเกียว',
        toPlace: 'กรุงเทพฯ',
        departAt: inDays(4),
        returnAt: inDays(11),
        capacityKg: 12,
        usedKg: 7.5,
        feePerKg: 350,
        note: 'รับหิ้วสกินแคร์ ขนม ของเล่น ไม่รับของเหลวเกิน 1 ลิตร',
      ),
      Trip(
        id: 't2',
        carrierName: 'เจ',
        carrierRating: 4.7,
        carrierReviewCount: 54,
        isVerified: true,
        fromPlace: 'เกาหลี · โซล',
        toPlace: 'กรุงเทพฯ',
        departAt: inDays(2),
        returnAt: inDays(8),
        capacityKg: 8,
        usedKg: 2,
        feePerKg: 300,
        note: 'เข้า Olive Young ทุกวัน ฝากได้เลยครับ',
      ),
      Trip(
        id: 't3',
        carrierName: 'พลอย',
        carrierRating: 5.0,
        carrierReviewCount: 31,
        isVerified: false,
        fromPlace: 'เชียงใหม่',
        toPlace: 'กรุงเทพฯ',
        departAt: inDays(1),
        returnAt: inDays(3),
        capacityKg: 15,
        usedKg: 15,
        feePerKg: 120,
        note: 'ขับรถกลับ รับของฝากได้เยอะ',
      ),
      Trip(
        id: 't4',
        carrierName: 'บอส',
        carrierRating: 4.6,
        carrierReviewCount: 88,
        isVerified: true,
        fromPlace: 'จีน · กว่างโจว',
        toPlace: 'กรุงเทพฯ',
        departAt: inDays(9),
        returnAt: inDays(16),
        capacityKg: 25,
        usedKg: 9,
        feePerKg: 220,
        note: 'ไปตลาดส่งของ รับหิ้วจำนวนมากได้',
      ),
      Trip(
        id: 't5',
        carrierName: 'มีน',
        carrierRating: 4.8,
        carrierReviewCount: 12,
        isVerified: false,
        fromPlace: 'ภูเก็ต',
        toPlace: 'กรุงเทพฯ',
        departAt: inDays(6),
        returnAt: inDays(9),
        capacityKg: 10,
        usedKg: 3,
        feePerKg: 100,
        note: 'รับของฝาก อาหารทะเลแห้ง',
      ),
    ];
  }
}

final tripListProvider =
    NotifierProvider<TripNotifier, List<Trip>>(TripNotifier.new);

/// ทริปที่ยังรับของเพิ่มได้ ขึ้นก่อน แล้วเรียงตามวันออกเดินทาง
final sortedTripsProvider = Provider<List<Trip>>((ref) {
  final trips = [...ref.watch(tripListProvider)];
  trips.sort((a, b) {
    if (a.isAcceptingNow != b.isAcceptingNow) {
      return a.isAcceptingNow ? -1 : 1;
    }
    return a.departAt.compareTo(b.departAt);
  });
  return trips;
});
