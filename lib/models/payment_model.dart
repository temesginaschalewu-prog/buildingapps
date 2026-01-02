import 'package:familyacademyclient/utils/constants.dart';

class Payment {
  final int id;
  final String paymentType;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final String categoryName;
  final DateTime? verifiedAt;
  final String? rejectionReason;

  Payment({
    required this.id,
    required this.paymentType,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.categoryName,
    this.verifiedAt,
    this.rejectionReason,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      paymentType: json['payment_type'],
      amount: double.parse(json['amount'].toString()),
      paymentMethod: json['payment_method'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      categoryName: json['category_name'],
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
      rejectionReason: json['rejection_reason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payment_type': paymentType,
      'amount': amount,
      'payment_method': paymentMethod,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'category_name': categoryName,
      'verified_at': verifiedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
    };
  }

  bool get isPending => status == 'pending';
  bool get isVerified => status == 'verified';
  bool get isRejected => status == 'rejected';

  String get paymentTypeText {
    switch (paymentType) {
      case AppConstants.firstTimePayment:
        return 'First Time Payment';
      case AppConstants.repayment:
        return 'Repayment';
      case AppConstants.deviceChange:
        return 'Device Change';
      default:
        return paymentType;
    }
  }

  String get paymentMethodText {
    switch (paymentMethod) {
      case AppConstants.telebirr:
        return 'Telebirr';
      case AppConstants.bankTransfer:
        return 'Bank Transfer';
      case AppConstants.cash:
        return 'Cash';
      default:
        return paymentMethod;
    }
  }
}
