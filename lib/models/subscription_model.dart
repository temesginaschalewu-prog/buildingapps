import 'package:flutter/foundation.dart';

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
    return Subscription(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] ?? 0,
      userId: json['user_id'] is String
          ? int.parse(json['user_id'])
          : json['user_id'] ?? 0,
      categoryId: json['category_id'] is String
          ? int.parse(json['category_id'])
          : json['category_id'] ?? 0,
      startDate: DateTime.parse(json['start_date']),
      expiryDate: DateTime.parse(json['expiry_date']),
      status: json['status'] ?? 'active',
      billingCycle: json['billing_cycle'] ?? 'monthly',
      paymentId: json['payment_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      categoryName: json['category_name'],
      price:
          json['price'] != null ? double.parse(json['price'].toString()) : null,
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
