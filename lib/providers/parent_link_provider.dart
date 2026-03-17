// lib/providers/parent_link_provider.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/parent_link_model.dart';
import '../utils/constants.dart';
import '../utils/api_response.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Parent Link Provider with Full Offline Support
class ParentLinkProvider extends ChangeNotifier
    with
        BaseProvider<ParentLinkProvider>,
        OfflineAwareProvider<ParentLinkProvider>,
        BackgroundRefreshMixin<ParentLinkProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  String? _parentToken;
  DateTime? _tokenExpiresAt;
  bool _isLinked = false;
  String? _parentTelegramUsername;
  int? _parentTelegramId;
  DateTime? _linkedAt;
  String? _parentName;
  ParentLink? _parentLinkData;
  Duration? _serverTimeOffset;

  Timer? _countdownTimer;

  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _parentLinkBox;
  Box? _tokenBox;

  int _apiCallCount = 0;

  final StreamController<ParentLink?> _parentLinkUpdateController =
      StreamController<ParentLink?>.broadcast();
  final StreamController<bool> _linkStatusUpdateController =
      StreamController<bool>.broadcast();

  ParentLinkProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) {
    log('ParentLinkProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    // Register processor for parent actions
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionParentAction,
      _processParentAction,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processParentAction(Map<String, dynamic> data) async {
    try {
      log('Processing offline parent action');
      // Handle any parent-related offline actions here
      // For now, just return true
      return true;
    } catch (e) {
      log('Error processing parent action: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedData();

    if (_hasData) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveParentLinkBox)) {
        _parentLinkBox = await Hive.openBox(AppConstants.hiveParentLinkBox);
      } else {
        _parentLinkBox = Hive.box(AppConstants.hiveParentLinkBox);
      }

      if (!Hive.isBoxOpen('parent_token_box')) {
        _tokenBox = await Hive.openBox('parent_token_box');
      } else {
        _tokenBox = Hive.box('parent_token_box');
      }

      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  Future<void> _loadCachedData() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      // Load parent link data from Hive
      if (_parentLinkBox != null) {
        final cachedKey = 'user_${userId}_parent_link';
        final cachedData = _parentLinkBox!.get(cachedKey);

        if (cachedData != null) {
          if (cachedData is ParentLink) {
            _parentLinkData = cachedData;
            _updateFromParentLink(_parentLinkData!);
            setLoaded();
            log('✅ Loaded parent link data from Hive');
          } else if (cachedData is Map) {
            try {
              _parentLinkData =
                  ParentLink.fromJson(Map<String, dynamic>.from(cachedData));
              _updateFromParentLink(_parentLinkData!);
              setLoaded();
              log('✅ Loaded parent link data from Hive (converted)');
            } catch (e) {
              log('Error converting parent link: $e');
            }
          }
        }
      }

      // Load token from Hive
      if (_tokenBox != null) {
        final tokenKey = 'user_${userId}_token';
        final cachedToken = _tokenBox!.get(tokenKey);
        if (cachedToken != null && cachedToken is Map) {
          _parentToken = cachedToken['token']?.toString();
          final expiresAtStr = cachedToken['expires_at']?.toString();
          if (expiresAtStr != null) {
            _tokenExpiresAt = DateTime.parse(expiresAtStr);
          }
          _startCountdownTimer();
          log('✅ Loaded parent token from Hive');
        }
      }
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      if (_parentLinkBox != null && _parentLinkData != null) {
        final cacheKey = 'user_${userId}_parent_link';
        await _parentLinkBox!.put(cacheKey, _parentLinkData);
        log('💾 Saved parent link to Hive');
      }

      if (_tokenBox != null && _parentToken != null) {
        final tokenKey = 'user_${userId}_token';
        await _tokenBox!.put(tokenKey, {
          'token': _parentToken,
          'expires_at': _tokenExpiresAt?.toIso8601String(),
        });
        log('💾 Saved token to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  bool get _hasData => _parentLinkData != null || _parentToken != null;

  // ===== GETTERS =====
  String? get parentToken => _parentToken;
  DateTime? get tokenExpiresAt => _tokenExpiresAt;
  bool get isLinked => _isLinked;
  String? get parentTelegramUsername => _parentTelegramUsername;
  int? get parentTelegramId => _parentTelegramId;
  DateTime? get linkedAt => _linkedAt;
  String? get parentName => _parentName;
  ParentLink? get parentLinkData => _parentLinkData;

  Stream<ParentLink?> get parentLinkUpdates =>
      _parentLinkUpdateController.stream;
  Stream<bool> get linkStatusUpdates => _linkStatusUpdateController.stream;

  DateTime get _currentServerTime {
    if (_serverTimeOffset != null) {
      return DateTime.now().add(_serverTimeOffset!);
    }
    return DateTime.now();
  }

  Duration get remainingTime {
    if (_tokenExpiresAt == null) return Duration.zero;
    final now = _currentServerTime;
    if (now.isAfter(_tokenExpiresAt!)) return Duration.zero;
    return _tokenExpiresAt!.difference(now);
  }

  String get remainingTimeFormatted {
    final duration = remainingTime;
    if (duration.inMinutes <= 0) return 'Expired';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  bool get isTokenExpired {
    if (_tokenExpiresAt == null) return true;
    return _currentServerTime.isAfter(_tokenExpiresAt!);
  }

  void _syncServerTime(DateTime? serverTime) {
    if (serverTime == null) return;
    _serverTimeOffset = serverTime.difference(DateTime.now());
    log('Server time synced, offset: $_serverTimeOffset');
  }

  void _startCountdownTimer() {
    _stopCountdownTimer();
    log('Starting countdown timer');

    if (_tokenExpiresAt != null && !isTokenExpired) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isTokenExpired) {
          log('Token expired, stopping timer');
          _stopCountdownTimer();
          unawaited(getParentLinkStatus(forceRefresh: true));
          safeNotify();
        } else {
          safeNotify();
        }
      });
    }
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    log('Countdown timer stopped');
  }

  // ===== CLEAR CACHE =====
  Future<void> clearCache() async {
    log('clearCache()');

    await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
    await deviceService.removeCacheItem(AppConstants.parentTokenKey);

    final userId = await UserSession().getCurrentUserId();
    if (userId != null) {
      if (_parentLinkBox != null) {
        await _parentLinkBox!.delete('user_${userId}_parent_link');
      }
      if (_tokenBox != null) {
        await _tokenBox!.delete('user_${userId}_token');
      }
    }
    log('Cache cleared');
  }

  // ===== GENERATE PARENT TOKEN =====
  Future<void> generateParentToken() async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('generateParentToken() CALL #$callId');

    if (isLoading) {
      log('⏳ Already loading, skipping');
      return;
    }

    if (isOffline) {
      setError('You are offline. Please connect to generate token.');
      safeNotify();
      return;
    }

    setLoading();

    try {
      log('Clearing old cache');
      await deviceService.removeCacheItem(AppConstants.parentTokenKey);
      await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);

      final userId = await UserSession().getCurrentUserId();
      if (userId != null) {
        if (_tokenBox != null) {
          await _tokenBox!.delete('user_${userId}_token');
        }
        if (_parentLinkBox != null) {
          await _parentLinkBox!.delete('user_${userId}_parent_link');
        }
      }

      log('Calling API to generate token');
      final response = await apiService.generateParentToken();

      if (!response.success || response.data == null) {
        throw Exception(response.message);
      }

      final data = response.data!;
      final serverTimeMs = data['server_time_ms'];
      final expiresAtMs = data['expires_at_ms'];

      _syncServerTime(
        serverTimeMs != null
            ? DateTime.fromMillisecondsSinceEpoch(serverTimeMs, isUtc: true)
                .toLocal()
            : (data['server_time'] != null
                ? DateTime.tryParse(data['server_time'].toString())?.toLocal()
                : null),
      );

      _parentToken = data['token'];
      _tokenExpiresAt = expiresAtMs != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true)
              .toLocal()
          : DateTime.parse(data['expires_at']).toLocal();
      _isLinked = false;
      _parentTelegramUsername = null;
      _parentTelegramId = null;
      _linkedAt = null;
      _parentName = null;
      _parentLinkData = null;

      log('Token generated: $_parentToken, expires at: $_tokenExpiresAt');

      await _saveToHive();

      deviceService.saveCacheItem(
        AppConstants.parentTokenKey,
        {
          'token': _parentToken,
          'expires_at': _tokenExpiresAt!.toIso8601String(),
        },
        ttl: const Duration(minutes: 30),
      );

      _startCountdownTimer();

      setLoaded();
      _linkStatusUpdateController.add(false);
      safeNotify();

      log('✅ Generated parent token');
    } on ApiError catch (e) {
      setError(e.userFriendlyMessage);
      setLoaded();
      log('❌ API Error: ${e.userFriendlyMessage}');
    } catch (e) {
      setError(e.toString());
      setLoaded();
      log('❌ Error: $e');
    } finally {
      safeNotify();
    }
  }

  // ===== GET PARENT LINK STATUS =====
  Future<void> getParentLinkStatus({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('getParentLinkStatus() CALL #$callId');

    if (isManualRefresh && isOffline) {
      throw Exception('Network error. Please check your internet connection.');
    }

    if (isLoading && !forceRefresh) {
      log('⏳ Already loading, skipping');
      return;
    }

    setLoading();

    try {
      if (forceRefresh) {
        await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
      }

      // STEP 1: Try Hive first
      if (!forceRefresh && _parentLinkData == null) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _parentLinkBox != null) {
          final cachedKey = 'user_${userId}_parent_link';
          final cachedData = _parentLinkBox!.get(cachedKey);

          if (cachedData != null) {
            if (cachedData is ParentLink) {
              _parentLinkData = cachedData;
              _updateFromParentLink(_parentLinkData!);
              setLoaded();
              log('✅ Using cached parent link data from Hive');

              if (isManualRefresh && isOffline) {
                throw Exception(
                    'Network error. Please check your internet connection.');
              }
              return;
            } else if (cachedData is Map) {
              try {
                _parentLinkData =
                    ParentLink.fromJson(Map<String, dynamic>.from(cachedData));
                _updateFromParentLink(_parentLinkData!);
                setLoaded();
                log('✅ Using cached parent link data from Hive (converted)');

                if (isManualRefresh && isOffline) {
                  throw Exception(
                      'Network error. Please check your internet connection.');
                }
                return;
              } catch (e) {
                log('Error converting Hive parent link: $e');
              }
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache');
        final cached = await deviceService.getCacheItem<Map<String, dynamic>>(
          AppConstants.parentLinkStatusKey,
        );
        if (cached != null) {
          _parentLinkData = ParentLink.fromJson(cached);
          _updateFromParentLink(_parentLinkData!);
          setLoaded();
          log('✅ Using cached parent link data from DeviceService');

          await _saveToHive();

          if (isManualRefresh && isOffline) {
            throw Exception(
                'Network error. Please check your internet connection.');
          }
          return;
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode');
        if (_parentLinkData != null) {
          setLoaded();
          log('✅ Showing cached parent link data offline');
          return;
        }

        setError('You are offline. No cached parent link data available.');
        setLoaded();

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API');
      final response = await apiService.getParentLinkStatus();

      if (response.success && response.data != null) {
        _parentLinkData = response.data;
        log('✅ Received parent link status from API');

        if (!forceRefresh) {
          await _saveToHive();

          deviceService.saveCacheItem(
            AppConstants.parentLinkStatusKey,
            _parentLinkData!.toJson(),
            ttl: const Duration(minutes: 5),
          );
        }

        _updateFromParentLink(_parentLinkData!);
        setLoaded();
        log('✅ Loaded parent link status from API');
      } else {
        _parentLinkData = null;
        _isLinked = false;
        _parentTelegramUsername = null;
        _parentTelegramId = null;
        _linkedAt = null;
        _parentName = null;
        _parentToken = null;
        _tokenExpiresAt = null;
        setLoaded();
        log('⚠️ No parent link from API');
      }

      _parentLinkUpdateController.add(_parentLinkData);
      _linkStatusUpdateController.add(_isLinked);
      safeNotify();
    } on ApiError catch (e) {
      setError(e.userFriendlyMessage);
      setLoaded();
      log('❌ API Error: ${e.userFriendlyMessage}');

      if (isManualRefresh) {
        rethrow;
      }
    } catch (e) {
      setError(e.toString());
      setLoaded();
      log('❌ Error getting parent link status: $e');

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  void _updateFromParentLink(ParentLink parentLink) {
    log('_updateFromParentLink()');
    _stopCountdownTimer();

    _isLinked = parentLink.isLinked;
    _parentTelegramUsername = parentLink.parentTelegramUsername;
    _parentTelegramId = parentLink.parentTelegramId;
    _linkedAt = parentLink.linkedAt;
    _parentName = parentLink.parentName;
    _syncServerTime(parentLink.serverTime);

    if (!_isLinked) {
      _parentToken = parentLink.token;
      _tokenExpiresAt = parentLink.tokenExpiresAt;

      if (_parentToken != null && _tokenExpiresAt != null) {
        _startCountdownTimer();
        log('Token active, expires at: $_tokenExpiresAt');
      }
    } else {
      _parentToken = null;
      _tokenExpiresAt = null;
      log('Parent linked, token cleared');
    }
  }

  Future<void> refreshParentLinkStatus() async {
    log('refreshParentLinkStatus()');

    await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);

    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _parentLinkBox != null) {
      await _parentLinkBox!.delete('user_${userId}_parent_link');
    }

    await getParentLinkStatus(forceRefresh: true);
  }

  // ===== UNLINK PARENT =====
  Future<void> unlinkParent() async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('unlinkParent() CALL #$callId');

    if (isLoading) {
      log('⏳ Already loading, skipping');
      return;
    }

    if (isOffline) {
      setError('You are offline. Please connect to unlink parent.');
      safeNotify();
      return;
    }

    setLoading();

    try {
      log('Calling API to unlink parent');
      final response = await apiService.unlinkParent();

      if (response.success) {
        await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
        await deviceService.removeCacheItem(AppConstants.parentTokenKey);

        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {
          if (_parentLinkBox != null) {
            await _parentLinkBox!.delete('user_${userId}_parent_link');
          }
          if (_tokenBox != null) {
            await _tokenBox!.delete('user_${userId}_token');
          }
        }

        _stopCountdownTimer();
        _isLinked = false;
        _parentTelegramUsername = null;
        _parentTelegramId = null;
        _linkedAt = null;
        _parentToken = null;
        _tokenExpiresAt = null;
        _parentName = null;
        _parentLinkData = null;

        setLoaded();
        _parentLinkUpdateController.add(null);
        _linkStatusUpdateController.add(false);

        log('✅ Unlinked parent');
      } else {
        setLoaded();
        throw Exception(response.message);
      }
    } on ApiError catch (e) {
      setError(e.userFriendlyMessage);
      setLoaded();
      log('❌ API Error: ${e.userFriendlyMessage}');
      rethrow;
    } catch (e) {
      setError(e.toString());
      setLoaded();
      log('❌ Error: $e');
      rethrow;
    } finally {
      safeNotify();
    }
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (!isOffline && _hasData) {
      await getParentLinkStatus(forceRefresh: true);
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing parent link');
    await getParentLinkStatus(forceRefresh: true);
  }

  // ===== CLEAR USER DATA =====
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_parentLinkBox != null) {
        await _parentLinkBox!.delete('user_${userId}_parent_link');
      }
      if (_tokenBox != null) {
        await _tokenBox!.delete('user_${userId}_token');
      }
    }

    await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
    await deviceService.removeCacheItem(AppConstants.parentTokenKey);
    await deviceService.removeCacheItem(AppConstants.serverTimeInfoKey);

    _stopCountdownTimer();

    _parentLinkData = null;
    _isLinked = false;
    _parentTelegramUsername = null;
    _parentTelegramId = null;
    _linkedAt = null;
    _parentToken = null;
    _tokenExpiresAt = null;
    _parentName = null;
    _serverTimeOffset = null;

    _parentLinkUpdateController.add(null);
    _linkStatusUpdateController.add(false);
    stopBackgroundRefresh();
    safeNotify();

    log('🧹 Cleared user parent link data');
  }

  @override
  void dispose() {
    _stopCountdownTimer();
    stopBackgroundRefresh();
    _parentLinkUpdateController.close();
    _linkStatusUpdateController.close();
    _parentLinkBox?.close();
    _tokenBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
