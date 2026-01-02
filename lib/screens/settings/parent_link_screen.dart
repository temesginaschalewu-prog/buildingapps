import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/parent_link_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/helpers.dart';

class ParentLinkScreen extends StatefulWidget {
  const ParentLinkScreen({super.key});

  @override
  State<ParentLinkScreen> createState() => _ParentLinkScreenState();
}

class _ParentLinkScreenState extends State<ParentLinkScreen> {
  @override
  void initState() {
    super.initState();
    _loadParentLinkStatus();
  }

  Future<void> _loadParentLinkStatus() async {
    final parentLinkProvider =
        Provider.of<ParentLinkProvider>(context, listen: false);
    await parentLinkProvider.getParentLinkStatus();
  }

  Future<void> _generateToken() async {
    final parentLinkProvider =
        Provider.of<ParentLinkProvider>(context, listen: false);

    try {
      await parentLinkProvider.generateParentToken();

      // Show token dialog
      final token = parentLinkProvider.parentToken;
      final expiresAt = parentLinkProvider.tokenExpiresAt;

      if (token != null && expiresAt != null) {
        _showTokenDialog(token, expiresAt);
      }
    } catch (e) {
      showSnackBar(context, 'Failed to generate token: $e', isError: true);
    }
  }

  Future<void> _unlinkParent() async {
    final parentLinkProvider =
        Provider.of<ParentLinkProvider>(context, listen: false);

    final confirmed = await showConfirmDialog(
      context,
      'Unlink Parent',
      'Are you sure you want to unlink the parent?',
      () async {
        try {
          await parentLinkProvider.unlinkParent();
          showSnackBar(context, 'Parent unlinked successfully');
        } catch (e) {
          showSnackBar(context, 'Failed to unlink: $e', isError: true);
        }
      },
    );
  }

  void _showTokenDialog(String token, DateTime expiresAt) {
    final remainingMinutes = expiresAt.difference(DateTime.now()).inMinutes;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parent Link Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Share this token with your parent:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: SelectableText(
                token,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Expires: ${formatDateTime(expiresAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Expires in: ${remainingMinutes > 0 ? remainingMinutes : 0} minutes',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text('1. Share this token with parent'),
            const Text('2. Parent uses /link TOKEN in Telegram bot'),
            const Text('3. Link expires in 30 minutes'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentLinkProvider = Provider.of<ParentLinkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Parent Controls')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parent Link',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Link your parent\'s Telegram account to receive progress updates.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (parentLinkProvider.isLinked)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.family_restroom,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Parent Linked',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (parentLinkProvider.parentTelegramUsername != null)
                        Text(
                          'Telegram: @${parentLinkProvider.parentTelegramUsername}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      if (parentLinkProvider.linkedAt != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Linked: ${formatDate(parentLinkProvider.linkedAt!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: _unlinkParent,
                        child: const Text('Unlink Parent'),
                      ),
                    ],
                  ),
                ),
              )
            else if (parentLinkProvider.parentToken != null &&
                parentLinkProvider.tokenExpiresAt != null &&
                !parentLinkProvider.isTokenExpired)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.timer,
                        size: 64,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Token Generated',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (parentLinkProvider.remainingTime.inMinutes > 0)
                        Text(
                          'Token expires in: ${parentLinkProvider.remainingTime.inMinutes} minutes',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        Text(
                          'Token expired',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          if (parentLinkProvider.parentToken != null &&
                              parentLinkProvider.tokenExpiresAt != null) {
                            _showTokenDialog(
                              parentLinkProvider.parentToken!,
                              parentLinkProvider.tokenExpiresAt!,
                            );
                          }
                        },
                        child: const Text('Show Token'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _generateToken,
                        child: const Text('Generate New Token'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.link_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Not Linked',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Generate a token to link with parent',
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _generateToken,
                        child: const Text('Generate Link Token'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What Parents Can See',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('✓ Daily study streak'),
                    const Text('✓ Weekly progress reports'),
                    const Text('✓ Exam results and scores'),
                    const Text('✓ Subscription status'),
                    const Text('✓ Payment reminders'),
                    const SizedBox(height: 16),
                    Text(
                      'Note: Parents receive weekly updates via Telegram bot.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
