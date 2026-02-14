import 'dart:async';
import 'package:flutter/material.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:familyacademyclient/models/parent_link_model.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/api_response.dart';

class ParentLinkProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  String? _parentToken;
  DateTime? _tokenExpiresAt;
  bool _isLinked = false;
  bool _hasLoaded = false;
  String? _parentTelegramUsername;
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

  Future<void> _syncServerTime() async {
    try {
      final cachedTime =
          await deviceService.getCacheItem<Duration>('server_time_offset');
      if (cachedTime != null) {
        _serverTimeOffset = cachedTime;
        return;
      }

      final startTime = DateTime.now();
      final response = await apiService.dio.head('/');
      final endTime = DateTime.now();

      if (response.headers.map.containsKey('date')) {
        final serverDateStr = response.headers.map['date']!.first;
        final serverTime = DateTime.parse(serverDateStr);
        final roundTripTime = endTime.difference(startTime);
        final estimatedServerTime = serverTime.add(roundTripTime ~/ 2);

        _serverTimeOffset = estimatedServerTime.difference(DateTime.now());

        if (_serverTimeOffset != null) {
          await deviceService.saveCacheItem(
              'server_time_offset', _serverTimeOffset,
              ttl: Duration(hours: 1));
        }

        debugLog('ParentLinkProvider',
            'Server time synced. Offset: $_serverTimeOffset');
      }
    } catch (e) {
      debugLog('ParentLinkProvider', 'Server time sync failed: $e');
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
      final cachedToken = await deviceService
          .getCacheItem<Map<String, dynamic>>('parent_token');
      if (cachedToken != null &&
          DateTime.parse(cachedToken['expires_at']).isAfter(DateTime.now())) {
        _parentToken = cachedToken['token'];
        _tokenExpiresAt = DateTime.parse(cachedToken['expires_at']);
        _isLinked = false;
        _parentTelegramUsername = null;
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

      await _syncServerTime();

      debugLog('ParentLinkProvider', 'Generating parent token');
      final response = await apiService.generateParentToken();
      final data = response.data!;

      _parentToken = data['token'];
      _tokenExpiresAt = DateTime.parse(data['expires_at']);
      _isLinked = false;
      _parentTelegramUsername = null;
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

      debugLog(
          'ParentLinkProvider', 'Generated token expiresAt: $_tokenExpiresAt');
      debugLog(
          'ParentLinkProvider', 'Current server time: $_currentServerTime');

      _startCountdownTimer();

      _hasLoaded = true;
      _linkStatusUpdateController.add(false);
    } on ApiError catch (e) {
      _error = e.message;
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

      await _syncServerTime();

      debugLog('ParentLinkProvider', 'Fetching parent link status');
      final response = await apiService.getParentLinkStatus();
      final parentLink = response.data;

      if (parentLink != null) {
        _parentLinkData = parentLink;

        await deviceService.saveCacheItem('parent_link_status', parentLink,
            ttl: Duration(minutes: 5));

        _updateFromParentLink(parentLink);

        debugLog(
            'ParentLinkProvider', 'Parent link status: isLinked=$_isLinked');
      } else {
        _parentLinkData = null;
        _isLinked = false;
        _parentTelegramUsername = null;
        _linkedAt = null;
        _parentName = null;
        _parentToken = null;
        _tokenExpiresAt = null;
      }

      _hasLoaded = true;

      _parentLinkUpdateController.add(_parentLinkData);
      _linkStatusUpdateController.add(_isLinked);
    } on ApiError catch (e) {
      _error = e.message;
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
      _error = e.message;
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
    String? parentName,
    DateTime? linkedAt,
  }) {
    _stopCountdownTimer();
    _isLinked = isLinked;
    _parentTelegramUsername = parentTelegramUsername;
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
    await deviceService.removeCacheItem('server_time_offset');

    _stopCountdownTimer();

    _parentLinkData = null;
    _hasLoaded = false;
    _isLinked = false;
    _parentTelegramUsername = null;
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
