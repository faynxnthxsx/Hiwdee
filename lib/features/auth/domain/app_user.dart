/// ผู้ใช้ในระบบ — คนเดียวกันเป็นได้ทั้ง "ผู้ฝากหิ้ว" และ "นักหิ้ว"
/// (เปิดโหมดนักหิ้วผ่าน [isCarrier] แทนการแยกบัญชี เหมือน Grab/Shopee)
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.phone,
    this.avatarUrl,
    this.isCarrier = false,
    this.isVerified = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.walletBalance = 0,
  });

  final String id;
  final String displayName;
  final String phone;
  final String? avatarUrl;
  final bool isCarrier;
  final bool isVerified;
  final double rating;
  final int reviewCount;
  final double walletBalance;

  bool get hasReviews => reviewCount > 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'isCarrier': isCarrier,
        'isVerified': isVerified,
        'rating': rating,
        'reviewCount': reviewCount,
        'walletBalance': walletBalance,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        phone: json['phone'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        isCarrier: json['isCarrier'] as bool? ?? false,
        isVerified: json['isVerified'] as bool? ?? false,
        rating: (json['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: json['reviewCount'] as int? ?? 0,
        walletBalance: (json['walletBalance'] as num?)?.toDouble() ?? 0,
      );

  AppUser copyWith({
    String? displayName,
    String? avatarUrl,
    bool? isCarrier,
    bool? isVerified,
    double? rating,
    int? reviewCount,
    double? walletBalance,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      phone: phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isCarrier: isCarrier ?? this.isCarrier,
      isVerified: isVerified ?? this.isVerified,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }
}
