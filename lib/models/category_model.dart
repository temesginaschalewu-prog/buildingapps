import '../utils/parsers.dart';

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
      id: Parsers.parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      price: json['price'] != null ? Parsers.parseDouble(json['price']) : null,
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      courseCount: Parsers.parseInt(json['course_count']),
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

  String get imageUrlOrDefault => imageUrl ?? '';
  String get initials => name.isNotEmpty
      ? name.substring(0, Parsers.min(2, name.length)).toUpperCase()
      : '?';

  bool hasUserAccess(bool hasActiveSubscription, bool hasPendingPayment) {
    if (isComingSoon) return false;
    if (isFree) return true;
    return hasActiveSubscription;
  }
}
