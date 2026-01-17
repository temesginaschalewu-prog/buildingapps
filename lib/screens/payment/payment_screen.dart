import 'dart:io';
import 'package:familyacademyclient/models/setting_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/category_model.dart';
import '../../providers/payment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic>? extra;

  const PaymentScreen({
    super.key,
    this.extra,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _picker = ImagePicker();

  String? _paymentMethod;
  String? _paymentType = 'first_time';
  File? _proofImageFile;
  bool _confirmAccuracy = false;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  Category? _category;
  late String _username;
  double _amount = 0.0;
  String _billingCycle = 'monthly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
      _loadPaymentSettings();
    });
  }

  void _initializeData() {
    try {
      final args = widget.extra;

      if (args == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'No payment data provided';
        });
        return;
      }

      dynamic categoryData = args['category'];

      if (categoryData == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Category data is required';
        });
        return;
      }

      // Try to get the full category object
      Category? category;

      if (categoryData is Map<String, dynamic>) {
        // If it's a map, check if it has price
        if (categoryData['price'] != null) {
          category = Category(
            id: categoryData['id'] ?? 0,
            name: categoryData['name'] ?? 'Unknown Category',
            status: 'active',
            price: double.parse(categoryData['price'].toString()),
            billingCycle: categoryData['billing_cycle'] ?? 'monthly',
            description: categoryData['description'],
          );
        } else {
          // If map doesn't have price, get from provider
          final categoryProvider = Provider.of<CategoryProvider>(
            context,
            listen: false,
          );
          final cat = categoryProvider.getCategoryById(categoryData['id']);
          if (cat != null) {
            category = cat;
          }
        }
      } else if (categoryData is Category) {
        category = categoryData;
      }

      if (category == null) {
        // Last resort: try to get category from provider
        final categoryProvider = Provider.of<CategoryProvider>(
          context,
          listen: false,
        );
        if (categoryData is Map<String, dynamic>) {
          final cat = categoryProvider.getCategoryById(categoryData['id']);
          if (cat != null) {
            category = cat;
          }
        }
      }

      if (category == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Category not found';
        });
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      setState(() {
        _paymentType = args['paymentType'] ?? 'first_time';
        _username = authProvider.user?.username ?? '';
        _usernameController.text = _username;
        _amount = category?.price ?? 0.0;
        _billingCycle = category!.billingCycle;
        _category = category;
        _hasError = false;
      });

      debugLog('PaymentScreen',
          'Category: ${category.name}, Amount: $_amount, Billing: $_billingCycle');
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize payment: $e';
      });
    }
  }

  Future<void> _loadPaymentSettings() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.loadPaymentSettings();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _proofImageFile = File(image.path);
        });
      }
    } catch (e) {
      showSnackBar(context, 'Failed to pick image: $e', isError: true);
    }
  }

  String _getPaymentTypeText() {
    switch (_paymentType) {
      case 'first_time':
        return 'First Time Payment';
      case 'repayment':
        return 'Renewal Payment';
      case 'device_change':
        return 'Device Change Payment';
      default:
        return _paymentType!;
    }
  }

  Future<void> _submitPayment() async {
    if (_category == null) {
      showSnackBar(context, 'Category information is missing', isError: true);
      return;
    }

    if (_amount <= 0) {
      showSnackBar(context, 'Invalid payment amount', isError: true);
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_proofImageFile == null) {
      showSnackBar(context, 'Please upload payment proof', isError: true);
      return;
    }
    if (!_confirmAccuracy) {
      showSnackBar(context, 'Please confirm accuracy', isError: true);
      return;
    }

    if (_paymentMethod == null) {
      showSnackBar(context, 'Please select a payment method', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    final password = _passwordController.text;

    try {
      debugLog('PaymentScreen', 'Uploading payment proof...');

      // Check if file exists
      if (_proofImageFile == null || !_proofImageFile!.existsSync()) {
        throw Exception('Payment proof file not found');
      }

      final uploadResponse =
          await paymentProvider.apiService.uploadPaymentProof(_proofImageFile!);
      final proofImagePath = uploadResponse.data;

      if (proofImagePath == null || proofImagePath.toString().isEmpty) {
        throw Exception('Failed to upload payment proof: Empty response');
      }

      debugLog('PaymentScreen', 'Payment proof uploaded: $proofImagePath');

      // Submit payment with the uploaded proof
      final result = await paymentProvider.submitPayment(
        categoryId: _category!.id,
        paymentType: _paymentType!,
        paymentMethod: _paymentMethod!,
        amount: _amount,
        proofImagePath: proofImagePath.toString(), // Ensure it's a string
      );

      debugLog('PaymentScreen', 'Payment submission result: $result');

      if (result['success'] == true) {
        await authProvider.refreshUserData();
        await subscriptionProvider.refreshAfterPaymentVerification();
        await subscriptionProvider
            .getCategorySubscriptionDetails(_category!.id);

        GoRouter.of(context).go('/payment-success', extra: {
          'category': _category,
          'paymentType': _paymentType,
        });
      } else {
        showSnackBar(context, result['message'] ?? 'Payment failed',
            isError: true);
      }
    } catch (e, stackTrace) {
      debugLog('PaymentScreen', 'Payment error: $e\n$stackTrace');
      showSnackBar(context, 'Payment failed: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPaymentMethodItem(Setting setting) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            setting.displayName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            setting.settingValue ?? '',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => GoRouter.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment')),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final settingsProvider = Provider.of<SettingsProvider>(context);
    final paymentSettings = settingsProvider.paymentSettings;

    if (_paymentMethod == null && paymentSettings.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _paymentMethod = paymentSettings.first.settingKey;
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => GoRouter.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _category!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payment Type:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            _getPaymentTypeText(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${_amount.toStringAsFixed(0)} Birr',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Billing Cycle:',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            _billingCycle.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (paymentSettings.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Methods',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...paymentSettings
                            .map(_buildPaymentMethodItem)
                            .toList(),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (paymentSettings.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Select Payment Method',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  items: paymentSettings.map((setting) {
                    return DropdownMenuItem<String>(
                      value: setting.settingKey,
                      child: Text(setting.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _paymentMethod = value);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a payment method';
                    }
                    return null;
                  },
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
                            SizedBox(height: 4),
                            Text(
                              'Max 5MB, JPG/PNG only',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
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
                    child: Text(
                        'I confirm that all payment information is accurate'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Payment',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
