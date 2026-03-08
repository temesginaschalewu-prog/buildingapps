import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/payment_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class PaymentProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;
  final ConnectivityService connectivityService;

  List<Payment> _payments = [];
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;

  Timer? _refreshTimer;
  StreamController<List<Payment>> _paymentsUpdateController =
      StreamController<List<Payment>>.broadcast();

  static const Duration _cacheDuration = AppConstants.cacheTTLPayments;
  static const Duration _refreshInterval = Duration(minutes: 5);

  PaymentProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
  }) {
    _setupConnectivityListener();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      _refreshDataInBackground();
    });
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        if (!_isOffline && _payments.isNotEmpty) {
          _refreshDataInBackground();
        }
        notifyListeners();
      }
    });
  }

  List<Payment> get payments => List.unmodifiable(_payments);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;

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
    if (_isLoading || _isOffline) return;

    try {
      debugLog('PaymentProvider', '🔄 Background refresh of payment data');
      await _loadPaymentsFromCacheOrApi(
          forceRefresh: true, isManualRefresh: false);
    } catch (e) {
      debugLog('PaymentProvider', 'Background refresh error: $e');
    }
  }

  Future<void> loadPayments(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    if (isManualRefresh) {
      forceRefresh = true;
    }

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('PaymentProvider', 'Loading payments');
      await _loadPaymentsFromCacheOrApi(
          forceRefresh: forceRefresh && !_isOffline,
          isManualRefresh: isManualRefresh);
    } catch (e) {
      _error = e.toString();
      debugLog('PaymentProvider', 'loadPayments error: $e');

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _loadPaymentsFromCacheOrApi(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    // STEP 1: ALWAYS try cache first (EVEN WHEN OFFLINE)
    if (!forceRefresh) {
      final cachedPayments = await deviceService
          .getCacheItem<List<Payment>>(AppConstants.paymentsCacheKey);
      if (cachedPayments != null) {
        _payments = cachedPayments;
        _paymentsUpdateController.add(_payments);
        debugLog('PaymentProvider',
            'Loaded ${_payments.length} payments from cache');

        // If this is a manual refresh and we're offline, throw exception
        if (isManualRefresh && _isOffline) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }
    }

    // STEP 2: If offline and no cache, throw error
    if (_isOffline) {
      debugLog('PaymentProvider', 'Offline - no cached data');
      if (isManualRefresh) {
        throw Exception(
            'Network error. Please check your internet connection.');
      }
      return;
    }

    // STEP 3: If online, fetch from API
    debugLog('PaymentProvider', 'Fetching payments from API');
    final response = await apiService.getMyPayments();
    _payments = response.data ?? [];

    await deviceService.saveCacheItem(AppConstants.paymentsCacheKey, _payments,
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
          'Submitting payment category:$categoryId amount:$amount method:$paymentMethod');

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

      if (apiResponse.data != null && apiResponse.data?['queued'] == true) {
        await _savePendingPaymentLocally({
          'categoryId': categoryId,
          'paymentType': paymentType,
          'paymentMethod': paymentMethod,
          'amount': amount,
          'accountHolderName': accountHolderName,
          'proofImagePath': proofImagePath,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }

      if (apiResponse.success) {
        await deviceService.removeCacheItem(AppConstants.paymentsCacheKey);
        await _loadPaymentsFromCacheOrApi(forceRefresh: true);
      }

      return {
        'success': apiResponse.success,
        'message': apiResponse.message,
        'data': apiResponse.data,
        'queued': apiResponse.data?['queued'] ?? false,
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

  Future<void> _savePendingPaymentLocally(
      Map<String, dynamic> paymentData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      final pendingKey = '${AppConstants.pendingPaymentsKey}_$userId';
      final existingJson = prefs.getString(pendingKey);
      List<Map<String, dynamic>> pendingPayments = [];

      if (existingJson != null) {
        try {
          pendingPayments =
              List<Map<String, dynamic>>.from(jsonDecode(existingJson));
        } catch (e) {
          debugLog('PaymentProvider', 'Error parsing pending payments: $e');
        }
      }

      pendingPayments.add(paymentData);
      await prefs.setString(pendingKey, jsonEncode(pendingPayments));

      debugLog('PaymentProvider',
          '📝 Saved pending payment locally (total: ${pendingPayments.length})');
    } catch (e) {
      debugLog('PaymentProvider', 'Error saving pending payment: $e');
    }
  }

  Future<void> syncPendingPayments() async {
    if (_isOffline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      final pendingKey = '${AppConstants.pendingPaymentsKey}_$userId';
      final existingJson = prefs.getString(pendingKey);

      if (existingJson == null) return;

      List<Map<String, dynamic>> pendingPayments = [];
      try {
        pendingPayments =
            List<Map<String, dynamic>>.from(jsonDecode(existingJson));
      } catch (e) {
        debugLog('PaymentProvider', 'Error parsing pending payments: $e');
        await prefs.remove(pendingKey);
        return;
      }

      if (pendingPayments.isEmpty) return;

      debugLog('PaymentProvider',
          '🔄 Syncing ${pendingPayments.length} pending payments');

      final List<Map<String, dynamic>> failedPayments = [];

      for (final payment in pendingPayments) {
        try {
          await apiService.submitPayment(
            categoryId: payment['categoryId'],
            paymentType: payment['paymentType'],
            paymentMethod: payment['paymentMethod'],
            amount: payment['amount'],
            accountHolderName: payment['accountHolderName'],
            proofImagePath: payment['proofImagePath'],
          );

          debugLog('PaymentProvider', '✅ Synced pending payment');
        } catch (e) {
          debugLog('PaymentProvider', '❌ Failed to sync payment: $e');
          failedPayments.add(payment);
        }
      }

      if (failedPayments.isEmpty) {
        await prefs.remove(pendingKey);
        debugLog('PaymentProvider', '✅ All pending payments synced');
      } else {
        await prefs.setString(pendingKey, jsonEncode(failedPayments));
        debugLog('PaymentProvider',
            '⚠️ ${failedPayments.length} payments still pending');
      }

      await loadPayments(forceRefresh: true);
    } catch (e) {
      debugLog('PaymentProvider', 'Error syncing pending payments: $e');
    }
  }

  Future<void> clearUserData() async {
    debugLog('PaymentProvider', 'Clearing payment data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('PaymentProvider', '✅ Same user - preserving payment cache');
      return;
    }

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${AppConstants.pendingPaymentsKey}_$userId');
    }

    await deviceService.clearCacheByPrefix('payment');

    _payments = [];

    await _paymentsUpdateController.close();
    _paymentsUpdateController = StreamController<List<Payment>>.broadcast();

    _paymentsUpdateController.add(_payments);

    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
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
