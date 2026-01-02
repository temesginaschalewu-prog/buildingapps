import 'dart:io';
import 'package:familyacademyclient/models/Device_change_request.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../../widgets/auth/auth_form_field.dart';
import '../../widgets/auth/password_field.dart';

class DeviceChangeScreen extends StatefulWidget {
  const DeviceChangeScreen({super.key});

  @override
  State<DeviceChangeScreen> createState() => _DeviceChangeScreenState();
}

class _DeviceChangeScreenState extends State<DeviceChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _picker = ImagePicker();
  String? _paymentMethod = AppConstants.telebirr;
  String? _proofImagePath;
  File? _proofImageFile;
  bool _isLoading = false;
  bool _confirmAccuracy = false;
  late Map<String, dynamic> _args;
  late String _username;
  late String _deviceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    _username = _args['username'];
    _deviceId = _args['deviceId'];
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _proofImageFile = File(image.path);
          _proofImagePath = image.path;
        });
      }
    } catch (e) {
      showSnackBar(context, 'Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _submitDeviceChange() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmAccuracy) {
      showSnackBar(context, 'Please confirm accuracy', isError: true);
      return;
    }
    if (_proofImageFile == null) {
      showSnackBar(context, 'Please upload payment proof', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final password = _passwordController.text;
    final amount = 0.0; // Amount should come from settings

    try {
      // First upload the proof image
      // Note: You need to implement uploadPaymentProof in ApiService

      final request = DeviceChangeRequest(
        username: _username,
        password: password,
        paymentMethod: _paymentMethod!,
        amount: amount,
        proofImagePath: _proofImagePath!,
        deviceId: _deviceId,
      );

      final result = await authProvider.submitDeviceChangePayment(
        username: _username,
        password: password,
        paymentMethod: _paymentMethod!,
        amount: amount,
        proofImagePath: _proofImagePath!,
        deviceId: _deviceId,
      );

      if (result['success'] == true) {
        showSnackBar(context, 'Device change request submitted successfully');
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        showSnackBar(context, result['message'] ?? 'Request failed',
            isError: true);
      }
    } catch (e) {
      showSnackBar(context, 'Device change failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Change'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Change Required',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You are logging in from a new device. Please submit a device change payment to continue.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                AuthFormField(
                  controller: TextEditingController(text: _username),
                  label: 'Username',
                  enabled: false,
                  prefixIcon: Icons.person,
                  hintText: 'name',
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AppConstants.telebirr,
                      child: const Text('Telebirr'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.bankTransfer,
                      child: const Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(
                      value: AppConstants.cash,
                      child: const Text('Cash'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _paymentMethod = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Payment method is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Amount: 0.00 Birr',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment Instructions:',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Please make payment and upload proof below.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Upload Payment Proof',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _proofImageFile != null
                        ? Image.file(_proofImageFile!, fit: BoxFit.cover)
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to upload payment proof'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _confirmAccuracy,
                      onChanged: (value) {
                        setState(() => _confirmAccuracy = value ?? false);
                      },
                    ),
                    const Expanded(
                      child: Text('I confirm that all information is accurate'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitDeviceChange,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Submit Device Change Request'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
