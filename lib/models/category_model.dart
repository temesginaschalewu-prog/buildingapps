import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class Category {
  final int id;
  final String name;
  final String status;
  final double? price;
  final String billingCycle;
  final String? description;
  final String? imageUrl;
  final int courseCount;

  Category({
    required this.id,
    required this.name,
    required this.status,
    this.price,
    required this.billingCycle,
    this.description,
    this.imageUrl,
    this.courseCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      status: json['status'] ?? 'active',
      price:
          json['price'] != null ? double.parse(json['price'].toString()) : null,
      billingCycle: json['billing_cycle'] ?? 'monthly',
      description: json['description'],
      imageUrl: json['image_url'],
      courseCount: json['course_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'price': price,
      'billing_cycle': billingCycle,
      'description': description,
      'image_url': imageUrl,
      'course_count': courseCount,
    };
  }

  bool get isFree => price == null || price == 0;
  bool get isActive => status == 'active';
  bool get isComingSoon => status == 'coming_soon';
  bool get requiresPayment => !isFree && isActive;

  String get priceDisplay {
    if (price == null || price == 0) return 'Free';
    return '${price?.toStringAsFixed(0)} Birr';
  }

  String get statusDisplay {
    if (isComingSoon) return 'Coming Soon';
    if (isActive) return 'Active';
    return status;
  }

  String get imageUrlOrDefault {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return imageUrl!;
    }
    return 'https://via.placeholder.com/400x400/6366f1/ffffff?text=${Uri.encodeComponent(name.substring(0, 2).toUpperCase())}';
  }

  bool hasUserAccess(bool hasActiveSubscription, bool hasPendingPayment) {
    if (isComingSoon) return false;
    if (isFree) return true;
    return hasActiveSubscription;
  }

  String getAccessLabel(bool hasActiveSubscription, bool hasPendingPayment) {
    if (isComingSoon) return 'COMING SOON';
    if (isFree) return 'FREE';
    if (hasActiveSubscription) return 'FULL ACCESS';
    if (hasPendingPayment) return 'PENDING VERIFICATION';
    return 'LIMITED ACCESS';
  }

  Color getAccessColor(bool hasActiveSubscription, bool hasPendingPayment) {
    if (isComingSoon) return Colors.grey;
    if (isFree) return Colors.green;
    if (hasActiveSubscription) return Colors.green;
    if (hasPendingPayment) return Colors.orange;
    return Colors.orange;
  }

  IconData getAccessIcon(bool hasActiveSubscription, bool hasPendingPayment) {
    if (isComingSoon) return Icons.schedule;
    if (isFree) return Icons.check_circle;
    if (hasActiveSubscription) return Icons.check_circle;
    if (hasPendingPayment) return Icons.pending;
    return Icons.lock;
  }
}
