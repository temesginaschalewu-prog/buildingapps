import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/helpers.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContactSettings();
  }

  Future<void> _loadContactSettings() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.loadContactSettings();
  }

  Widget _buildContactItem(String title, String? value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 24,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value ?? 'Not available',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final contactSettings = settingsProvider.contactSettings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: settingsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 32,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need Help?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'We\'re here to help you with any questions or issues.',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (contactSettings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          'Contact information not available',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        if (settingsProvider.getContactSupportPhone() != null)
                          _buildContactItem(
                            'Support Phone',
                            settingsProvider.getContactSupportPhone(),
                            Icons.phone,
                          ),
                        if (settingsProvider.getContactSupportEmail() != null)
                          _buildContactItem(
                            'Support Email',
                            settingsProvider.getContactSupportEmail(),
                            Icons.email,
                          ),
                        if (settingsProvider.getContactOfficeAddress() != null)
                          _buildContactItem(
                            'Office Address',
                            settingsProvider.getContactOfficeAddress(),
                            Icons.location_on,
                          ),
                        if (settingsProvider.getContactOfficeHours() != null)
                          _buildContactItem(
                            'Office Hours',
                            settingsProvider.getContactOfficeHours(),
                            Icons.access_time,
                          ),
                      ],
                    ),
                  const SizedBox(height: 32),
                  const Text(
                    'Common Issues',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCommonIssueItem(
                    'Payment Issues',
                    'Ensure payment proof is clear and includes transaction ID',
                    Icons.payment,
                  ),
                  _buildCommonIssueItem(
                    'Video Playback',
                    'Check your internet connection and try again',
                    Icons.video_library,
                  ),
                  _buildCommonIssueItem(
                    'Exam Access',
                    'Ensure you have an active subscription for the category',
                    Icons.quiz,
                  ),
                  _buildCommonIssueItem(
                    'Account Login',
                    'Verify username and password, or request password reset',
                    Icons.lock,
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Send Us a Message',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'If you need further assistance, please contact support using the information above.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Quick Actions',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.receipt, size: 18),
                        label: const Text('My Payments'),
                        onPressed: () {
                          GoRouter.of(context).push('/payment-history');
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.subscriptions, size: 18),
                        label: const Text('My Subscriptions'),
                        onPressed: () {
                          GoRouter.of(context).push('/subscriptions');
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.device_hub, size: 18),
                        label: const Text('Device Settings'),
                        onPressed: () {
                          GoRouter.of(context).push('/device-settings');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildCommonIssueItem(
      String title, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(description),
        dense: true,
      ),
    );
  }
}
