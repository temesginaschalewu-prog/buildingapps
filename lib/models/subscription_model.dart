
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
    DateTime parseDate(String dateStr) {
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return DateTime.now();
      }
    }

    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    double? parsePrice(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    // CRITICAL FIX: Try to get category_id from multiple possible fields
    int getCategoryId(Map<String, dynamic> json) {
      // Try category_id first
      if (json['category_id'] != null) {
        return parseId(json['category_id']);
      }

      // Try to extract from category_name (e.g., "grade 9" -> 1)
      // This is a temporary fix - backend should include category_id
      final categoryName = json['category_name']?.toString() ?? '';
      if (categoryName == 'grade 9') return 1;
      if (categoryName == 'category 10') return 6;
      if (categoryName == 'categorytrial') return 7;

      return 0;
    }

    return Subscription(
      id: parseId(json['id']),
      userId: parseId(json['user_id']),
      categoryId: getCategoryId(json), // Use the fixed method
      startDate: parseDate(json['start_date'].toString()),
      expiryDate: parseDate(json['expiry_date'].toString()),
      status: json['status']?.toString() ?? 'active',
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      paymentId:
          json['payment_id'] != null ? parseId(json['payment_id']) : null,
      createdAt: json['created_at'] != null
          ? parseDate(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? parseDate(json['updated_at'].toString())
          : null,
      categoryName: json['category_name']?.toString(),
      price: parsePrice(json['price']),
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
    if (expiryDate.isBefore(now)) return 0;
    return expiryDate.difference(now).inDays;
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
  String toString() {
    return 'Subscription(id: $id, categoryId: $categoryId, status: $status, expiry: $expiryDate)';
  }

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
