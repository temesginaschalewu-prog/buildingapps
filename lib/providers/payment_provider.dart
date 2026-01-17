import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/payment_model.dart';
import '../models/setting_model.dart';
import '../utils/helpers.dart';

class PaymentProvider with ChangeNotifier {
  final ApiService apiService;

  List<Payment> _payments = [];
  List<Setting> _paymentSettings = [];
  bool _isLoading = false;
  String? _error;

  PaymentProvider({required this.apiService});

  List<Payment> get payments => List.unmodifiable(_payments);
  List<Setting> get paymentSettings => List.unmodifiable(_paymentSettings);
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Payment> getPendingPayments() {
    return _payments.where((p) => p.isPending).toList();
  }

  List<Payment> getVerifiedPayments() {
    return _payments.where((p) => p.isVerified).toList();
  }

  List<Payment> getRejectedPayments() {
    return _payments.where((p) => p.isRejected).toList();
  }

  Future<void> loadPayments() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider', 'Loading payments');
      final response = await apiService.getMyPayments();
      _payments = response.data ?? [];
      debugLog('PaymentProvider', 'Loaded payments: ${_payments.length}');
    } catch (e) {
      _error = e.toString();
      debugLog('PaymentProvider', 'loadPayments error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> loadPaymentSettings() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider', 'Loading payment settings');
      final response = await apiService.getSettingsByCategory('payment');
      _paymentSettings = response.data ?? [];
      debugLog('PaymentProvider',
          'Loaded payment settings: ${_paymentSettings.length}');
    } catch (e) {
      _error = e.toString();
      debugLog('PaymentProvider', 'loadPaymentSettings error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<Map<String, dynamic>> submitPayment({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
    String? proofImagePath,
  }) async {
    if (_isLoading) return {};

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider',
          'Submitting payment category:$categoryId amount:$amount proof:$proofImagePath');

      final response = await apiService.submitPayment(
        categoryId: categoryId,
        paymentType: paymentType,
        paymentMethod: paymentMethod,
        amount: amount,
        proofImagePath: proofImagePath,
      );

      // Debug the response
      debugLog('PaymentProvider', 'Submit payment response: ${response.data}');

      // Ensure we return a Map<String, dynamic>
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      } else {
        debugLog('PaymentProvider',
            'Response data is not a map: ${response.data.runtimeType}');
        return {'success': false, 'message': 'Invalid response format'};
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('PaymentProvider', 'submitPayment error: $e\n$stackTrace');

      // Return error map
      return {
        'success': false,
        'message': e.toString(),
        'error': e.toString(),
      };
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Setting? getPaymentSetting(String key) {
    try {
      return _paymentSettings.firstWhere((s) => s.settingKey == key);
    } catch (e) {
      return null;
    }
  }

  String getPaymentInstructions() {
    final setting = getPaymentSetting('payment_instructions');
    return setting?.settingValue ??
        'Please contact support for payment instructions.';
  }

  String getBankName() {
    final setting = getPaymentSetting('payment_bank_name');
    return setting?.settingValue ?? 'Commercial Bank of Ethiopia';
  }

  String getAccountNumber() {
    final setting = getPaymentSetting('payment_account_number');
    return setting?.settingValue ?? '100034567890';
  }

  String getTelebirrNumber() {
    final setting = getPaymentSetting('payment_telebirr_number');
    return setting?.settingValue ?? '+251912345678';
  }

  void clearPayments() {
    _payments = [];
    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}
