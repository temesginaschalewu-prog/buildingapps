import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:flutter/material.dart';
import 'snackbar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/helpers.dart';

enum ConnectionQuality { none, poor, fair, good, excellent }
enum ConnectivityStatus { online, noNetwork, backendUnavailable }

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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _periodicCheckTimer;

  bool _isOnline = true;
  bool _isInitialized = false;
  bool _isCheckingConnectivity = false;
  bool _isCheckingQuality = false;
  DateTime? _lastSyncTime;
  DateTime? _lastConnectivityCheckAt;
  DateTime? _lastQualityCheckAt;
  ConnectionQuality _connectionQuality = ConnectionQuality.good;
  ConnectivityStatus _status = ConnectivityStatus.online;

  Stream<bool> get onConnectivityChanged => _connectionStatusController.stream;
  Stream<ConnectionQuality> get onConnectionQualityChanged =>
      _connectionQualityController.stream;
  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;
  bool get isInitialized => _isInitialized;
  DateTime? get lastSyncTime => _lastSyncTime;
  ConnectionQuality get connectionQuality => _connectionQuality;
  ConnectivityStatus get status => _status;
  bool get hasNetworkConnection => _status != ConnectivityStatus.noNetwork;
  bool get isBackendUnavailable =>
      _status == ConnectivityStatus.backendUnavailable;

  // Quality thresholds in milliseconds
  static const int _excellentThreshold = 100;
  static const int _goodThreshold = 300;
  static const int _fairThreshold = 800;
  static const Duration _connectivityCheckInterval = Duration(minutes: 2);
  static const Duration _qualityCheckInterval = Duration(minutes: 1);
  static const Duration _probeTimeout = Duration(seconds: 8);
  static const Duration _warmupRetryDelay = Duration(seconds: 6);

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugLog('ConnectivityService', 'Starting initialization');

    try {
      await checkConnectivity(force: true);
      await _loadLastSyncTime();

      _connectivitySubscription =
          _connectivity.onConnectivityChanged.listen((results) {
        final hasNetwork =
            results.isNotEmpty && results.first != ConnectivityResult.none;

        if (!hasNetwork) {
          _status = ConnectivityStatus.noNetwork;
          _handleConnectivityChange(false);
          return;
        }

        unawaited(checkConnectivity(force: true));
      });

      // Re-check backend reachability periodically so cached/offline UI can
      // switch states even when the network link itself has not changed.
      _periodicCheckTimer = Timer.periodic(_connectivityCheckInterval, (_) {
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

  Future<bool> checkConnectivity({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _isCheckingConnectivity &&
        _lastConnectivityCheckAt != null &&
        now.difference(_lastConnectivityCheckAt!) <
            _connectivityCheckInterval) {
      return _isOnline;
    }

    if (!force &&
        _lastConnectivityCheckAt != null &&
        now.difference(_lastConnectivityCheckAt!) <
            const Duration(seconds: 20)) {
      return _isOnline;
    }

    _isCheckingConnectivity = true;
    _lastConnectivityCheckAt = now;

    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));

      final bool hasNetwork =
          results.isNotEmpty && results.first != ConnectivityResult.none;

      if (hasNetwork) {
        final backendReachable = await _probeBackendReachability();

        if (backendReachable) {
          _status = ConnectivityStatus.online;
          _handleConnectivityChange(true);
          unawaited(checkConnectionQuality(force: force));
        } else {
          if (!_isInitialized && _isOnline) {
            _status = ConnectivityStatus.backendUnavailable;
            debugLog(
              'ConnectivityService',
              'Backend probe missed during startup warmup; keeping app online and retrying shortly',
            );
            unawaited(_scheduleWarmupRetry());
            return _isOnline;
          }

          debugLog(
            'ConnectivityService',
            'Backend is unreachable; using offline mode so cached data can be used',
          );
          _status = ConnectivityStatus.backendUnavailable;
          _handleConnectivityChange(false);
        }
      } else {
        _status = ConnectivityStatus.noNetwork;
        _handleConnectivityChange(false);
      }

      return _isOnline;
    } catch (e) {
      debugLog('ConnectivityService', 'Connectivity check error: $e');
      _status = ConnectivityStatus.noNetwork;
      _handleConnectivityChange(false);
      return false;
    } finally {
      _isCheckingConnectivity = false;
    }
  }

  Future<void> checkConnectionQuality({bool force = false}) async {
    if (!_isOnline) {
      _connectionQuality = ConnectionQuality.none;
      _connectionQualityController.add(_connectionQuality);
      return;
    }

    final now = DateTime.now();
    if (_isCheckingQuality) return;
    if (!force &&
        _lastQualityCheckAt != null &&
        now.difference(_lastQualityCheckAt!) < _qualityCheckInterval) {
      return;
    }

    _isCheckingQuality = true;
    _lastQualityCheckAt = now;

    try {
      final stopwatch = Stopwatch()..start();
      final dio = Dio();
      await dio.get(
        '${AppConstants.apiBaseUrl}${AppConstants.healthEndpoint}',
        options: Options(
          sendTimeout: _probeTimeout,
          receiveTimeout: _probeTimeout,
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
    } finally {
      _isCheckingQuality = false;
    }
  }

  Future<bool> _probeUrl(String url) async {
    try {
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(
          sendTimeout: _probeTimeout,
          receiveTimeout: _probeTimeout,
          validateStatus: (status) => status != null && status < 500,
          followRedirects: true,
        ),
      );
      return response.statusCode != null && response.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _probeBackendReachability() async {
    final healthUrl = '${AppConstants.apiBaseUrl}${AppConstants.healthEndpoint}';

    if (await _probeUrl(healthUrl)) {
      return true;
    }

    // Some deployments can temporarily fail the dedicated health route while
    // the main app server is still reachable. Treat a normal API/root
    // response as enough to keep the app online.
    if (await _probeUrl(AppConstants.apiBaseUrl)) {
      debugLog(
        'ConnectivityService',
        'Health endpoint failed but backend root is reachable; keeping app online',
      );
      return true;
    }

    await Future<void>.delayed(_warmupRetryDelay);

    if (await _probeUrl(AppConstants.apiBaseUrl)) {
      debugLog(
        'ConnectivityService',
        'Backend became reachable on retry; keeping app online',
      );
      return true;
    }

    return false;
  }

  Future<void> _scheduleWarmupRetry() async {
    await Future<void>.delayed(_warmupRetryDelay);
    await checkConnectivity(force: true);
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
      if (_status == ConnectivityStatus.backendUnavailable) {
        SnackbarService().showServerUnavailable(context, action: action);
      } else {
        SnackbarService().showNoInternet(context, action: action);
      }
    }

    return false;
  }

  String getOfflineReasonText() {
    switch (_status) {
      case ConnectivityStatus.online:
        return 'Online';
      case ConnectivityStatus.noNetwork:
        return 'No internet connection';
      case ConnectivityStatus.backendUnavailable:
        return 'Server unavailable';
    }
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
    _periodicCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _connectionStatusController.close();
    _connectionQualityController.close();
    _onlineListeners.clear();
    _offlineListeners.clear();
  }
}
