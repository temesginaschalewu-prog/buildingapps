import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:flutter/material.dart';
import 'snackbar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/helpers.dart';

enum ConnectionQuality { none, poor, fair, good, excellent }

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  final StreamController<ConnectionQuality> _connectionQualityController =
      StreamController<ConnectionQuality>.broadcast();
  final List<VoidCallback> _onlineListeners = [];
  final List<VoidCallback> _offlineListeners = [];

  bool _isOnline = true;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;
  ConnectionQuality _connectionQuality = ConnectionQuality.good;

  Stream<bool> get onConnectivityChanged => _connectionStatusController.stream;
  Stream<ConnectionQuality> get onConnectionQualityChanged =>
      _connectionQualityController.stream;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isInitialized => _isInitialized;
  DateTime? get lastSyncTime => _lastSyncTime;
  ConnectionQuality get connectionQuality => _connectionQuality;

  // Quality thresholds in milliseconds
  static const int _excellentThreshold = 100;
  static const int _goodThreshold = 300;
  static const int _fairThreshold = 800;

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugLog('ConnectivityService', 'Starting initialization');

    try {
      await checkConnectivity();
      await _loadLastSyncTime();

      _connectivity.onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        final isOnline =
            results.isNotEmpty && results.first != ConnectivityResult.none;
        _handleConnectivityChange(isOnline);
      });

      // Re-check backend reachability periodically so cached/offline UI can
      // switch states even when the network link itself has not changed.
      Timer.periodic(const Duration(seconds: 30), (_) {
        unawaited(checkConnectivity());
      });

      _isInitialized = true;
      debugLog('ConnectivityService', 'Initialized. Online: $_isOnline');
    } catch (e) {
      debugLog('ConnectivityService', 'Initialization error: $e');
      _isOnline = true;
      _isInitialized = true;
    }
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(AppConstants.lastSyncTimeKey);
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
      }
    } catch (e) {
      debugLog('ConnectivityService', 'Error loading last sync time: $e');
    }
  }

  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));

      final bool hasNetwork =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      if (hasNetwork) {
        final backendReachable =
            await _probeUrl('${AppConstants.apiBaseUrl}${AppConstants.healthEndpoint}');

        if (backendReachable) {
          _handleConnectivityChange(true);
          unawaited(checkConnectionQuality());
        } else {
          debugLog(
            'ConnectivityService',
            'Backend is unreachable; switching to offline mode so cached data can be used',
          );
          _handleConnectivityChange(false);
        }
      } else {
        _handleConnectivityChange(false);
      }

      return _isOnline;
    } catch (e) {
      debugLog('ConnectivityService', 'Connectivity check error: $e');
      _handleConnectivityChange(false);
      return false;
    }
  }

  Future<void> checkConnectionQuality() async {
    if (!_isOnline) {
      _connectionQuality = ConnectionQuality.none;
      _connectionQualityController.add(_connectionQuality);
      return;
    }

    try {
      final stopwatch = Stopwatch()..start();
      final dio = Dio();
      await dio.get(
        '${AppConstants.apiBaseUrl}${AppConstants.healthEndpoint}',
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      stopwatch.stop();

      final latency = stopwatch.elapsedMilliseconds;

      if (latency < _excellentThreshold) {
        _connectionQuality = ConnectionQuality.excellent;
      } else if (latency < _goodThreshold) {
        _connectionQuality = ConnectionQuality.good;
      } else if (latency < _fairThreshold) {
        _connectionQuality = ConnectionQuality.fair;
      } else {
        _connectionQuality = ConnectionQuality.poor;
      }

      _connectionQualityController.add(_connectionQuality);
      debugLog('ConnectivityService',
          'Connection quality: $_connectionQuality (${latency}ms)');
    } catch (e) {
      _connectionQuality = ConnectionQuality.none;
      _connectionQualityController.add(_connectionQuality);
      debugLog('ConnectivityService', 'Failed to check quality: $e');
    }
  }

  Future<bool> _probeUrl(String url) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
          validateStatus: (status) => status != null && status < 500,
          followRedirects: true,
        ),
      );
      return response.statusCode != null && response.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  void _handleConnectivityChange(bool isOnline) {
    if (_isOnline != isOnline) {
      _isOnline = isOnline;
      _connectionStatusController.add(_isOnline);
      _notifyListeners();

      if (isOnline) {
        unawaited(checkConnectionQuality());
      } else {
        _connectionQuality = ConnectionQuality.none;
        _connectionQualityController.add(_connectionQuality);
      }

      debugLog('ConnectivityService',
          'Status changed: ${_isOnline ? 'ONLINE' : 'OFFLINE'}');
    }
  }

  void addOnlineListener(VoidCallback callback) {
    _onlineListeners.add(callback);
  }

  void removeOnlineListener(VoidCallback callback) {
    _onlineListeners.remove(callback);
  }

  void addOfflineListener(VoidCallback callback) {
    _offlineListeners.add(callback);
  }

  void removeOfflineListener(VoidCallback callback) {
    _offlineListeners.remove(callback);
  }

  void _notifyListeners() {
    if (_isOnline) {
      for (final listener in _onlineListeners) {
        listener.call();
      }
    } else {
      for (final listener in _offlineListeners) {
        listener.call();
      }
    }
  }

  Future<bool> ensureOnline(BuildContext context, {String? action}) async {
    if (isOnline) return true;

    if (context.mounted) {
      SnackbarService().showOffline(context, action: action);
    }

    return false;
  }

  String getLastSyncTimeText() {
    if (_lastSyncTime == null) return 'Never';
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String getQualityMessage() {
    switch (_connectionQuality) {
      case ConnectionQuality.none:
        return 'Offline';
      case ConnectionQuality.poor:
        return 'Poor connection - videos may buffer';
      case ConnectionQuality.fair:
        return 'Fair connection';
      case ConnectionQuality.good:
        return 'Good connection';
      case ConnectionQuality.excellent:
        return 'Excellent connection';
    }
  }

  Color getQualityColor() {
    switch (_connectionQuality) {
      case ConnectionQuality.none:
        return Colors.red;
      case ConnectionQuality.poor:
        return Colors.orange;
      case ConnectionQuality.fair:
        return Colors.yellow;
      case ConnectionQuality.good:
        return Colors.green;
      case ConnectionQuality.excellent:
        return Colors.green;
    }
  }

  void dispose() {
    _connectionStatusController.close();
    _connectionQualityController.close();
    _onlineListeners.clear();
    _offlineListeners.clear();
  }
}
