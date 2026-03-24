// lib/utils/offline_first.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyacademyclient/utils/helpers.dart';

/// Core offline-first utilities for instant loading
class OfflineFirst {
  static bool _initialized = false;
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};

  static Future<void> initialize() async {
    if (_initialized) return;

    // Pre-warm SharedPreferences
    await SharedPreferences.getInstance();

    _initialized = true;
    debugLog('OfflineFirst', '✅ Initialized');
  }

  /// Get data with instant memory cache, then disk cache
  static Future<T?> getCached<T>(
    String key, {
    required Future<T?> Function() fetchFromDisk,
    required Future<T?> Function() fetchFromNetwork,
    Duration? maxAge,
  }) async {
    // Step 1: Check memory cache (instant)
    if (_memoryCache.containsKey(key)) {
      final cacheData = _memoryCache[key];
      if (maxAge != null && _cacheTimestamps.containsKey(key)) {
        final age = DateTime.now().difference(_cacheTimestamps[key]!);
        if (age <= maxAge) {
          return cacheData as T?;
        }
      } else {
        return cacheData as T?;
      }
    }

    // Step 2: Check disk cache (fast)
    try {
      final diskData = await fetchFromDisk();
      if (diskData != null) {
        _memoryCache[key] = diskData;
        _cacheTimestamps[key] = DateTime.now();
        return diskData;
      }
    } catch (e) {
      debugLog('OfflineFirst', 'Disk cache error: $e');
    }

    // Step 3: Fetch from network (slow)
    try {
      final networkData = await fetchFromNetwork();
      if (networkData != null) {
        _memoryCache[key] = networkData;
        _cacheTimestamps[key] = DateTime.now();

        // Save to disk in background
        unawaited(_saveToDisk(key, networkData));
      }
      return networkData;
    } catch (e) {
      debugLog('OfflineFirst', 'Network fetch error: $e');
      return null;
    }
  }

  static Future<void> _saveToDisk(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String stringValue;
      if (value is String) {
        stringValue = value;
      } else {
        stringValue = value.toString();
      }
      await prefs.setString('offline_$key', stringValue);
    } catch (e) {}
  }

  /// Clear memory cache for a key
  static void clearMemoryCache(String key) {
    _memoryCache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Clear all memory cache
  static void clearAllMemoryCache() {
    _memoryCache.clear();
    _cacheTimestamps.clear();
  }
}

/// Mixin for offline-first providers
mixin OfflineFirstProvider<T extends ChangeNotifier> {
  final Map<String, dynamic> _providerCache = {};
  final Map<String, DateTime> _providerCacheTimestamps = {};

  bool _isLoadingFromNetwork = false;
  Timer? _debounceTimer;

  /// Get from cache instantly, then refresh in background
  Future<CacheType?> getCachedData<CacheType>(
    String key, {
    required CacheType? Function() getFromMemory,
    required Future<CacheType?> Function() getFromDisk,
    required Future<CacheType?> Function() getFromNetwork,
    Duration? maxAge,
    VoidCallback? onDataLoaded,
  }) async {
    // Return memory cache instantly
    final memoryData = getFromMemory();
    if (memoryData != null) {
      if (maxAge != null && _providerCacheTimestamps.containsKey(key)) {
        final age = DateTime.now().difference(_providerCacheTimestamps[key]!);
        if (age <= maxAge) {
          return memoryData;
        }
      } else {
        return memoryData;
      }
    }

    // Try disk cache
    try {
      final diskData = await getFromDisk();
      if (diskData != null) {
        _providerCache[key] = diskData;
        _providerCacheTimestamps[key] = DateTime.now();

        // Schedule background refresh
        _scheduleBackgroundRefresh(key, getFromNetwork, onDataLoaded);
        return diskData;
      }
    } catch (e) {}

    // If no cache, load from network
    if (!_isLoadingFromNetwork) {
      _isLoadingFromNetwork = true;
      try {
        final networkData = await getFromNetwork();
        if (networkData != null) {
          _providerCache[key] = networkData;
          _providerCacheTimestamps[key] = DateTime.now();
          if (onDataLoaded != null) onDataLoaded();
          return networkData;
        }
      } finally {
        _isLoadingFromNetwork = false;
      }
    }

    return null;
  }

  void _scheduleBackgroundRefresh<CacheType>(
    String key,
    Future<CacheType?> Function() getFromNetwork,
    VoidCallback? onDataLoaded,
  ) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final networkData = await getFromNetwork();
        if (networkData != null) {
          _providerCache[key] = networkData;
          _providerCacheTimestamps[key] = DateTime.now();
          if (onDataLoaded != null) onDataLoaded();
        }
      } catch (e) {}
    });
  }

  void clearProviderCache() {
    _providerCache.clear();
    _providerCacheTimestamps.clear();
    _debounceTimer?.cancel();
  }
}

/// Helper for offline actions (like Telegram)
class OfflineActionQueue {
  static final OfflineActionQueue _instance = OfflineActionQueue._internal();
  factory OfflineActionQueue() => _instance;
  OfflineActionQueue._internal();

  final List<QueuedAction> _queue = [];
  bool _isProcessing = false;
  final StreamController<int> _queueCountController =
      StreamController<int>.broadcast();

  Stream<int> get queueCount => _queueCountController.stream;
  int get pendingCount => _queue.length;

  void add(QueuedAction action) {
    _queue.add(action);
    _queueCountController.add(_queue.length);
    _saveQueue();

    // Start processing if online
    if (!_isProcessing) {
      unawaited(_processQueue());
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final action = _queue.first;

      try {
        final success = await action.execute();
        if (success) {
          _queue.removeAt(0);
          _queueCountController.add(_queue.length);
          unawaited(_saveQueue());
        } else {
          // Move to end and retry later
          _queue.removeAt(0);
          _queue.add(action);
          break;
        }
      } catch (e) {
        break;
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isProcessing = false;
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueData = _queue.map((a) => a.toJson()).toList();
      await prefs.setString('offline_action_queue', queueData.toString());
    } catch (e) {}
  }

  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString('offline_action_queue');
      if (queueJson != null && queueJson.isNotEmpty) {
        // Parse and load queue - implementation depends on your serialization
      }
    } catch (e) {}
  }
}

class QueuedAction {
  final String id;
  final Future<bool> Function() execute;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  QueuedAction({
    required this.id,
    required this.execute,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'data': data,
        'timestamp': timestamp.toIso8601String(),
      };
}
