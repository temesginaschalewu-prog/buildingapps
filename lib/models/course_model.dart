import 'package:flutter/material.dart';

class Course {
  final int id;
  final String name;
  final int categoryId;
  final String? description;
  final int chapterCount;
  final String? access;
  final String? message;
  final bool hasPendingPayment;
  final bool requiresPayment;

  Course({
    required this.id,
    required this.name,
    required this.categoryId,
    this.description,
    required this.chapterCount,
    this.access,
    this.message,
    this.hasPendingPayment = false,
    this.requiresPayment = true,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      categoryId: json['category_id'] ?? 0,
      description: json['description'],
      chapterCount: json['chapter_count'] ?? 0,
      access: json['access'],
      message: json['message'],
      hasPendingPayment: json['has_pending_payment'] ?? false,
      requiresPayment: json['requires_payment'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'description': description,
      'chapter_count': chapterCount,
      'access': access,
      'message': message,
      'has_pending_payment': hasPendingPayment,
      'requires_payment': requiresPayment,
    };
  }

  bool get isFullyAccessible => access == 'full';
  bool get isLimitedAccess => access == 'limited' || access == null;

  bool hasFullAccess(bool hasActiveSubscription) {
    if (access == 'full') return true;

    if (hasActiveSubscription) return true;

    if (!requiresPayment) return true;

    return false;
  }

  bool shouldShowLock(bool hasActiveSubscription) {
    return requiresPayment && !hasActiveSubscription;
  }

  IconData getAccessIcon(bool hasActiveSubscription) {
    if (hasFullAccess(hasActiveSubscription)) {
      return Icons.check_circle;
    } else if (hasPendingPayment) {
      return Icons.pending;
    } else {
      return Icons.lock;
    }
  }

  Color getAccessColor(bool hasActiveSubscription) {
    if (hasFullAccess(hasActiveSubscription)) {
      return Colors.green;
    } else if (hasPendingPayment) {
      return Colors.orange;
    } else {
      return Colors.orangeAccent;
    }
  }

  String getAccessText(bool hasActiveSubscription) {
    if (hasFullAccess(hasActiveSubscription)) {
      return 'Full Access';
    } else if (hasPendingPayment) {
      return 'Pending Payment';
    } else if (!requiresPayment) {
      return 'Free';
    } else {
      return 'Purchase Required';
    }
  }
}
