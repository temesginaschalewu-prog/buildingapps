// lib/services/offline_queue_manager.dart
// PRODUCTION FINAL - WITH PROCESSING STATE

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'api_service.dart';

enum QueuePriority { high, normal, low }

enum QueueStatus { pending, processing, completed, failed }

class QueueItem {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final QueuePriority priority;
  QueueStatus status;
  int retryCount;
  String? error;
  DateTime? lastAttempt;

  QueueItem({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.priority = QueuePriority.normal,
    this.status = QueueStatus.pending,
    this.retryCount = 0,
    this.error,
    this.lastAttempt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
        'priority': priority.index,
        'status': status.index,
        'retryCount': retryCount,
        'error': error,
        'lastAttempt': lastAttempt?.toIso8601String(),
      };

  factory QueueItem.fromJson(Map<String, dynamic> json) => QueueItem(
        id: json['id'],
        type: json['type'],
        data: Map<String, dynamic>.from(json['data']),
        timestamp: DateTime.parse(json['timestamp']),
        priority: QueuePriority.values[json['priority']],
        status: QueueStatus.values[json['status']],
        retryCount: json['retryCount'] ?? 0,
        error: json['error'],
        lastAttempt: json['lastAttempt'] != null
            ? DateTime.parse(json['lastAttempt'])
            : null,
      );

  bool get shouldRetry {
    if (retryCount >= AppConstants.maxQueueRetries) return false;
    if (lastAttempt == null) return true;
    final backoffDuration = Duration(
      seconds: AppConstants.queueRetryBaseSeconds * (1 << retryCount),
    );
    return DateTime.now().difference(lastAttempt!) > backoffDuration;
  }
}

class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();

  final List<QueueItem> _queue = [];
  final StreamController<List<QueueItem>> _queueStreamController =
      StreamController<List<QueueItem>>.broadcast();
  final Map<String, Future<bool> Function(Map<String, dynamic>)> _processors =
      {};

  Stream<List<QueueItem>> get queueStream => _queueStreamController.stream;
  List<QueueItem> get pendingItems =>
      _queue.where((item) => item.status == QueueStatus.pending).toList();
  List<QueueItem> get failedItems =>
      _queue.where((item) => item.status == QueueStatus.failed).toList();
  int get pendingCount => pendingItems.length;
  bool _isProcessing = false;

  // ✅ NEW: Public getter for processing state
  bool get isProcessing => _isProcessing;

  Timer? _retryTimer;
  Timer? _persistenceTimer;
  bool _useSharedPrefs = false;

  void setApiService(ApiService apiService) {}

  void registerProcessor(
      String type, Future<bool> Function(Map<String, dynamic>) processor) {
    _processors[type] = processor;
    debugLog('OfflineQueueManager', '✅ Registered processor for: $type');
  }

  Future<void> initialize() async {
    try {
      await _loadQueue();
      _setupConnectivityListener();
      _startPeriodicRetry();
      _startPersistenceTimer();
      debugLog('OfflineQueueManager',
          '✅ Initialized with ${_queue.length} items ($pendingCount pending)');
    } catch (e) {
      debugLog('OfflineQueueManager',
          '❌ Error initializing: $e, falling back to SharedPreferences');
      _useSharedPrefs = true;
      await _loadQueueFromPrefs();
    }
  }

  Future<String> _getQueueFilePath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return '${dir.path}/offline_queue.json';
    } catch (e) {
      _useSharedPrefs = true;
      return '';
    }
  }

  Future<void> _loadQueue() async {
    try {
      if (_useSharedPrefs) {
        await _loadQueueFromPrefs();
        return;
      }

      final filePath = await _getQueueFilePath();
      if (filePath.isEmpty) {
        await _loadQueueFromPrefs();
        return;
      }

      final file = File(filePath);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> decoded = jsonDecode(contents);
        _queue.clear();
        _queue.addAll(
          decoded.map(
              (item) => QueueItem.fromJson(Map<String, dynamic>.from(item))),
        );

        for (final item in _queue) {
          if (item.status == QueueStatus.processing) {
            item.status = QueueStatus.pending;
          }
        }

        debugLog('OfflineQueueManager',
            '📦 Loaded ${_queue.length} items from file ($pendingCount pending)');
        _queueStreamController.add(List.unmodifiable(_queue));
      }
    } catch (e) {
      debugLog('OfflineQueueManager',
          '⚠️ Error loading queue from file: $e, falling back to SharedPreferences');
      _useSharedPrefs = true;
      await _loadQueueFromPrefs();
    }
  }

  Future<void> _loadQueueFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(AppConstants.offlineQueueKey);
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue.clear();
        _queue.addAll(
          decoded.map(
              (item) => QueueItem.fromJson(Map<String, dynamic>.from(item))),
        );

        for (final item in _queue) {
          if (item.status == QueueStatus.processing) {
            item.status = QueueStatus.pending;
          }
        }

        debugLog('OfflineQueueManager',
            '📦 Loaded ${_queue.length} items from SharedPreferences ($pendingCount pending)');
        _queueStreamController.add(List.unmodifiable(_queue));
      }
    } catch (e) {
      debugLog('OfflineQueueManager',
          '⚠️ Error loading queue from SharedPreferences: $e');
    }
  }

  Future<void> _saveQueue() async {
    try {
      final queueJson =
          jsonEncode(_queue.map((item) => item.toJson()).toList());

      if (_useSharedPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.offlineQueueKey, queueJson);
      } else {
        final filePath = await _getQueueFilePath();
        if (filePath.isNotEmpty) {
          final file = File(filePath);
          await file.writeAsString(queueJson);
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(AppConstants.offlineQueueKey, queueJson);
        }
      }

      _queueStreamController.add(List.unmodifiable(_queue));
    } catch (e) {
      debugLog('OfflineQueueManager', '❌ Error saving queue: $e');
    }
  }

  void _startPersistenceTimer() {
    _persistenceTimer?.cancel();
    _persistenceTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _saveQueue());
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !_isProcessing) {
        debugLog('OfflineQueueManager', '📶 Online - processing queue');
        processQueue();
      }
    });
  }

  void _startPeriodicRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_isProcessing && pendingItems.isNotEmpty) {
        debugLog('OfflineQueueManager',
            '⏰ Periodic retry - $pendingCount items pending');
        processQueue();
      }
    });
  }

  String addItem({
    required String type,
    required Map<String, dynamic> data,
    QueuePriority priority = QueuePriority.normal,
  }) {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${type}_${data.hashCode}';
    final item = QueueItem(
      id: id,
      type: type,
      data: data,
      timestamp: DateTime.now(),
      priority: priority,
    );

    _queue.add(item);
    unawaited(_saveQueue());

    debugLog('OfflineQueueManager',
        '📝 Added: $type (priority: ${priority.name}) - Queue now has ${_queue.length} items');

    Connectivity().checkConnectivity().then((result) {
      if (result != ConnectivityResult.none && !_isProcessing) {
        processQueue();
      }
    });

    return id;
  }

  Future<void> processQueue() async {
    if (_isProcessing) {
      debugLog('OfflineQueueManager', '⏳ Already processing queue');
      return;
    }

    final pending = pendingItems;
    if (pending.isEmpty) {
      debugLog('OfflineQueueManager', '✅ No pending items to process');
      return;
    }

    _isProcessing = true;
    _queueStreamController.add(List.unmodifiable(_queue));
    debugLog('OfflineQueueManager', '🔄 Processing ${pending.length} items');

    pending.sort((a, b) {
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return priorityCompare;
      return a.timestamp.compareTo(b.timestamp);
    });

    int successCount = 0;
    int failureCount = 0;

    for (final item in pending) {
      if (item.status != QueueStatus.pending) continue;

      if (item.retryCount > 0 && !item.shouldRetry) {
        debugLog('OfflineQueueManager',
            '⏸️ Skipping ${item.type} - retry in cooldown (attempt ${item.retryCount})');
        continue;
      }

      item.status = QueueStatus.processing;
      item.lastAttempt = DateTime.now();
      _queueStreamController.add(List.unmodifiable(_queue));

      final bool success = await _processItem(item);

      if (success) {
        item.status = QueueStatus.completed;
        _queue.remove(item);
        successCount++;
        debugLog('OfflineQueueManager', '✅ Completed: ${item.type}');
      } else {
        item.status = QueueStatus.pending;
        item.retryCount++;
        failureCount++;

        if (item.retryCount >= AppConstants.maxQueueRetries) {
          item.status = QueueStatus.failed;
          debugLog('OfflineQueueManager',
              '❌ Failed permanently: ${item.type} after ${item.retryCount} attempts');
        } else {
          debugLog('OfflineQueueManager',
              '⚠️ Will retry ${item.type} (attempt ${item.retryCount}/${AppConstants.maxQueueRetries})');
        }
      }

      _queueStreamController.add(List.unmodifiable(_queue));
      await Future.delayed(const Duration(milliseconds: 500));
    }

    await _saveQueue();

    _isProcessing = false;
    _queueStreamController.add(List.unmodifiable(_queue));

    debugLog('OfflineQueueManager',
        '✅ Queue processed. $successCount succeeded, $failureCount failed, $pendingCount remaining');

    if (pendingItems.isNotEmpty) {
      const nextRetry = Duration(
        seconds: AppConstants.queueRetryBaseSeconds * 2,
      );
      Future.delayed(nextRetry, processQueue);
      debugLog('OfflineQueueManager',
          '⏰ Scheduled retry in ${nextRetry.inSeconds}s for $pendingCount items');
    }
  }

  Future<bool> _processItem(QueueItem item) async {
    final processor = _processors[item.type];
    if (processor == null) {
      debugLog('OfflineQueueManager',
          '❌ No processor registered for type: ${item.type}');
      return false;
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        debugLog('OfflineQueueManager',
            '📴 No connectivity, cannot process ${item.type}');
        return false;
      }

      return await processor(item.data);
    } catch (e, stackTrace) {
      debugLog('OfflineQueueManager',
          '❌ Error processing ${item.type}: $e\n$stackTrace');
      return false;
    }
  }

  Future<void> retryFailedItems() async {
    final failed = failedItems;
    if (failed.isEmpty) return;

    debugLog(
        'OfflineQueueManager', '🔄 Retrying ${failed.length} failed items');

    for (final item in failed) {
      item.status = QueueStatus.pending;
      item.retryCount = 0;
    }

    await _saveQueue();
    processQueue();
  }

  Future<void> clearCompleted() async {
    _queue.removeWhere((item) => item.status == QueueStatus.completed);
    await _saveQueue();
    debugLog('OfflineQueueManager', '🧹 Cleared completed items');
  }

  Future<void> clearFailed() async {
    _queue.removeWhere((item) => item.status == QueueStatus.failed);
    await _saveQueue();
    debugLog('OfflineQueueManager', '🧹 Cleared failed items');
  }

  Future<void> clearAll() async {
    _queue.clear();
    await _saveQueue();
    debugLog('OfflineQueueManager', '🧹 Cleared entire queue');
  }

  Future<void> removeItem(String id) async {
    _queue.removeWhere((item) => item.id == id);
    await _saveQueue();
  }

  Map<String, dynamic> getStats() {
    return {
      'total': _queue.length,
      'pending': pendingCount,
      'failed': failedItems.length,
      'completed':
          _queue.where((item) => item.status == QueueStatus.completed).length,
      'processing':
          _queue.where((item) => item.status == QueueStatus.processing).length,
      'isProcessing': _isProcessing,
    };
  }

  void dispose() {
    _retryTimer?.cancel();
    _persistenceTimer?.cancel();
    _queueStreamController.close();
  }
}
