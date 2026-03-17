import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'payment_model.g.dart'; // NEW

@HiveType(typeId: 10) // NEW
class Payment {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String paymentType;

  @HiveField(2)
  final double amount;

  @HiveField(3)
  final String paymentMethod;

  @HiveField(4)
  final String? accountHolderName;

  @HiveField(5)
  final String status;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final String categoryName;

  @HiveField(8)
  final DateTime? verifiedAt;

  @HiveField(9)
  final String? rejectionReason;

  @HiveField(10)
  final int? categoryId;

  Payment({
    required this.id,
    required this.paymentType,
    required this.amount,
    required this.paymentMethod,
    this.accountHolderName,
    required this.status,
    required this.createdAt,
    required this.categoryName,
    this.verifiedAt,
    this.rejectionReason,
    this.categoryId,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: Parsers.parseInt(json['id']),
      paymentType: json['payment_type']?.toString() ?? '',
      amount: Parsers.parseDouble(json['amount']),
      paymentMethod: json['payment_method']?.toString() ?? '',
      accountHolderName: json['account_holder_name']?.toString(),
      status: json['status']?.toString() ?? '',
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
      categoryName: json['category_name']?.toString() ?? '',
      verifiedAt: Parsers.parseDate(json['verified_at']),
      rejectionReason: json['rejection_reason']?.toString(),
      categoryId: json['category_id'] != null
          ? Parsers.parseInt(json['category_id'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_type': paymentType,
      'amount': amount,
      'payment_method': paymentMethod,
      'account_holder_name': accountHolderName,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'category_name': categoryName,
      'verified_at': verifiedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'category_id': categoryId,
    };
  }

  bool get isPending => status == 'pending';
  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';

  String get paymentTypeText {
    switch (paymentType) {
      case 'first_time':
        return 'First Time Payment';
      case 'repayment':
        return 'Renewal Payment';
      default:
        return paymentType.replaceAll('_', ' ');
    }
  }
}
