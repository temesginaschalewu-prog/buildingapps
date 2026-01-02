class Subscription {
  final int id;
  final DateTime startDate;
  final DateTime expiryDate;
  final String status;
  final String billingCycle;
  final String categoryName;
  final int categoryId;
  final double price;
  final String? paymentMethod;
  final String? paymentStatus;
  final int daysRemaining;

  Subscription({
    required this.id,
    required this.startDate,
    required this.expiryDate,
    required this.status,
    required this.billingCycle,
    required this.categoryName,
    required this.categoryId,
    required this.price,
    this.paymentMethod,
    this.paymentStatus,
    required this.daysRemaining,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      startDate: DateTime.parse(json['start_date']),
      expiryDate: DateTime.parse(json['expiry_date']),
      status: json['status'],
      billingCycle: json['billing_cycle'],
      categoryName: json['category_name'],
      categoryId: json['category_id'],
      price: double.parse(json['price'].toString()),
      paymentMethod: json['payment_method'],
      paymentStatus: json['payment_status'],
      daysRemaining: json['days_remaining'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start_date': startDate.toIso8601String(),
      'expiry_date': expiryDate.toIso8601String(),
      'status': status,
      'billing_cycle': billingCycle,
      'category_name': categoryName,
      'category_id': categoryId,
      'price': price,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      'days_remaining': daysRemaining,
    };
  }

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';
  bool get isCancelled => status == 'cancelled';

  bool get isExpiringSoon => daysRemaining <= 7 && daysRemaining > 0;
  bool get hasExpired => daysRemaining <= 0;

  bool get providesAccess => isActive && !hasExpired;

  String get statusDisplay {
    if (isActive) {
      if (hasExpired) return 'Expired';
      if (isExpiringSoon) return 'Expiring Soon';
      return 'Active';
    }
    return status;
  }
}
