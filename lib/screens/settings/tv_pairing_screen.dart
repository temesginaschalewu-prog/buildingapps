import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/helpers.dart';

class TvPairingScreen extends StatefulWidget {
  const TvPairingScreen({super.key});

  @override
  State<TvPairingScreen> createState() => _TvPairingScreenState();
}

class _TvPairingScreenState extends State<TvPairingScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pairDevice() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      showSnackBar(context, 'Please enter the pairing code', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await deviceProvider.verifyTvPairing(code);
      showSnackBar(context, 'TV device paired successfully');
      _codeController.clear();
    } catch (e) {
      showSnackBar(context, 'Pairing failed: $e', isError: true);
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _unpairDevice() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);

    final confirmed = await showConfirmDialog(
      context,
      'Unpair TV Device',
      'Are you sure you want to unpair your TV device?',
      () async {
        try {
          await deviceProvider.unpairTvDevice();
          showSnackBar(context, 'TV device unpaired successfully');
        } catch (e) {
          showSnackBar(context, 'Unpairing failed: $e', isError: true);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('TV Device Pairing')),
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
                      'TV Device Pairing',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pair your Android TV device to stream content.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (deviceProvider.hasTvDevice)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.tv,
                        size: 64,
                        color: Colors.green,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TV Device Paired',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Device ID: ${deviceProvider.tvDeviceId}',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: _unpairDevice,
                        child: const Text('Unpair Device'),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter Pairing Code',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        decoration: const InputDecoration(
                          labelText: '6-digit Code',
                          border: OutlineInputBorder(),
                          hintText: 'Enter code from TV',
                        ),
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isVerifying ? null : _pairDevice,
                          child: _isVerifying
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Text('Pair Device'),
                        ),
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
                      'Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Open Family Academy on your Android TV',
                    ),
                    const Text(
                      '2. Go to Settings > Pair Device',
                    ),
                    const Text(
                      '3. Enter the 6-digit code shown on TV',
                    ),
                    const Text(
                      '4. Click "Pair Device" above',
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Note: You can only pair one TV device at a time.',
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
