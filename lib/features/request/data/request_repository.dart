import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../domain/haul_request.dart';

/// คลังคำขอฝากหิ้ว
///
/// ข้อมูลตัวอย่างคิดวันที่จาก "ตอนนี้" เสมอ จะได้ไม่ดูเก่า — จึง **ไม่เซฟ**
/// ลงเครื่อง ไม่งั้นเวลาที่ตรึงไว้จะค้างและขัดกับเจตนาเดิม
/// ส่วนคำขอที่ผู้ใช้โพสต์เองเป็นของจริง เก็บไว้แล้วเอากลับมาต่อท้ายตอนเปิดแอป
class RequestNotifier extends Notifier<List<HaulRequest>> {
  @override
  List<HaulRequest> build() {
    final saved = _store?.readMaps(StoreKeys.myRequests) ?? const [];
    final mine = [for (final json in saved) HaulRequest.fromJson(json)];
    _mineIds = {for (final r in mine) r.id};
    return [...mine, ..._seed()];
  }

  /// id ของคำขอที่ผู้ใช้โพสต์เอง — ตัวแยกว่าอันไหนต้องเซฟ
  Set<String> _mineIds = const {};

  LocalStore? get _store => ref.read(localStoreProvider);

  void _persist() => _store?.write(
        StoreKeys.myRequests,
        [
          for (final r in state)
            if (_mineIds.contains(r.id)) r.toJson(),
        ],
      );

  void add(HaulRequest request) {
    _mineIds = {..._mineIds, request.id};
    state = [request, ...state];
    _persist();
  }

  HaulRequest? byId(String id) {
    for (final r in state) {
      if (r.id == id) return r;
    }
    return null;
  }

  void incrementBid(String id) {
    state = [
      for (final r in state)
        if (r.id == id)
          HaulRequest(
            id: r.id,
            title: r.title,
            category: r.category,
            originType: r.originType,
            originName: r.originName,
            quantity: r.quantity,
            budgetMax: r.budgetMax,
            serviceFeeOffer: r.serviceFeeOffer,
            deadline: r.deadline,
            requesterName: r.requesterName,
            createdAt: r.createdAt,
            productUrl: r.productUrl,
            note: r.note,
            bidCount: r.bidCount + 1,
            status: r.status,
          )
        else
          r,
    ];
    _persist();
  }

  static List<HaulRequest> _seed() {
    final now = DateTime.now();
    DateTime inDays(int d) => now.add(Duration(days: d));
    DateTime agoHours(int h) => now.subtract(Duration(hours: h));

    return [
      HaulRequest(
        id: 'r1',
        title: 'SK-II Facial Treatment Essence 230ml',
        category: HaulCategory.beauty,
        originType: OriginType.abroad,
        originName: 'ญี่ปุ่น · โตเกียว',
        quantity: 2,
        budgetMax: 8500,
        serviceFeeOffer: 800,
        deadline: inDays(12),
        requesterName: 'มายด์',
        createdAt: agoHours(3),
        productUrl: 'https://example.com/sk2-essence',
        note: 'ขอแบบกล่องซีล ไม่เอา tester นะคะ ถ้าลด duty free ได้จะดีมาก',
        bidCount: 4,
      ),
      HaulRequest(
        id: 'r2',
        title: 'Labubu The Monsters ซีรีส์ใหม่ (สุ่มกล่อง)',
        category: HaulCategory.collectible,
        originType: OriginType.abroad,
        originName: 'จีน · เซี่ยงไฮ้',
        quantity: 6,
        budgetMax: 4200,
        serviceFeeOffer: 600,
        deadline: inDays(2),
        requesterName: 'บีม',
        createdAt: agoHours(8),
        note: 'ขอที่ POP MART สาขาไหนก็ได้ ถ่ายรูปตอนซื้อให้ดูด้วยครับ',
        bidCount: 11,
      ),
      HaulRequest(
        id: 'r3',
        title: 'ไส้อั่ว + แคบหมู ร้านดำรงค์',
        category: HaulCategory.local,
        originType: OriginType.domestic,
        originName: 'เชียงใหม่',
        quantity: 3,
        budgetMax: 900,
        serviceFeeOffer: 250,
        deadline: inDays(5),
        requesterName: 'ต้น',
        createdAt: agoHours(20),
        note: 'ขอแบบสุญญากาศ จะได้ส่งไปรษณีย์ได้',
        bidCount: 2,
      ),
      HaulRequest(
        id: 'r4',
        title: 'Sony WH-1000XM6 หูฟังตัดเสียง',
        category: HaulCategory.gadget,
        originType: OriginType.abroad,
        originName: 'ญี่ปุ่น · โอซาก้า',
        quantity: 1,
        budgetMax: 14500,
        serviceFeeOffer: 1200,
        deadline: inDays(18),
        requesterName: 'ปอนด์',
        createdAt: agoHours(30),
        note: 'สีดำ ขอใบเสร็จด้วยครับ เผื่อเคลมประกัน',
        bidCount: 7,
      ),
      HaulRequest(
        id: 'r5',
        title: 'ครีมกันแดด Beauty of Joseon ยกเซ็ต',
        category: HaulCategory.beauty,
        originType: OriginType.abroad,
        originName: 'เกาหลี · โซล',
        quantity: 10,
        budgetMax: 3200,
        serviceFeeOffer: 500,
        deadline: inDays(7),
        requesterName: 'จูน',
        createdAt: agoHours(46),
        note: 'ซื้อที่ Olive Young ช่วงลดราคาได้ยิ่งดีค่ะ',
        bidCount: 9,
      ),
      HaulRequest(
        id: 'r6',
        title: 'กุ้งแห้งเกาะยอ + น้ำพริกปลาย่าง',
        category: HaulCategory.local,
        originType: OriginType.domestic,
        originName: 'สงขลา',
        quantity: 4,
        budgetMax: 1400,
        serviceFeeOffer: 300,
        deadline: inDays(9),
        requesterName: 'แนน',
        createdAt: agoHours(52),
        bidCount: 1,
      ),
      HaulRequest(
        id: 'r7',
        title: 'Royce Nama Chocolate 5 กล่อง',
        category: HaulCategory.snack,
        originType: OriginType.abroad,
        originName: 'ญี่ปุ่น · ฮอกไกโด',
        quantity: 5,
        budgetMax: 2600,
        serviceFeeOffer: 700,
        deadline: inDays(3),
        requesterName: 'ฟิล์ม',
        createdAt: agoHours(60),
        note: 'ต้องเก็บเย็นนะคะ ขอคนที่มีกระเป๋าเก็บความเย็น',
        bidCount: 5,
      ),
      HaulRequest(
        id: 'r8',
        title: 'เม็ดมะม่วงหิมพานต์อบเกลือ ภูเก็ต',
        category: HaulCategory.snack,
        originType: OriginType.domestic,
        originName: 'ภูเก็ต',
        quantity: 8,
        budgetMax: 1600,
        serviceFeeOffer: 350,
        deadline: inDays(14),
        requesterName: 'กิ๊ฟ',
        createdAt: agoHours(70),
        bidCount: 3,
      ),
    ];
  }
}

final requestListProvider =
    NotifierProvider<RequestNotifier, List<HaulRequest>>(RequestNotifier.new);

/// ตัวกรองฟีด
class FeedFilter {
  const FeedFilter({this.originType, this.category, this.query = ''});

  final OriginType? originType;
  final HaulCategory? category;
  final String query;

  FeedFilter copyWith({
    OriginType? originType,
    HaulCategory? category,
    String? query,
    bool clearOrigin = false,
    bool clearCategory = false,
  }) {
    return FeedFilter(
      originType: clearOrigin ? null : (originType ?? this.originType),
      category: clearCategory ? null : (category ?? this.category),
      query: query ?? this.query,
    );
  }
}

class FeedFilterNotifier extends Notifier<FeedFilter> {
  @override
  FeedFilter build() => const FeedFilter();

  void update(FeedFilter Function(FeedFilter current) transform) =>
      state = transform(state);

  /// ล้างตัวกรองแต่คงคำค้นหาไว้
  void reset() => state = FeedFilter(query: state.query);
}

final feedFilterProvider =
    NotifierProvider<FeedFilterNotifier, FeedFilter>(FeedFilterNotifier.new);

final filteredRequestsProvider = Provider<List<HaulRequest>>((ref) {
  final all = ref.watch(requestListProvider);
  final f = ref.watch(feedFilterProvider);
  final q = f.query.trim();

  return all.where((r) {
    if (f.originType != null && r.originType != f.originType) return false;
    if (f.category != null && r.category != f.category) return false;
    if (q.isNotEmpty && !r.title.contains(q) && !r.originName.contains(q)) {
      return false;
    }
    return true;
  }).toList();
});

final requestByIdProvider = Provider.family<HaulRequest?, String>((ref, id) {
  for (final r in ref.watch(requestListProvider)) {
    if (r.id == id) return r;
  }
  return null;
});
