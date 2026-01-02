import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../models/category_model.dart';
import '../../utils/helpers.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final category = args['category'] as Category;
    final paymentType = args['paymentType'] as String;

    String getMessage() {
      switch (paymentType) {
        case 'first_time':
          return 'Your payment for "${category.name}" has been submitted successfully. Your subscription will be activated after admin verification.';
        case 'repayment':
          return 'Your renewal payment for "${category.name}" has been submitted successfully. Your subscription will be extended after admin verification.';
        case 'device_change':
          return 'Your device change payment has been submitted successfully. You can login on your new device after admin verification.';
        default:
          return 'Payment submitted successfully.';
      }
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/lottie/success_check.json',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 32),
              Text(
                'Payment Submitted!',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                getMessage(),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Category:'),
                          Text(
                            category.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Amount:'),
                          Text(
                            '${category.price ?? 0} Birr',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Status:'),
                          const Text(
                            'Pending Verification',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'What happens next?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text('1. Admin will verify your payment'),
              const Text('2. You\'ll receive a notification'),
              const Text('3. Access will be granted automatically'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  child: const Text('Return to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
