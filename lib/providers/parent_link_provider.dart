import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/parent_link_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';

class ParentLinkProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  String? _parentToken;
  DateTime? _tokenExpiresAt;
  bool _isLinked = false;
  bool _hasLoaded = false;
  String? _parentTelegramUsername;
  int? _parentTelegramId;
  DateTime? _linkedAt;
  bool _isLoading = false;
  String? _error;
  Timer? _countdownTimer;
  String? _parentName;
  ParentLink? _parentLinkData;
  Duration? _serverTimeOffset;

  final StreamController<ParentLink?> _parentLinkUpdateController =
      StreamController<ParentLink?>.broadcast();
  final StreamController<bool> _linkStatusUpdateController =
      StreamController<bool>.broadcast();

  ParentLinkProvider({required this.apiService, required this.deviceService});

  String? get parentToken => _parentToken;
  DateTime? get tokenExpiresAt => _tokenExpiresAt;
  bool get isLinked => _isLinked;
  bool get hasLoaded => _hasLoaded;
  String? get parentTelegramUsername => _parentTelegramUsername;
  int? get parentTelegramId => _parentTelegramId;
  DateTime? get linkedAt => _linkedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;
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

  Future<void> clearCache() async {
    debugLog('ParentLinkProvider', ' Clearing cache');
    await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
    await deviceService.removeCacheItem(AppConstants.parentTokenKey);
  }

  Future<void> _syncServerTime() async {
    try {
      final cachedTime = await deviceService
          .getCacheItem<Map<String, dynamic>>(AppConstants.serverTimeInfoKey);
      if (cachedTime != null) {
        final offset = Duration(milliseconds: cachedTime['offset'] ?? 0);
        final cachedAt = DateTime.parse(cachedTime['cached_at']);

        if (DateTime.now().difference(cachedAt).inHours < 1) {
          _serverTimeOffset = offset;
          debugLog('ParentLinkProvider',
              'Using cached server time offset: ${offset.inMinutes} minutes');
          return;
        }
      }

      try {
        final startTime = DateTime.now();
        final response = await apiService.dio.get('/health');
        final endTime = DateTime.now();

        if (response.statusCode == 200) {
          final serverTime = DateTime.now();
          final roundTripTime = endTime.difference(startTime);
          final estimatedServerTime = serverTime.add(roundTripTime ~/ 2);
          _serverTimeOffset = estimatedServerTime.difference(DateTime.now());

          await deviceService.saveCacheItem(
              AppConstants.serverTimeInfoKey,
              {
                'offset': _serverTimeOffset!.inMilliseconds,
                'cached_at': DateTime.now().toIso8601String(),
              },
              ttl: const Duration(hours: 1));

          debugLog('ParentLinkProvider',
              'Server time synced. Offset: ${_serverTimeOffset!.inMinutes} minutes');
        }
      } catch (e) {
        debugLog('ParentLinkProvider', 'Server time sync failed: $e');
        _serverTimeOffset = null;
      }
    } catch (e) {
      debugLog('ParentLinkProvider', 'Server time sync error: $e');
      _serverTimeOffset = null;
    }
  }

  void _startCountdownTimer() {
    _stopCountdownTimer();

    if (_tokenExpiresAt != null && !isTokenExpired) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isTokenExpired) {
          _stopCountdownTimer();
          _parentToken = null;
          _tokenExpiresAt = null;
          _notifySafely();
        } else {
          _notifySafely();
        }
      });
    }
  }

  void _stopCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  Future<void> generateParentToken() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      await deviceService.removeCacheItem(AppConstants.parentTokenKey);
      await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);

      debugLog('ParentLinkProvider', ' Cleared cache, generating new token');

      await _syncServerTime();

      debugLog('ParentLinkProvider', 'Generating parent token');
      final response = await apiService.generateParentToken();

      if (!response.success || response.data == null) {
        throw Exception(response.message);
      }

      final data = response.data!;

      _parentToken = data['token'];
      _tokenExpiresAt = DateTime.parse(data['expires_at']).toLocal();
      _isLinked = false;
      _parentTelegramUsername = null;
      _parentTelegramId = null;
      _linkedAt = null;
      _parentName = null;
      _parentLinkData = null;

      await deviceService.saveCacheItem(
          AppConstants.parentTokenKey,
          {
            'token': _parentToken,
            'expires_at': _tokenExpiresAt!.toIso8601String(),
          },
          ttl: const Duration(minutes: 30));

      debugLog('ParentLinkProvider',
          '✅ Generated new token: $_parentToken, expiresAt: ${_tokenExpiresAt?.toIso8601String()}');

      _startCountdownTimer();

      _hasLoaded = true;
      _linkStatusUpdateController.add(false);
      _notifySafely();
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog(
          'ParentLinkProvider', 'generateParentToken API error: ${e.message}');
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'generateParentToken error: $e');
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> getParentLinkStatus({bool forceRefresh = false}) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    if (forceRefresh) {
      _error = null;
    }
    _notifySafely();

    try {
      if (forceRefresh) {
        await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
      }

      debugLog('ParentLinkProvider',
          'Fetching parent link status (forceRefresh: $forceRefresh)');
      final response = await apiService.getParentLinkStatus();

      if (response.success && response.data != null) {
        _parentLinkData = response.data;

        if (!forceRefresh) {
          await deviceService.saveCacheItem(
              AppConstants.parentLinkStatusKey, _parentLinkData!,
              ttl: const Duration(minutes: 5));
        }

        _updateFromParentLink(_parentLinkData!);

        debugLog(
            'ParentLinkProvider', 'Parent link status: isLinked=$_isLinked');
      } else {
        _parentLinkData = null;
        _isLinked = false;
        _parentTelegramUsername = null;
        _parentTelegramId = null;
        _linkedAt = null;
        _parentName = null;
        _parentToken = null;
        _tokenExpiresAt = null;
      }

      _hasLoaded = true;

      _parentLinkUpdateController.add(_parentLinkData);
      _linkStatusUpdateController.add(_isLinked);
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog(
          'ParentLinkProvider', 'getParentLinkStatus API error: ${e.message}');
      _hasLoaded = true;
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'getParentLinkStatus error: $e');
      _hasLoaded = true;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void _updateFromParentLink(ParentLink parentLink) {
    _stopCountdownTimer();

    _isLinked = parentLink.isLinked;
    _parentTelegramUsername = parentLink.parentTelegramUsername;
    _parentTelegramId = parentLink.parentTelegramId;
    _linkedAt = parentLink.linkedAt;
    _parentName = parentLink.parentName;

    if (!_isLinked) {
      _parentToken = parentLink.token;
      _tokenExpiresAt = parentLink.tokenExpiresAt;

      if (_parentToken != null && _tokenExpiresAt != null) {
        _startCountdownTimer();
      }
    } else {
      _parentToken = null;
      _tokenExpiresAt = null;
    }
  }

  Future<void> refreshParentLinkStatus() async {
    await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
    await getParentLinkStatus(forceRefresh: true);
  }

  Future<void> unlinkParent() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ParentLinkProvider', 'Unlinking parent');
      final response = await apiService.unlinkParent();

      if (response.success) {
        await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
        await deviceService.removeCacheItem(AppConstants.parentTokenKey);

        _stopCountdownTimer();
        _isLinked = false;
        _parentTelegramUsername = null;
        _parentTelegramId = null;
        _linkedAt = null;
        _parentToken = null;
        _tokenExpiresAt = null;
        _parentName = null;
        _parentLinkData = null;
        _hasLoaded = true;

        _parentLinkUpdateController.add(null);
        _linkStatusUpdateController.add(false);

        debugLog('ParentLinkProvider', 'Parent unlinked');
      }
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog('ParentLinkProvider', 'unlinkParent API error: ${e.message}');
      rethrow;
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'unlinkParent error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  void updateLinkStatus({
    required bool isLinked,
    String? parentTelegramUsername,
    int? parentTelegramId,
    String? parentName,
    DateTime? linkedAt,
  }) {
    _stopCountdownTimer();
    _isLinked = isLinked;
    _parentTelegramUsername = parentTelegramUsername;
    _parentTelegramId = parentTelegramId;
    _parentName = parentName;
    _linkedAt = linkedAt ?? DateTime.now();

    if (isLinked) {
      _parentToken = null;
      _tokenExpiresAt = null;
    }

    _hasLoaded = true;

    _parentLinkUpdateController.add(_parentLinkData);
    _linkStatusUpdateController.add(_isLinked);

    _notifySafely();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('ParentLinkProvider', 'Clearing parent link data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog(
          'ParentLinkProvider', '✅ Same user - preserving parent link cache');
      return;
    }

    await deviceService.removeCacheItem(AppConstants.parentLinkStatusKey);
    await deviceService.removeCacheItem(AppConstants.parentTokenKey);
    await deviceService.removeCacheItem(AppConstants.serverTimeInfoKey);

    _stopCountdownTimer();

    _parentLinkData = null;
    _hasLoaded = false;
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

    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  @override
  void dispose() {
    _stopCountdownTimer();
    _parentLinkUpdateController.close();
    _linkStatusUpdateController.close();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}
