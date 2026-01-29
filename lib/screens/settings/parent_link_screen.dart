import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
  late Timer _refreshTimer;
  late Timer _countdownTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Load cached data immediately
    _loadParentLinkStatus(forceRefresh: false);

    // Refresh parent link status every 30 seconds when screen is active
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshDataInBackground();
      }
    });

    // Update countdown every second for smooth animation
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _countdownTimer.cancel();
    super.dispose();
  }

  Future<void> _loadParentLinkStatus({bool forceRefresh = false}) async {
    final parentLinkProvider =
        Provider.of<ParentLinkProvider>(context, listen: false);
    try {
      await parentLinkProvider.getParentLinkStatus(forceRefresh: forceRefresh);
    } catch (e) {
      debugLog('ParentLinkScreen', 'Error loading parent link status: $e');
    }
  }

  Future<void> _refreshDataInBackground() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    try {
      await _loadParentLinkStatus(forceRefresh: true);
    } catch (e) {
      debugLog('ParentLinkScreen', 'Background refresh error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
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
    final confirmed = await showConfirmDialog(
      context,
      'Unlink Parent',
      'Are you sure you want to unlink the parent? This will stop all progress updates to the parent.',
      () async {
        final parentLinkProvider =
            Provider.of<ParentLinkProvider>(context, listen: false);
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.link, color: Colors.blue),
            SizedBox(width: 8),
            Text('Parent Link Token'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this token with your parent to link their Telegram account.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      token,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Consumer<ParentLinkProvider>(
                      builder: (context, provider, child) {
                        return Text(
                          'Expires in: ${provider.remainingTimeFormatted}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: provider.remainingTime.inMinutes < 5
                                ? Colors.red
                                : Colors.green,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '📋 How to use:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('1. Share this token with your parent'),
              Text('2. Parent sends /link $token in Telegram bot'),
              const Text('3. Link will be established immediately'),
              const SizedBox(height: 8),
              const Text(
                '⏰ Token expires in 30 minutes',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => GoRouter.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Copy to clipboard
              await Clipboard.setData(ClipboardData(text: token));
              showSnackBar(context, 'Token copied to clipboard!');
            },
            child: const Text('Copy Token'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedState(ParentLinkProvider provider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade100, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade200, width: 2),
                ),
                child: const Icon(
                  Icons.family_restroom,
                  size: 48,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '✅ Parent Linked Successfully',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (provider.parentTelegramUsername != null ||
                  provider.parentName != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      if (provider.parentName != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person,
                                size: 20, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text(
                              provider.parentName!,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (provider.parentTelegramUsername != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.telegram,
                                  size: 20, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(
                                '@${provider.parentTelegramUsername}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              if (provider.linkedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Linked: ${formatDateTime(provider.linkedAt!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _unlinkParent,
                icon: const Icon(Icons.link_off, size: 20),
                label: const Text('Unlink Parent'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your parent will receive weekly progress updates.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTokenState(ParentLinkProvider provider) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.orange.shade100, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orange.shade200, width: 2),
                ),
                child: const Icon(
                  Icons.timer,
                  size: 48,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '⏳ Token Generated',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Column(
                  children: [
                    Consumer<ParentLinkProvider>(
                      builder: (context, provider, child) {
                        return Text(
                          provider.remainingTimeFormatted,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: provider.remainingTime.inMinutes < 5
                                ? Colors.red
                                : Colors.orange,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Token expires in',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  if (provider.parentToken != null &&
                      provider.tokenExpiresAt != null) {
                    _showTokenDialog(
                      provider.parentToken!,
                      provider.tokenExpiresAt!,
                    );
                  }
                },
                icon: const Icon(Icons.visibility, size: 20),
                label: const Text('Show Token & Instructions'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _generateToken,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Generate New Token'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotLinkedState() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: const Icon(
                  Icons.link_off,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '🔗 Link with Parent',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Generate a token to link your parent\'s Telegram account and share your progress.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _generateToken,
                icon: const Icon(Icons.add_link, size: 20),
                label: const Text('Generate Link Token'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Loading parent link status...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentLinkProvider = Provider.of<ParentLinkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Controls'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshDataInBackground,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status Card - Show immediately with cached data
                if (!parentLinkProvider.hasLoaded)
                  _buildLoadingState()
                else if (parentLinkProvider.isLinked)
                  _buildLinkedState(parentLinkProvider)
                else if (parentLinkProvider.parentToken != null &&
                    !parentLinkProvider.isTokenExpired)
                  _buildTokenState(parentLinkProvider)
                else
                  _buildNotLinkedState(),

                const SizedBox(height: 32),

                // Benefits Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.visibility, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'What Parents Can See',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildBenefitItem('📊 Daily study streak and progress'),
                        _buildBenefitItem('📝 Exam results and scores'),
                        _buildBenefitItem('💰 Subscription and payment status'),
                        _buildBenefitItem('🔔 Important notifications'),
                        _buildBenefitItem('📅 Weekly progress summary'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: const Text(
                            'Parents receive weekly updates via Telegram bot. '
                            'They cannot modify your account or access videos.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions Card
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.help_outline, color: Colors.purple),
                            SizedBox(width: 8),
                            Text(
                              'How It Works',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildStepItem(1, 'Generate a token in the app'),
                        _buildStepItem(2, 'Share the token with your parent'),
                        _buildStepItem(
                            3, 'Parent uses /link TOKEN in Telegram bot'),
                        _buildStepItem(4, 'Link established instantly'),
                        _buildStepItem(5, 'Parent receives weekly updates'),
                        const SizedBox(height: 12),
                        Text(
                          'Tokens expire in 30 minutes for security.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // User Info
                if (authProvider.user != null)
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.grey),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authProvider.user!.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Student ID: ${authProvider.user!.id}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Show small refreshing indicator in top-right corner
          if (_isRefreshing)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 20, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildStepItem(int step, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}
