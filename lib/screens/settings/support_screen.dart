import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/payment_provider.dart';
import '../../utils/helpers.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  @override
  void initState() {
    super.initState();
    _loadPaymentSettings();
  }

  Future<void> _loadPaymentSettings() async {
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    await paymentProvider.loadPaymentSettings();
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => paymentProvider.loadPaymentSettings(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact Information
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildContactItem(
                        Icons.phone,
                        'Phone',
                        '+251 91 234 5678',
                        onTap: () {
                          // Launch phone app
                        },
                      ),
                      _buildContactItem(
                        Icons.email,
                        'Email',
                        'support@familyacademy.edu',
                        onTap: () {
                          // Launch email app
                        },
                      ),
                      _buildContactItem(
                        Icons.telegram,
                        'Telegram',
                        '@familyacademy_support',
                        onTap: () {
                          // Launch Telegram
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Office Hours
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Office Hours',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildOfficeHourItem(
                          'Monday - Friday', '8:00 AM - 5:00 PM'),
                      _buildOfficeHourItem('Saturday', '9:00 AM - 1:00 PM'),
                      _buildOfficeHourItem('Sunday', 'Closed'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Payment Support
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment Support',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'For payment-related issues, please contact:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(paymentProvider.getBankName()),
                      Text('Account: ${paymentProvider.getAccountNumber()}'),
                      const SizedBox(height: 8),
                      const Text(
                        'Telebirr:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(paymentProvider.getTelebirrNumber()),
                      const SizedBox(height: 8),
                      Text(paymentProvider.getPaymentInstructions()),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // FAQ
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Frequently Asked Questions',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFAQItem(
                        'How do I reset my password?',
                        'Contact support with your username to reset your password.',
                      ),
                      _buildFAQItem(
                        'Why is my payment not verified?',
                        'Payments are verified manually by admin within 24 hours.',
                      ),
                      _buildFAQItem(
                        'Can I use the app on multiple devices?',
                        'No, each account is limited to one primary device.',
                      ),
                      _buildFAQItem(
                        'How do I cancel my subscription?',
                        'Subscriptions cannot be cancelled, but will expire automatically.',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeHourItem(String day, String hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day),
          Text(
            hours,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(
        question,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer),
        ),
      ],
    );
  }
}
