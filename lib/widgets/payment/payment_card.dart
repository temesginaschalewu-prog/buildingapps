import 'package:flutter/material.dart';
import '../../models/payment_model.dart';
import '../../themes/app_colors.dart';

class PaymentCard extends StatelessWidget {
  final Payment payment;

  const PaymentCard({super.key, required this.payment});

  Color _getStatusColor() {
    switch (payment.status) {
      case 'verified':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
        return AppColors.warning;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText() {
    switch (payment.status) {
      case 'verified':
        return 'VERIFIED';
      case 'rejected':
        return 'REJECTED';
      case 'pending':
        return 'PENDING';
      default:
        return payment.status.toUpperCase();
    }
  }

  IconData _getStatusIcon() {
    switch (payment.status) {
      case 'verified':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _getStatusColor()),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getStatusIcon(),
                        size: 12,
                        color: _getStatusColor(),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _getStatusColor(),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${payment.amount} Birr',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              payment.categoryName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.payment, size: 14),
                const SizedBox(width: 4),
                Text(
                  payment.paymentMethodText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  '${payment.createdAt.day}/${payment.createdAt.month}/${payment.createdAt.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (payment.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Reason: ${payment.rejectionReason}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.error,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            if (payment.verifiedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Verified: ${payment.verifiedAt!.day}/${payment.verifiedAt!.month}/${payment.verifiedAt!.year}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
