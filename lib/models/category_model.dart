import '../utils/constants.dart';

class Category {
  final int id;
  final String name;
  final String status;
  final double? price;
  final String billingCycle;
  final String? description;
  final int courseCount;

  Category({
    required this.id,
    required this.name,
    required this.status,
    this.price,
    required this.billingCycle,
    this.description,
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
      'course_count': courseCount,
    };
  }

  bool get isActive => status == 'active';
  bool get isComingSoon => status == 'coming_soon';
  bool get isFree => price == null || price == 0;
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

  bool canAccessForUser(bool hasActiveSubscription) {
    if (isComingSoon) return false;
    if (isFree) return true;
    return hasActiveSubscription;
  }
}
