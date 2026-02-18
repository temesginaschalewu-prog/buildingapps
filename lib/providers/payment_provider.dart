import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/payment_model.dart';
import '../models/setting_model.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class PaymentProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  List<Payment> _payments = [];
  bool _isLoading = false;
  String? _error;

  Timer? _refreshTimer;
  StreamController<List<Payment>> _paymentsUpdateController =
      StreamController<List<Payment>>.broadcast();

  static const Duration _cacheDuration = Duration(minutes: 10);
  static const Duration _refreshInterval = Duration(minutes: 5);

  PaymentProvider({required this.apiService, required this.deviceService}) {
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshDataInBackground();
    });
  }

  List<Payment> get payments => List.unmodifiable(_payments);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<Payment>> get paymentsUpdates => _paymentsUpdateController.stream;

  List<Payment> getPendingPayments() {
    return _payments.where((p) => p.isPending).toList();
  }

  List<Payment> getVerifiedPayments() {
    return _payments.where((p) => p.isVerified).toList();
  }

  List<Payment> getRejectedPayments() {
    return _payments.where((p) => p.isRejected).toList();
  }

  Future<void> _refreshDataInBackground() async {
    if (_isLoading) return;

    try {
      debugLog('PaymentProvider', '🔄 Background refresh of payment data');
      await _loadPaymentsFromCacheOrApi(forceRefresh: true);
    } catch (e) {
      debugLog('PaymentProvider', 'Background refresh error: $e');
    }
  }

  Future<void> loadPayments({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider', 'Loading payments');
      await _loadPaymentsFromCacheOrApi(forceRefresh: forceRefresh);
    } catch (e) {
      _error = e.toString();
      debugLog('PaymentProvider', 'loadPayments error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _loadPaymentsFromCacheOrApi({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cachedPayments =
          await deviceService.getCacheItem<List<Payment>>('payments');
      if (cachedPayments != null) {
        _payments = cachedPayments;
        _paymentsUpdateController.add(_payments);
        debugLog('PaymentProvider',
            'Loaded ${_payments.length} payments from cache');
        return;
      }
    }

    final response = await apiService.getMyPayments();
    _payments = response.data ?? [];

    await deviceService.saveCacheItem('payments', _payments,
        ttl: _cacheDuration);
    _paymentsUpdateController.add(_payments);

    debugLog('PaymentProvider', 'Loaded payments: ${_payments.length}');
  }

  Future<Map<String, dynamic>> submitPayment({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
    String? accountHolderName,
    String? proofImagePath,
  }) async {
    if (_isLoading) return {'success': false, 'message': 'Already processing'};

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider',
          'Submitting payment category:$categoryId amount:$amount method:$paymentMethod accountHolder:$accountHolderName proof:$proofImagePath');

      final apiResponse = await apiService.submitPayment(
        categoryId: categoryId,
        paymentType: paymentType,
        paymentMethod: paymentMethod,
        amount: amount,
        accountHolderName: accountHolderName,
        proofImagePath: proofImagePath,
      );

      debugLog(
          'PaymentProvider', 'Submit payment response: ${apiResponse.data}');
      debugLog(
          'PaymentProvider', 'Submit payment success: ${apiResponse.success}');
      debugLog(
          'PaymentProvider', 'Submit payment message: ${apiResponse.message}');

      if (apiResponse.success) {
        await deviceService.removeCacheItem('payments');
        await _loadPaymentsFromCacheOrApi(forceRefresh: true);
      }

      return {
        'success': apiResponse.success,
        'message': apiResponse.message,
        'data': apiResponse.data,
      };
    } catch (e, stackTrace) {
      _error = e.toString();
      debugLog('PaymentProvider', 'submitPayment error: $e\n$stackTrace');

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

  Future<void> clearUserData() async {
    debugLog('PaymentProvider', 'Clearing payment data');

    await deviceService.clearCacheByPrefix('payment');

    _payments = [];

    _paymentsUpdateController.close();
    _paymentsUpdateController = StreamController<List<Payment>>.broadcast();

    _paymentsUpdateController.add(_payments);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _paymentsUpdateController.close();
    super.dispose();
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
