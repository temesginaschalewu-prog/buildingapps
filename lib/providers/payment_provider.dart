// lib/providers/payment_provider.dart
// PRODUCTION-READY FINAL VERSION - INCREASED TIMEOUT TO 20 SECONDS

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/payment_model.dart';
import '../utils/api_response.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Payment Provider with Full Offline Support
class PaymentProvider extends ChangeNotifier
    with
        BaseProvider<PaymentProvider>,
        OfflineAwareProvider<PaymentProvider>,
        BackgroundRefreshMixin<PaymentProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  List<Payment> _payments = [];

  static const Duration _cacheDuration = AppConstants.cacheTTLPayments;
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _paymentsBox;

  int _apiCallCount = 0;

  bool _hasLoadedPayments = false;
  bool _hasInitialData = false;

  late StreamController<List<Payment>> _paymentsUpdateController;

  PaymentProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) : _paymentsUpdateController = StreamController<List<Payment>>.broadcast() {
    log('PaymentProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionSubmitPayment,
      _processPaymentSubmission,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processPaymentSubmission(Map<String, dynamic> data) async {
    try {
      log('Processing offline payment submission');

      final response = await apiService.submitPayment(
        categoryId: data['categoryId'],
        paymentType: data['paymentType'],
        paymentMethod: data['paymentMethod'],
        amount: data['amount'],
        accountHolderName: data['accountHolderName'],
        proofImagePath: data['proofImagePath'],
      );

      if (response.success) {
        await loadPayments(forceRefresh: true);
      }

      return response.success;
    } catch (e) {
      log('Error processing payment submission: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedPayments();

    if (_payments.isNotEmpty) {
      startBackgroundRefresh();
      _hasLoadedPayments = true;
      _hasInitialData = true;
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hivePaymentsBox)) {
        _paymentsBox =
            await Hive.openBox<dynamic>(AppConstants.hivePaymentsBox);
      } else {
        _paymentsBox = Hive.box<dynamic>(AppConstants.hivePaymentsBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  Future<void> _loadCachedPayments() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _paymentsBox == null) return;

      final cachedKey = 'user_${userId}_payments';
      final cachedPayments = _paymentsBox!.get(cachedKey);

      if (cachedPayments != null && cachedPayments is List) {
        final List<Payment> payments = [];
        for (final item in cachedPayments) {
          if (item is Payment) {
            payments.add(item);
          } else if (item is Map<String, dynamic>) {
            payments.add(Payment.fromJson(item));
          }
        }

        if (payments.isNotEmpty) {
          _payments = payments;
          log('✅ Loaded ${_payments.length} payments from Hive');
        }
      }
    } catch (e) {
      log('Error loading cached payments: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _paymentsBox == null) return;

      final cacheKey = 'user_${userId}_payments';
      await _paymentsBox!.put(cacheKey, _payments);
      log('💾 Saved ${_payments.length} payments to Hive');
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  Future<void> _cachePendingPaymentFromSubmission({
    required int categoryId,
    required String paymentType,
    required double amount,
    required String paymentMethod,
    String? accountHolderName,
    Map<String, dynamic>? responseData,
  }) async {
    try {
      final pendingPayment = Payment(
        id: responseData?['id'] is num
            ? (responseData!['id'] as num).toInt()
            : DateTime.now().millisecondsSinceEpoch,
        paymentType: responseData?['payment_type']?.toString() ?? paymentType,
        amount: responseData?['amount'] != null
            ? (responseData!['amount'] as num).toDouble()
            : amount,
        paymentMethod:
            responseData?['payment_method']?.toString() ?? paymentMethod,
        accountHolderName:
            responseData?['account_holder_name']?.toString() ??
                accountHolderName,
        status: responseData?['status']?.toString() ?? 'pending',
        createdAt: DateTime.tryParse(
              responseData?['created_at']?.toString() ?? '',
            ) ??
            DateTime.now(),
        categoryName: responseData?['category_name']?.toString() ?? '',
        verifiedAt: DateTime.tryParse(
          responseData?['verified_at']?.toString() ?? '',
        ),
        rejectionReason: responseData?['rejection_reason']?.toString(),
        categoryId: responseData?['category_id'] is num
            ? (responseData!['category_id'] as num).toInt()
            : categoryId,
      );

      _payments.removeWhere((payment) =>
          payment.categoryId == categoryId &&
          (payment.isPending || payment.isRejected));
      _payments.insert(0, pendingPayment);
      _hasLoadedPayments = true;
      _hasInitialData = true;

      await _saveToHive();
      deviceService.saveCacheItem(
        AppConstants.paymentsCacheKey,
        _payments.map((p) => p.toJson()).toList(),
        ttl: _cacheDuration,
        isUserSpecific: true,
      );
      _paymentsUpdateController.add(_payments);
      safeNotify();
      log('💾 Cached submitted payment locally as pending');
    } catch (e) {
      log('⚠️ Failed to cache submitted payment locally: $e');
    }
  }

  // ===== GETTERS =====
  List<Payment> get payments => List.unmodifiable(_payments);

  bool get hasLoadedPayments => _hasLoadedPayments;
  bool get hasInitialData => _hasInitialData;

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

  // ===== LOAD PAYMENTS =====
  Future<void> loadPayments({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadPayments() CALL #$callId');

    if (isManualRefresh && isOffline) {
      if (_payments.isNotEmpty) {
        clearError();
        _paymentsUpdateController.add(_payments);
        setLoaded();
        return;
      }
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (_hasLoadedPayments && !forceRefresh && !isManualRefresh) {
      log('✅ Already have payments, returning cached');
      _paymentsUpdateController.add(_payments);
      setLoaded();
      return;
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, waiting...');
      int attempts = 0;
      while (isLoading && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      if (_hasLoadedPayments) {
        log('✅ Got payments from existing load');
        _paymentsUpdateController.add(_payments);
        setLoaded();
        return;
      }
    }

    setLoading();

    try {
      // STEP 1: Try Hive first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _paymentsBox != null) {
          final cachedKey = 'user_${userId}_payments';
          final cachedPayments = _paymentsBox!.get(cachedKey);

          if (cachedPayments != null && cachedPayments is List) {
            final List<Payment> payments = [];
            for (final item in cachedPayments) {
              if (item is Payment) {
                payments.add(item);
              } else if (item is Map<String, dynamic>) {
                payments.add(Payment.fromJson(item));
              }
            }
            if (payments.isNotEmpty) {
              _payments = payments;
              _hasLoadedPayments = true;
              _hasInitialData = true;
              setLoaded();
              _paymentsUpdateController.add(_payments);
              log('✅ Using cached payments from Hive');

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshInBackground());
              }
              return;
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache');
        final cachedPayments = await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.paymentsCacheKey,
          isUserSpecific: true,
        );

        if (cachedPayments != null) {
          final List<Payment> payments = [];
          for (final json in cachedPayments) {
            if (json is Map<String, dynamic>) {
              payments.add(Payment.fromJson(json));
            }
          }
          if (payments.isNotEmpty) {
            _payments = payments;
            _hasLoadedPayments = true;
            _hasInitialData = true;
            setLoaded();
            _paymentsUpdateController.add(_payments);

            await _saveToHive();
            log('✅ Using cached payments from DeviceService');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground());
            }
            return;
          }
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_payments.isNotEmpty) {
          _hasLoadedPayments = true;
          setLoaded();
          _paymentsUpdateController.add(_payments);
          log('✅ Showing cached payments offline');
          return;
        }

        setError('You are offline. No cached payments available.');
        setLoaded();
        _paymentsUpdateController.add(_payments);

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      // STEP 4: Fetch from API with increased timeout
      log('STEP 4: Fetching from API');
      final response = await apiService.getMyPayments().timeout(
        const Duration(seconds: 20), // ✅ INCREASED from 15 to 20 seconds
        onTimeout: () {
          log('⏱️ API timeout in loadPayments - using cached data');
          if (_payments.isNotEmpty) {
            _hasLoadedPayments = true;
            setLoaded();
            _paymentsUpdateController.add(_payments);
            return ApiResponse<List<Payment>>(
              success: true,
              message: 'Using cached payments (server timeout)',
              data: _payments,
            );
          }
          return ApiResponse<List<Payment>>(
            success: false,
            message: 'Request timed out. Please try again.',
            data: [],
          );
        },
      );

      if (response.success) {
        _payments = response.data ?? [];
        log('✅ Received ${_payments.length} payments from API');
        _hasLoadedPayments = true;
        _hasInitialData = _payments.isNotEmpty;
        setLoaded();

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.paymentsCacheKey,
          _payments.map((p) => p.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _paymentsUpdateController.add(_payments);
        log('✅ Success! Payments loaded');
      } else {
        if (_payments.isNotEmpty) {
          clearError();
          log('⚠️ API refresh failed, keeping cached payments');
          setLoaded();
          _paymentsUpdateController.add(_payments);
          return;
        }

        setError(getUserFriendlyErrorMessage(response.message));
        log('❌ API error: ${response.message}');
        setLoaded();

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading payments: $e');

      if (_payments.isEmpty) {
        setError(getUserFriendlyErrorMessage(e));
        setLoaded();
        await _recoverFromCache();
      } else {
        clearError();
        setLoaded();
      }

      _paymentsUpdateController.add(_payments);

      if (isManualRefresh && _payments.isEmpty) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  Future<void> _refreshInBackground() async {
    if (isOffline) return;

    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

    try {
      final response = await apiService.getMyPayments().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          log('⏱️ Background refresh timeout for payments');
          return ApiResponse<List<Payment>>(
            success: false,
            message: 'Timeout',
          );
        },
      );

      if (response.success) {
        _payments = response.data ?? [];

        await _saveToHive();

        deviceService.saveCacheItem(
          AppConstants.paymentsCacheKey,
          _payments.map((p) => p.toJson()).toList(),
          ttl: _cacheDuration,
          isUserSpecific: true,
        );

        _paymentsUpdateController.add(_payments);
        log('🔄 Background refresh complete');
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  Future<void> _recoverFromCache() async {
    log('Attempting cache recovery');
    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _paymentsBox != null) {
      try {
        final cachedKey = 'user_${userId}_payments';
        final cachedPayments = _paymentsBox!.get(cachedKey);
        if (cachedPayments != null && cachedPayments is List) {
          final List<Payment> payments = [];
          for (final item in cachedPayments) {
            if (item is Payment) {
              payments.add(item);
            } else if (item is Map<String, dynamic>) {
              payments.add(Payment.fromJson(item));
            }
          }
          if (payments.isNotEmpty) {
            _payments = payments;
            _hasLoadedPayments = true;
            _hasInitialData = true;
            _paymentsUpdateController.add(_payments);
            log('✅ Recovered ${payments.length} payments from Hive after error');
            return;
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    try {
      final cachedPayments = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.paymentsCacheKey,
        isUserSpecific: true,
      );
      if (cachedPayments != null && cachedPayments.isNotEmpty) {
        final List<Payment> payments = [];
        for (final json in cachedPayments) {
          if (json is Map<String, dynamic>) {
            payments.add(Payment.fromJson(json));
          }
        }

        if (payments.isNotEmpty) {
          _payments = payments;
          _hasLoadedPayments = true;
          _hasInitialData = true;
          _paymentsUpdateController.add(_payments);
          log('✅ Recovered ${payments.length} payments from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  Future<ApiResponse<String>> uploadPaymentProof(File imageFile) async {
    log('uploadPaymentProof()');

    if (isOffline) {
      log('📴 Cannot upload payment proof offline');
      return ApiResponse.offline(
        message:
            'Cannot upload payment proof while offline. Please connect and try again.',
      );
    }

    setLoading();

    try {
      final response = await apiService.uploadPaymentProof(imageFile);
      setLoaded();
      return response;
    } catch (e) {
      setLoaded();
      setError(getUserFriendlyErrorMessage(e));
      log('❌ Error uploading proof: $e');
      return ApiResponse.error(message: getUserFriendlyErrorMessage(e));
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> submitPayment({
    required int categoryId,
    required String paymentType,
    required String paymentMethod,
    required double amount,
    String? accountHolderName,
    String? proofImagePath,
  }) async {
    log('submitPayment() for category $categoryId');

    if (isLoading) {
      log('⏳ Payment submission already in progress');
      return ApiResponse.error(
        message: 'Payment is already being processed. Please wait.',
      );
    }

    if (isOffline) {
      log('📴 Offline - queuing payment');
      await _queuePaymentOffline({
        'categoryId': categoryId,
        'paymentType': paymentType,
        'paymentMethod': paymentMethod,
        'amount': amount,
        'accountHolderName': accountHolderName,
        'proofImagePath': proofImagePath,
      });

      setLoaded();
      return ApiResponse.queued(
        message: 'Payment saved offline. Will submit when online.',
      );
    }

    setLoading();

    try {
      final response = await apiService.submitPayment(
        categoryId: categoryId,
        paymentType: paymentType,
        paymentMethod: paymentMethod,
        amount: amount,
        accountHolderName: accountHolderName,
        proofImagePath: proofImagePath,
      );

      if (response.success) {
        log('✅ Payment submitted successfully');
        await _cachePendingPaymentFromSubmission(
          categoryId: categoryId,
          paymentType: paymentType,
          amount: amount,
          paymentMethod: paymentMethod,
          accountHolderName: accountHolderName,
          responseData: response.data,
        );

        await loadPayments(forceRefresh: true);
      }

      setLoaded();
      return response;
    } catch (e) {
      setLoaded();
      setError(getUserFriendlyErrorMessage(e));
      log('❌ Error submitting payment: $e');
      return ApiResponse.error(message: getUserFriendlyErrorMessage(e));
    }
  }

  Future<void> _queuePaymentOffline(Map<String, dynamic> paymentData) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionSubmitPayment,
        data: {
          ...paymentData,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      log('📝 Queued payment for offline sync');
    } catch (e) {
      log('Error queueing payment: $e');
    }
  }

  @override
  Future<void> onBackgroundRefresh() async {
    if (!isOffline && _payments.isNotEmpty) {
      await _refreshInBackground();
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing payments');
    await loadPayments();
  }

  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_paymentsBox != null) {
        final cacheKey = 'user_${userId}_payments';
        await _paymentsBox!.delete(cacheKey);
      }

      await deviceService.clearCacheByPrefix('payment');
    }

    stopBackgroundRefresh();
    _payments = [];
    _hasLoadedPayments = false;
    _hasInitialData = false;

    await _paymentsUpdateController.close();
    _paymentsUpdateController = StreamController<List<Payment>>.broadcast();
    _paymentsUpdateController.add(_payments);

    safeNotify();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _paymentsUpdateController.close();
    _paymentsBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
