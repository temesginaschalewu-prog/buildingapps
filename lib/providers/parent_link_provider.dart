import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/models/parent_link_model.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/api_response.dart';
import 'package:http/http.dart' as http;

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

  StreamController<ParentLink?> _parentLinkUpdateController =
      StreamController<ParentLink?>.broadcast();
  StreamController<bool> _linkStatusUpdateController =
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
    // FIXED: Add 2 minute buffer to prevent premature expiration
    final now = _currentServerTime;
    final bufferedExpiry = _tokenExpiresAt!.add(const Duration(minutes: 2));
    if (now.isAfter(bufferedExpiry)) return Duration.zero;
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
    // FIXED: Add 2 minute buffer
    final bufferedExpiry = _tokenExpiresAt!.add(const Duration(minutes: 2));
    return _currentServerTime.isAfter(bufferedExpiry);
  }

  // FIXED: Improved server time sync
  Future<void> _syncServerTime() async {
    try {
      // Check cache first
      final cachedTime = await deviceService
          .getCacheItem<Map<String, dynamic>>('server_time_info');
      if (cachedTime != null) {
        final offset = Duration(milliseconds: cachedTime['offset'] ?? 0);
        final cachedAt = DateTime.parse(cachedTime['cached_at']);

        // Only use cache if less than 1 hour old
        if (DateTime.now().difference(cachedAt).inHours < 1) {
          _serverTimeOffset = offset;
          debugLog('ParentLinkProvider',
              'Using cached server time offset: ${offset.inMinutes} minutes');
          return;
        }
      }

      // Get server time from health endpoint
      final startTime = DateTime.now();
      final response = await apiService.dio.get('/health');
      final endTime = DateTime.now();

      // Try to get timestamp from response
      String? serverTimeStr;
      if (response.headers.map.containsKey('date')) {
        serverTimeStr = response.headers.map['date']!.first;
      } else if (response.data is Map &&
          (response.data as Map).containsKey('timestamp')) {
        serverTimeStr = (response.data as Map)['timestamp'];
      }

      if (serverTimeStr != null) {
        try {
          // Try to parse HTTP date format
          DateTime serverTime;
          try {
            serverTime = HttpDate.parse(serverTimeStr);
          } catch (e) {
            // Try ISO format
            serverTime = DateTime.parse(serverTimeStr);
          }

          final roundTripTime = endTime.difference(startTime);
          final estimatedServerTime = serverTime.add(roundTripTime ~/ 2);

          _serverTimeOffset = estimatedServerTime.difference(DateTime.now());

          // Cache the offset
          await deviceService.saveCacheItem(
              'server_time_info',
              {
                'offset': _serverTimeOffset!.inMilliseconds,
                'cached_at': DateTime.now().toIso8601String(),
              },
              ttl: Duration(hours: 1));

          debugLog('ParentLinkProvider',
              'Server time synced. Offset: ${_serverTimeOffset!.inMinutes} minutes');
        } catch (e) {
          debugLog('ParentLinkProvider', 'Failed to parse server date: $e');
          _serverTimeOffset = null;
        }
      } else {
        debugLog(
            'ParentLinkProvider', 'No date header found, using local time');
        _serverTimeOffset = null;
      }
    } catch (e) {
      debugLog('ParentLinkProvider',
          'Server time sync failed (using local time): $e');
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
    if (_countdownTimer != null) {
      _countdownTimer!.cancel();
      _countdownTimer = null;
    }
  }

  Future<void> generateParentToken() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      // Check cache first
      final cachedToken = await deviceService
          .getCacheItem<Map<String, dynamic>>('parent_token');
      if (cachedToken != null) {
        final expiresAt = DateTime.parse(cachedToken['expires_at']).toLocal();
        if (expiresAt.isAfter(DateTime.now())) {
          _parentToken = cachedToken['token'];
          _tokenExpiresAt = expiresAt;
          _isLinked = false;
          _parentTelegramUsername = null;
          _parentTelegramId = null;
          _linkedAt = null;
          _parentName = null;
          _parentLinkData = null;

          debugLog('ParentLinkProvider', '✅ Loaded parent token from cache');

          _startCountdownTimer();

          _hasLoaded = true;
          _linkStatusUpdateController.add(false);
          _notifySafely();
          return;
        }
      }

      // Sync server time before generating
      await _syncServerTime();

      debugLog('ParentLinkProvider', 'Generating parent token');
      final response = await apiService.generateParentToken();
      final data = response.data!;

      _parentToken = data['token'];
      // FIXED: Parse date properly
      _tokenExpiresAt = DateTime.parse(data['expires_at']).toLocal();
      _isLinked = false;
      _parentTelegramUsername = null;
      _parentTelegramId = null;
      _linkedAt = null;
      _parentName = null;
      _parentLinkData = null;

      await deviceService.saveCacheItem(
          'parent_token',
          {
            'token': _parentToken,
            'expires_at': _tokenExpiresAt!.toIso8601String(),
          },
          ttl: Duration(seconds: 600));

      debugLog('ParentLinkProvider',
          'Generated token expiresAt: ${_tokenExpiresAt?.toIso8601String()}');
      debugLog('ParentLinkProvider',
          'Current server time: ${_currentServerTime.toIso8601String()}');

      _startCountdownTimer();

      _hasLoaded = true;
      _linkStatusUpdateController.add(false);
    } on ApiError catch (e) {
      _error = e.userFriendlyMessage;
      debugLog(
          'ParentLinkProvider', 'generateParentToken API error: ${e.message}');
      rethrow;
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'generateParentToken error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> getParentLinkStatus({bool forceRefresh = false}) async {
    if (!forceRefresh && _hasLoaded) {
      return;
    }

    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    if (forceRefresh) {
      _error = null;
    }
    _notifySafely();

    try {
      // Try cache first
      if (!forceRefresh) {
        final cachedStatus =
            await deviceService.getCacheItem<ParentLink>('parent_link_status');
        if (cachedStatus != null) {
          _updateFromParentLink(cachedStatus);
          _hasLoaded = true;
          _isLoading = false;
          _parentLinkUpdateController.add(_parentLinkData);
          _linkStatusUpdateController.add(_isLinked);
          _notifySafely();
          debugLog(
              'ParentLinkProvider', '✅ Loaded parent link status from cache');
          return;
        }
      }

      // Sync server time before checking
      await _syncServerTime();

      debugLog('ParentLinkProvider', 'Fetching parent link status');
      final response = await apiService.getParentLinkStatus();
      final parentLink = response.data;

      if (parentLink != null) {
        _parentLinkData = parentLink;

        await deviceService.saveCacheItem('parent_link_status', parentLink,
            ttl: const Duration(minutes: 5));

        _updateFromParentLink(parentLink);

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
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'getParentLinkStatus error: $e');
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
    await deviceService.removeCacheItem('parent_link_status');
    await getParentLinkStatus(forceRefresh: true);
  }

  Future<void> unlinkParent() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ParentLinkProvider', 'Unlinking parent');
      await apiService.unlinkParent();

      await deviceService.removeCacheItem('parent_link_status');
      await deviceService.removeCacheItem('parent_token');

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

    await deviceService.removeCacheItem('parent_link_status');
    await deviceService.removeCacheItem('parent_token');
    await deviceService.removeCacheItem('server_time_info');

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

    _parentLinkUpdateController.close();
    _linkStatusUpdateController.close();

    _parentLinkUpdateController = StreamController<ParentLink?>.broadcast();
    _linkStatusUpdateController = StreamController<bool>.broadcast();

    _parentLinkUpdateController.add(null);
    _linkStatusUpdateController.add(false);

    _notifySafely();
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
