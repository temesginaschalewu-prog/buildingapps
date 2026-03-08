import '../utils/parsers.dart';

class Subscription {
  final int id;
  final int userId;
  final int categoryId;
  final DateTime startDate;
  final DateTime expiryDate;
  final String status;
  final String billingCycle;
  final int? paymentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? categoryName;
  final double? price;

  Subscription({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.startDate,
    required this.expiryDate,
    required this.status,
    required this.billingCycle,
    this.paymentId,
    this.createdAt,
    this.updatedAt,
    this.categoryName,
    this.price,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    int getCategoryId(Map<String, dynamic> json) {
      if (json['category_id'] != null) {
        return Parsers.parseInt(json['category_id']);
      }

      final categoryName = json['category_name']?.toString() ?? '';
      if (categoryName == 'grade 9') return 1;
      if (categoryName == 'category 10') return 6;
      if (categoryName == 'categorytrial') return 7;
      return 0;
    }

    return Subscription(
      id: Parsers.parseInt(json['id']),
      userId: Parsers.parseInt(json['user_id']),
      categoryId: getCategoryId(json),
      startDate: Parsers.parseDate(json['start_date']) ?? DateTime.now(),
      expiryDate: Parsers.parseDate(json['expiry_date']) ?? DateTime.now(),
      status: json['status']?.toString() ?? 'active',
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      paymentId: json['payment_id'] != null
          ? Parsers.parseInt(json['payment_id'])
          : null,
      createdAt: Parsers.parseDate(json['created_at']),
      updatedAt: Parsers.parseDate(json['updated_at']),
      categoryName: json['category_name']?.toString(),
      price: json['price'] != null ? Parsers.parseDouble(json['price']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'start_date': startDate.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'status': status,
      'billing_cycle': billingCycle,
      'payment_id': paymentId,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'category_name': categoryName,
      'price': price,
    };
  }

  bool get isActive => status == 'active' && expiryDate.isAfter(DateTime.now());
  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isCancelled => status == 'cancelled';

  int get daysRemaining {
    final now = DateTime.now();
    return expiryDate.isBefore(now) ? 0 : expiryDate.difference(now).inDays;
  }

  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;

  String get statusDisplay {
    if (isCancelled) return 'Cancelled';
    if (isExpired) return 'Expired';
    if (isExpiringSoon) return 'Expiring Soon';
    if (isActive) return 'Active';
    return status;
  }

  @override
  String toString() =>
      'Subscription(id: $id, categoryId: $categoryId, status: $status, expiry: $expiryDate)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Subscription &&
        other.id == id &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode => id.hashCode ^ categoryId.hashCode;
}
