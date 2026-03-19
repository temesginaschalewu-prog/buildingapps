// lib/providers/base_provider.dart
// COMPLETE FIXED VERSION - WITH SAFE CONTEXT PATTERN

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/offline_queue_manager.dart';
import '../utils/helpers.dart';

enum ProviderState { initial, loading, loaded, error, offline, queued }

mixin BaseProvider<T extends ChangeNotifier> on ChangeNotifier {
  ProviderState _state = ProviderState.initial;
  String? _errorMessage;
  bool _isInitialized = false;
  final List<StreamSubscription> _subscriptions = [];

  ProviderState get state => _state;
  bool get isLoading => _state == ProviderState.loading;
  bool get isLoaded => _state == ProviderState.loaded;
  bool get hasError => _state == ProviderState.error;
  bool get isOffline => _state == ProviderState.offline;
  bool get isQueued => _state == ProviderState.queued;
  String? get errorMessage => _errorMessage;
  bool get isInitialized => _isInitialized;

  void setState(ProviderState newState, {String? error}) {
    if (_state != newState || (error != null && error != _errorMessage)) {
      _state = newState;
      _errorMessage = error;
      safeNotify();
    }
  }

  void setLoading() => setState(ProviderState.loading);

  void setLoaded() {
    if (_state == ProviderState.error) {
      _errorMessage = null;
    }
    setState(ProviderState.loaded);
  }

  void setOffline() => setState(ProviderState.offline);
  void setQueued() => setState(ProviderState.queued);

  void setError(String message) {
    setState(ProviderState.error, error: message);
    _state = ProviderState.loaded;
    safeNotify();
  }

  void clearError() {
    if (_state == ProviderState.error) {
      _state = ProviderState.initial;
      _errorMessage = null;
      safeNotify();
    }
  }

  void markInitialized() {
    _isInitialized = true;
    safeNotify();
  }

  void safeNotify() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }

  void addSubscription(StreamSubscription subscription) {
    _subscriptions.add(subscription);
  }

  void disposeSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  Future<R> runWithLoading<R>(Future<R> Function() action) async {
    try {
      setLoading();
      clearError();
      return await action();
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e));
      rethrow;
    } finally {
      setLoaded();
    }
  }

  String getCacheKey(String base,
      {bool isUserSpecific = false, String? userId}) {
    if (!isUserSpecific || userId == null) return base;
    return 'user_${userId}_$base';
  }

  void log(String message) {
    debugLog('${(this as T).runtimeType}', message);
  }
}

mixin OfflineAwareProvider<T extends ChangeNotifier> on BaseProvider<T> {
  late final ConnectivityService connectivityService;
  late final OfflineQueueManager queueManager;

  void initializeOfflineAware({
    required ConnectivityService connectivity,
    required OfflineQueueManager queue,
  }) {
    connectivityService = connectivity;
    queueManager = queue;

    addSubscription(
      connectivityService.onConnectivityChanged.listen(_onConnectivityChanged),
    );

    if (!connectivityService.isOnline) {
      setOffline();
    }
  }

  void _onConnectivityChanged(bool isOnline) {
    log('Connectivity changed: ${isOnline ? 'ONLINE' : 'OFFLINE'}');

    if (isOnline) {
      if (state == ProviderState.offline || state == ProviderState.queued) {
        _onOnline();
      }
    } else {
      setOffline();
      _onOffline();
    }
  }

  Future<void> _onOnline() async {
    log('Online - processing queue and refreshing');
    await queueManager.processQueue();
    await onOnlineRefresh();

    if (queueManager.pendingCount > 0) {
      setQueued();
    } else {
      setLoaded();
    }
  }

  void _onOffline() {
    log('Offline - showing cached data');
  }

  Future<void> onOnlineRefresh() async {}

  bool ensureOnline({required BuildContext context, String? action}) {
    if (connectivityService.isOnline) return true;
    return false;
  }

  String queueAction(String type, Map<String, dynamic> data) {
    return queueManager.addItem(type: type, data: data);
  }
}

mixin BackgroundRefreshMixin<T extends ChangeNotifier> on BaseProvider<T> {
  Timer? _refreshTimer;
  Duration get refreshInterval => const Duration(minutes: 5);
  bool get enableBackgroundRefresh => true;

  void startBackgroundRefresh() {
    if (!enableBackgroundRefresh) return;

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(refreshInterval, (_) {
      if (!isLoading && !isOffline) {
        log('Background refresh triggered');
        onBackgroundRefresh();
      }
    });
  }

  void stopBackgroundRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> onBackgroundRefresh() async {}

  @override
  void disposeSubscriptions() {
    stopBackgroundRefresh();
    super.disposeSubscriptions();
  }
}
