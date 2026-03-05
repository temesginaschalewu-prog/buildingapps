import '../utils/parsers.dart';

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
      id: Parsers.parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      categoryId: Parsers.parseInt(json['category_id']),
      description: json['description']?.toString(),
      chapterCount: Parsers.parseInt(json['chapter_count']),
      access: json['access']?.toString(),
      message: json['message']?.toString(),
      hasPendingPayment: Parsers.parseBool(json['has_pending_payment']),
      requiresPayment: Parsers.parseBool(json['requires_payment'], true),
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
}
