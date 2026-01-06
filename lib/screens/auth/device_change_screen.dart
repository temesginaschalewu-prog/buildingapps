import 'dart:io';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/utils/api_response.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../utils/helpers.dart';

class DeviceChangeScreen extends StatefulWidget {
  const DeviceChangeScreen({super.key});

  @override
  State<DeviceChangeScreen> createState() => _DeviceChangeScreenState();
}

class _DeviceChangeScreenState extends State<DeviceChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _confirmChange = false;
  late Map<String, dynamic> _args = {};
  bool _hasArgs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get arguments from go_router state
    final goRouter = GoRouter.of(context);
    final state = goRouter.routerDelegate.currentConfiguration;

    if (state?.extra != null && state!.extra is Map<String, dynamic>) {
      _args = state.extra as Map<String, dynamic>;
      _hasArgs = true;

      debugLog('DeviceChangeScreen', 'Received args: $_args');

      // Auto-fill password if provided
      if (_args['password'] != null) {
        _passwordController.text = _args['password'].toString();
      }
    } else {
      debugLog('DeviceChangeScreen', 'No arguments provided');
      // Show error or navigate back
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackBar(context, 'Invalid device change request', isError: true);
        context.go('/auth/login');
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  String get _username => _hasArgs ? (_args['username']?.toString() ?? '') : '';
  String get _deviceId => _hasArgs ? (_args['deviceId']?.toString() ?? '') : '';
  String get _currentDeviceId =>
      _hasArgs ? (_args['currentDeviceId']?.toString() ?? '') : '';
  String get _newDeviceId =>
      _hasArgs ? (_args['newDeviceId']?.toString() ?? '') : '';
  int get _changeCount => _hasArgs ? (_args['changeCount'] as int? ?? 0) : 0;
  int get _maxChanges => _hasArgs ? (_args['maxChanges'] as int? ?? 2) : 2;
  int get _remainingChanges =>
      _hasArgs ? (_args['remainingChanges'] as int? ?? 2) : 2;
  bool get _canChangeDevice =>
      _hasArgs ? (_args['canChangeDevice'] as bool? ?? true) : true;

  Future<void> _approveDeviceChange() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmChange) {
      showSnackBar(context, 'Please confirm the device change', isError: true);
      return;
    }
    if (!_canChangeDevice) {
      showSnackBar(
        context,
        'You have reached the maximum device changes ($_maxChanges per month)',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final password = _passwordController.text;

    try {
      debugLog(
          'DeviceChangeScreen', 'Approving device change for user: $_username');

      // Call the approve-device-change endpoint
      final response = await authProvider.apiService.approveDeviceChange(
        password: password,
        deviceId: _deviceId,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;

        // Update auth provider with new data
        await authProvider.updateAfterDeviceChange(
          userData: data['user'],
          token: data['token'],
          deviceToken: data['deviceToken'],
          deviceId: _deviceId,
        );

        showSnackBar(
          context,
          'Device change approved! Old device is now blocked.',
        );

        // Navigate to home
        if (authProvider.user?.schoolId == null) {
          context.go('/school-selection');
        } else {
          context.go('/');
        }
      } else {
        showSnackBar(context, response.message ?? 'Device change failed',
            isError: true);
      }
    } catch (e) {
      debugLog('DeviceChangeScreen', 'Device change failed: $e');

      if (e is ApiError && e.action == 'max_device_changes_reached') {
        showSnackBar(
          context,
          'Maximum device changes (2 per month) reached. Please contact support.',
          isError: true,
        );
      } else {
        showSnackBar(context, 'Device change failed: ${e.toString()}',
            isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _cancelDeviceChange() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Device Change'),
        content: const Text(
            'Are you sure you want to cancel? You will not be able to login on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/auth/login');
            },
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasArgs) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Device Change'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/auth/login'),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Change Required'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Warning Card
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text(
                              'New Device Detected',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are logging in from a new device. '
                          'Your old device will be blocked after this change.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Device Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Username', _username),
                        _buildInfoRow('Current Device', _currentDeviceId),
                        _buildInfoRow('New Device', _newDeviceId),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Change Limit Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Device Change Limits',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildLimitRow(
                            'Changes this month', '$_changeCount/$_maxChanges'),
                        _buildLimitRow(
                            'Remaining changes', '$_remainingChanges'),
                        if (!_canChangeDevice)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '⚠️ Maximum changes reached. Contact support.',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Password Verification
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Verify Password',
                    border: OutlineInputBorder(),
                    filled: true,
                    prefixIcon: Icon(Icons.lock),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required to confirm device change';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Confirm Checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _confirmChange,
                      onChanged: (value) {
                        setState(() => _confirmChange = value ?? false);
                      },
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: const [
                            TextSpan(text: 'I understand that: '),
                            TextSpan(
                              text: 'My old device will be blocked, ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            TextSpan(text: 'and I can only change devices '),
                            TextSpan(
                              text: '2 times per month.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Action Buttons
                if (_canChangeDevice)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _approveDeviceChange,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text(
                            'Approve Device Change',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),

                if (!_canChangeDevice)
                  ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Maximum Changes Reached',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),

                const SizedBox(height: 12),

                OutlinedButton(
                  onPressed: _isLoading ? null : _cancelDeviceChange,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontFamily: Platform.isIOS ? 'Courier' : 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}
