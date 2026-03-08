import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:familyacademyclient/services/platform_service.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/helpers.dart';

enum OfflineActionType {
  saveProgress,
  submitExam,
  submitPayment,
  markNotificationRead,
  updateProfile,
  saveAnswer,
  submitExamAnswer,
}

class OfflineAction {
  final String id;
  final OfflineActionType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final int retryCount;
  final String userId;

  OfflineAction({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.retryCount = 0,
    required this.userId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
        'userId': userId,
      };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
        id: json['id'],
        type: OfflineActionType.values[json['type']],
        data: Map<String, dynamic>.from(json['data']),
        timestamp: DateTime.parse(json['timestamp']),
        retryCount: json['retryCount'] ?? 0,
        userId: json['userId'],
      );
}

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  final List<OfflineAction> _offlineQueue = [];
  final List<VoidCallback> _onlineListeners = [];
  final List<VoidCallback> _offlineListeners = [];

  bool _isOnline = true;
  bool _isInitialized = false;
  bool _isProcessingQueue = false;
  DateTime? _lastSyncTime;

  bool _mockMode = false;
  bool _mockOnline = true;

  Stream<bool> get onConnectivityChanged => _connectionStatusController.stream;
  bool get isOnline => _mockMode ? _mockOnline : _isOnline;
  bool get isOffline => !isOnline;
  List<OfflineAction> get offlineQueue => List.unmodifiable(_offlineQueue);
  int get pendingActionsCount => _offlineQueue.length;
  DateTime? get lastSyncTime => _lastSyncTime;

  static const int _maxRetries = 3;

  void setMockOnline(bool online) {
    _mockMode = true;
    _mockOnline = online;
    _connectionStatusController.add(online);
    debugLog('ConnectivityService',
        '🖥️ Desktop mock mode: ${online ? 'ONLINE' : 'OFFLINE'}');
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugLog('ConnectivityService', 'Starting initialization');

    if (!PlatformService.isMobile) {
      debugLog('ConnectivityService',
          '🖥️ Desktop detected - using mock connectivity');
      _mockMode = true;
      _mockOnline = true;
      _isInitialized = true;
      _connectionStatusController.add(true);
      return;
    }

    try {
      await checkConnectivity().timeout(const Duration(seconds: 2));
      await _loadOfflineQueue();
      await _loadLastSyncTime();

      _connectivity.onConnectivityChanged
          .listen((List<ConnectivityResult> results) {
        final isOnline =
            results.isNotEmpty && results.first != ConnectivityResult.none;
        _handleConnectivityChange(isOnline);
      });

      _isInitialized = true;
      debugLog('ConnectivityService',
          '✅ Initialized. Online: $_isOnline, Pending: ${_offlineQueue.length}');
    } catch (e) {
      debugLog('ConnectivityService', '❌ Initialization error: $e');
      _isOnline = true;
      _isInitialized = true;
    }
  }

  Future<void> _loadOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(AppConstants.offlineQueueKey);
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _offlineQueue.clear();
        _offlineQueue.addAll(
          decoded.map((item) =>
              OfflineAction.fromJson(Map<String, dynamic>.from(item))),
        );
        debugLog('ConnectivityService',
            '📦 Loaded ${_offlineQueue.length} pending actions from queue');
      }
    } catch (e) {
      debugLog('ConnectivityService', 'Error loading offline queue: $e');
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

  Future<void> _saveOfflineQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson =
          jsonEncode(_offlineQueue.map((a) => a.toJson()).toList());
      await prefs.setString(AppConstants.offlineQueueKey, queueJson);
    } catch (e) {
      debugLog('ConnectivityService', 'Error saving offline queue: $e');
    }
  }

  Future<void> _updateLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          AppConstants.lastSyncTimeKey, _lastSyncTime!.toIso8601String());
    } catch (e) {
      debugLog('ConnectivityService', 'Error saving last sync time: $e');
    }
  }

  void queueAction(
      OfflineActionType type, Map<String, dynamic> data, String userId) {
    final action = OfflineAction(
      id: '${DateTime.now().millisecondsSinceEpoch}_${type.index}_${data.hashCode}',
      type: type,
      data: data,
      timestamp: DateTime.now(),
      userId: userId,
    );

    _offlineQueue.add(action);
    _saveOfflineQueue();

    debugLog('ConnectivityService',
        '📝 Queued action: ${type.name} (${_offlineQueue.length} total)');
  }

  Future<void> processQueueWithApi(dynamic apiService,
      {VoidCallback? onComplete}) async {
    if (_mockMode) {
      debugLog('ConnectivityService',
          '🖥️ Desktop mock mode - skipping queue processing');
      if (onComplete != null) onComplete();
      return;
    }

    if (_isProcessingQueue || _offlineQueue.isEmpty || !_isOnline) {
      if (onComplete != null) onComplete();
      return;
    }

    _isProcessingQueue = true;
    debugLog('ConnectivityService',
        '🔄 Processing ${_offlineQueue.length} offline actions');

    final actionsToProcess = List<OfflineAction>.from(_offlineQueue);
    final failedActions = <OfflineAction>[];
    int successCount = 0;

    for (final action in actionsToProcess) {
      bool success = false;

      try {
        switch (action.type) {
          case OfflineActionType.saveProgress:
            await apiService.saveUserProgress(
              chapterId: action.data['chapterId'],
              videoProgress: action.data['videoProgress'],
              notesViewed: action.data['notesViewed'],
              questionsAttempted: action.data['questionsAttempted'],
              questionsCorrect: action.data['questionsCorrect'],
            );
            success = true;
            successCount++;
            break;

          case OfflineActionType.submitExam:
            await apiService.submitExam(
              action.data['examResultId'],
              List<Map<String, dynamic>>.from(action.data['answers']),
            );
            success = true;
            successCount++;
            break;

          case OfflineActionType.submitPayment:
            await apiService.submitPayment(
              categoryId: action.data['categoryId'],
              paymentType: action.data['paymentType'],
              paymentMethod: action.data['paymentMethod'],
              amount: action.data['amount'],
              accountHolderName: action.data['accountHolderName'],
              proofImagePath: action.data['proofImagePath'],
            );
            success = true;
            successCount++;
            break;

          case OfflineActionType.markNotificationRead:
            await apiService.markNotificationAsRead(action.data['logId']);
            success = true;
            successCount++;
            break;

          case OfflineActionType.updateProfile:
            await apiService.updateMyProfile(
              email: action.data['email'],
              phone: action.data['phone'],
              profileImage: action.data['profileImage'],
            );
            success = true;
            successCount++;
            break;

          case OfflineActionType.saveAnswer:
            await apiService.checkAnswer(
              action.data['questionId'],
              action.data['selectedOption'],
            );
            success = true;
            successCount++;
            break;

          case OfflineActionType.submitExamAnswer:
            success = true;
            successCount++;
            break;
        }
      } catch (e) {
        debugLog('ConnectivityService', 'Action execution error: $e');
        success = false;
      }

      if (success) {
        _offlineQueue.removeWhere((a) => a.id == action.id);
      } else {
        if (action.retryCount < _maxRetries) {
          failedActions.add(OfflineAction(
            id: action.id,
            type: action.type,
            data: action.data,
            timestamp: action.timestamp,
            retryCount: action.retryCount + 1,
            userId: action.userId,
          ));
        } else {
          await _storeFailedAction(action);
        }
      }
    }

    if (failedActions.isNotEmpty) {
      _offlineQueue.clear();
      _offlineQueue.addAll(failedActions);
    }

    await _saveOfflineQueue();

    if (successCount > 0) {
      await _updateLastSyncTime();
    }

    _isProcessingQueue = false;

    debugLog('ConnectivityService',
        '✅ Queue processed. $successCount succeeded, ${_offlineQueue.length} remaining');

    if (onComplete != null) onComplete();
  }

  Future<void> _storeFailedAction(OfflineAction action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final failedKey = 'failed_actions_${action.userId}';
      final existing = prefs.getStringList(failedKey) ?? [];
      existing.add(jsonEncode(action.toJson()));
      await prefs.setStringList(failedKey, existing);
      debugLog('ConnectivityService',
          '⚠️ Stored permanently failed action: ${action.id}');
    } catch (e) {
      debugLog('ConnectivityService', 'Error storing failed action: $e');
    }
  }

  Future<bool> checkConnectivity() async {
    if (!PlatformService.isMobile) {
      debugLog('ConnectivityService',
          'checkConnectivity bypassed on desktop - returning true');
      return true;
    }

    try {
      debugLog('ConnectivityService', 'Performing connectivity check');
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 2));
      _isOnline =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      debugLog('ConnectivityService',
          'checkConnectivity result: ${_isOnline ? 'online' : 'offline'}');
      return _isOnline;
    } catch (e) {
      debugLog('ConnectivityService', 'Check error/timeout: $e');
      _isOnline = true;
      return true;
    }
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

  Future<void> clearUserQueue(String userId) async {
    _offlineQueue.removeWhere((a) => a.userId == userId);
    await _saveOfflineQueue();
    debugLog('ConnectivityService', '🧹 Cleared queue for user $userId');
  }

  void dispose() {
    _connectionStatusController.close();
    _onlineListeners.clear();
    _offlineListeners.clear();
  }

  Future<bool> ensureOnline(BuildContext context, {String? action}) async {
    if (isOnline) return true;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action != null
                ? 'Cannot $action while offline. Your changes will sync when online.'
                : 'You are offline. Showing cached content.',
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

  String getLastSyncTimeText() {
    if (_lastSyncTime == null) return 'Never';
    final diff = DateTime.now().difference(_lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
