// lib/providers/streak_provider.dart
// PRODUCTION-READY FINAL VERSION - WITH ALL FIXES

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/streak_model.dart';
import '../utils/constants.dart';
import '../utils/ui_helpers.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Streak Provider with Full Offline Support
class StreakProvider extends ChangeNotifier
    with
        BaseProvider<StreakProvider>,
        OfflineAwareProvider<StreakProvider>,
        BackgroundRefreshMixin<StreakProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  Streak? _streak;
  List<DateTime> _streakHistory = [];
  String? _currentUserId;

  static const Duration _cacheDuration = AppConstants.cacheTTLStreak;
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _streakBox;

  int _apiCallCount = 0;

  // ✅ FIXED: Rate limiting
  DateTime? _lastBackgroundRefresh;
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  StreakProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) {
    log('StreakProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    // Register processor for streak updates
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionUpdateStreak,
      _processStreakUpdate,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processStreakUpdate(Map<String, dynamic> data) async {
    try {
      log('Processing offline streak update');
      final response = await apiService.updateStreak();
      return response.success;
    } catch (e) {
      log('Error processing streak update: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _getCurrentUserId();
    await loadStreak();

    if (_streak != null) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveStreakBox)) {
        _streakBox = await Hive.openBox(AppConstants.hiveStreakBox);
      } else {
        _streakBox = Hive.box(AppConstants.hiveStreakBox);
      }
      log('✅ Hive box opened');
    } catch (e) {
      log('⚠️ Error opening Hive box: $e');
    }
  }

  Future<void> _getCurrentUserId() async {
    final session = UserSession();
    _currentUserId = await session.getCurrentUserId();
    log('Current user ID: $_currentUserId');
  }

  // ===== GETTERS =====
  Streak? get streak => _streak;

  List<DateTime> get streakHistory => _streakHistory;

  int get currentStreak => _streak?.currentStreak ?? 0;

  String get streakLevel => UiHelpers.getStreakLevel(currentStreak);
  Color get streakColor => UiHelpers.getStreakColor(currentStreak);
  String get motivationalMessage => UiHelpers.getStreakMessage(currentStreak);

  bool get hasStreakToday {
    final today = DateTime.now();
    return _streakHistory.any(
      (date) =>
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day,
    );
  }

  bool hasStreakOnDate(DateTime date) {
    return _streakHistory.any(
      (streakDate) =>
          streakDate.year == date.year &&
          streakDate.month == date.month &&
          streakDate.day == date.day,
    );
  }

  int getWeeklyStreak() {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _streakHistory.where((date) => date.isAfter(weekAgo)).length;
  }

  List<bool> getLast7DaysStreak() {
    final days = List<bool>.filled(7, false);
    final now = DateTime.now();

    for (final date in _streakHistory) {
      final diff = now.difference(date).inDays;
      if (diff < 7) days[6 - diff] = true;
    }
    return days;
  }

  // ===== LOAD STREAK =====
  Future<void> loadStreak({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadStreak() CALL #$callId');

    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, skipping');
      return;
    }

    setLoading();

    try {
      // STEP 1: Try Hive first (fastest)
      if (!forceRefresh && _currentUserId != null && _streakBox != null) {
        log('STEP 1: Checking Hive cache');
        final cachedStreak = _streakBox!.get('user_${_currentUserId}_streak');

        if (cachedStreak != null) {
          if (cachedStreak is Streak) {
            _streak = cachedStreak;
            _streakHistory = _streak?.history ?? [];
            setLoaded();
            log('✅ Loaded streak from Hive: currentStreak=${_streak?.currentStreak}');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground());
            }
            return;
          } else if (cachedStreak is Map) {
            try {
              _streak =
                  Streak.fromJson(Map<String, dynamic>.from(cachedStreak));
              _streakHistory = _streak?.history ?? [];
              setLoaded();
              log('✅ Loaded streak from Hive (converted): currentStreak=${_streak?.currentStreak}');

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshInBackground());
              }
              return;
            } catch (e) {
              log('Error converting Hive streak: $e');
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh && _currentUserId != null) {
        log('STEP 2: Checking DeviceService cache');
        final cachedStreak =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          AppConstants.streakKey(_currentUserId!),
          isUserSpecific: true,
        );
        if (cachedStreak != null) {
          _streak = Streak.fromJson(cachedStreak);
          _streakHistory = _streak?.history ?? [];
          setLoaded();
          log('✅ Loaded streak from DeviceService: currentStreak=${_streak?.currentStreak}');

          if (_streakBox != null && _currentUserId != null) {
            await _streakBox!.put('user_${_currentUserId}_streak', _streak);
          }

          if (!isOffline && !isManualRefresh) {
            unawaited(_refreshInBackground());
          }
          return;
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_streak != null) {
          setLoaded();
          log('✅ Showing cached streak offline');
          return;
        }

        setError(getUserFriendlyErrorMessage(
            'You are offline. No cached streak available.'));
        setLoaded();

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API');
      final response = await apiService.getMyStreak();

      if (response.success && response.data != null) {
        _streak = Streak.fromJson(response.data!);
        _streakHistory = _streak?.history ?? [];
        setLoaded();
        log('✅ Received streak from API: currentStreak=${_streak?.currentStreak}');

        if (_currentUserId != null) {
          if (_streakBox != null) {
            await _streakBox!.put('user_${_currentUserId}_streak', _streak);
          }

          deviceService.saveCacheItem(
            AppConstants.streakKey(_currentUserId!),
            response.data!,
            ttl: _cacheDuration,
            isUserSpecific: true,
          );
        }
        log('✅ Success! Streak loaded');
      } else {
        setError(getUserFriendlyErrorMessage(response.message));
        setLoaded();
        log('❌ API error: ${response.message}');

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading streak: $e');

      setError(getUserFriendlyErrorMessage(e));
      setLoaded();

      if (_streak == null && _currentUserId != null) {
        log('Attempting cache recovery');
        await _recoverFromCache();
      }

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  // ✅ FIXED: Rate limited background refresh
  Future<void> _refreshInBackground() async {
    if (isOffline) return;

    // Rate limiting
    if (_lastBackgroundRefresh != null &&
        DateTime.now().difference(_lastBackgroundRefresh!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited');
      return;
    }
    _lastBackgroundRefresh = DateTime.now();

    try {
      final response = await apiService.getMyStreak();
      if (response.success && response.data != null) {
        _streak = Streak.fromJson(response.data!);
        _streakHistory = _streak?.history ?? [];
        log('Background refresh got streak: ${_streak?.currentStreak}');

        if (_currentUserId != null) {
          if (_streakBox != null) {
            await _streakBox!.put('user_${_currentUserId}_streak', _streak);
          }

          deviceService.saveCacheItem(
            AppConstants.streakKey(_currentUserId!),
            response.data!,
            ttl: _cacheDuration,
            isUserSpecific: true,
          );
        }

        safeNotify();
        log('🔄 Background refresh complete');
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  Future<void> _recoverFromCache() async {
    log('Attempting cache recovery');
    if (_currentUserId != null && _streakBox != null) {
      try {
        final cachedStreak = _streakBox!.get('user_${_currentUserId}_streak');
        if (cachedStreak != null) {
          if (cachedStreak is Streak) {
            _streak = cachedStreak;
          } else if (cachedStreak is Map) {
            _streak = Streak.fromJson(Map<String, dynamic>.from(cachedStreak));
          }
          if (_streak != null) {
            _streakHistory = _streak?.history ?? [];
            log('✅ Recovered streak from Hive after error');
            return;
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    if (_currentUserId != null) {
      try {
        final cachedStreak =
            await deviceService.getCacheItem<Map<String, dynamic>>(
          AppConstants.streakKey(_currentUserId!),
          isUserSpecific: true,
        );
        if (cachedStreak != null) {
          _streak = Streak.fromJson(cachedStreak);
          _streakHistory = _streak?.history ?? [];
          log('✅ Recovered streak from DeviceService after error');
        }
      } catch (e) {
        log('Error recovering from DeviceService: $e');
      }
    }
  }

  // ===== UPDATE STREAK =====
  Future<void> updateStreak() async {
    log('updateStreak()');

    if (isLoading) return;

    setLoading();

    try {
      if (isOffline) {
        log('📝 Offline - queuing streak update');
        await _queueStreakUpdateOffline();
        setLoaded();
        return;
      }

      await apiService.updateStreak();
      await loadStreak(forceRefresh: true);
      log('✅ Streak updated successfully');
    } catch (e) {
      setError(getUserFriendlyErrorMessage(e));
      log('❌ Error updating streak: $e');
    } finally {
      setLoaded();
      safeNotify();
    }
  }

  Future<void> _queueStreakUpdateOffline() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionUpdateStreak,
        data: {
          'timestamp': DateTime.now().toIso8601String(),
          'userId': userId,
        },
      );

      log('📝 Queued streak update for offline sync');
    } catch (e) {
      log('Error queueing streak update: $e');
    }
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (!isOffline && _streak != null) {
      await _refreshInBackground();
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing streak');
    await loadStreak(forceRefresh: true);
  }

  // ✅ FIXED: Clear user data with proper cleanup
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_streakBox != null) {
        await _streakBox!.delete('user_${userId}_streak');
      }

      await deviceService.removeCacheItem(
        AppConstants.streakKey(userId),
        isUserSpecific: true,
      );
    }

    stopBackgroundRefresh();
    _lastBackgroundRefresh = null;
    _streak = null;
    _streakHistory = [];
    safeNotify();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _streakBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
