import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:flutter/material.dart';
import '../utils/helpers.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();

  bool _isOnline = true;
  bool _isInitialized = false;
  final List<VoidCallback> _listeners = [];

  Stream<bool> get onConnectivityChanged => _connectionStatusController.stream;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _checkConnectivity();

      _connectivity.onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        final isOnline =
            results.isNotEmpty && results.first != ConnectivityResult.none;
        _handleConnectivityChange(isOnline);
      });

      _isInitialized = true;
      debugLog('ConnectivityService', '✅ Initialized. Online: $_isOnline');
    } catch (e) {
      debugLog('ConnectivityService', '❌ Initialization error: $e');
      _isOnline = false;
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();
      _isOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      return _isOnline;
    } catch (e) {
      debugLog('ConnectivityService', 'Check error: $e');
      _isOnline = false;
      return false;
    }
  }

  Future<void> _checkConnectivity() async {
    await checkConnectivity();
  }

  void _handleConnectivityChange(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _connectionStatusController.add(_isOnline);
      _notifyListeners();

      debugLog('ConnectivityService',
          'Status changed: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
    }
  }

  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener.call();
    }
  }

  void dispose() {
    _connectionStatusController.close();
    _listeners.clear();
  }

  Future<bool> ensureOnline(BuildContext context, {String? action}) async {
    if (_isOnline) return true;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action != null
                ? 'Cannot $action while offline. Please check your connection.'
                : 'You are offline. Please check your internet connection.',
          ),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return false;
  }
}
