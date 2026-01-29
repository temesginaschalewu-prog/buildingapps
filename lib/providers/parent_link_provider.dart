import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/parent_link_model.dart';
import '../utils/helpers.dart';

class ParentLinkProvider with ChangeNotifier {
  final ApiService apiService;

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

  ParentLinkProvider({required this.apiService});

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

  Duration get remainingTime {
    if (_tokenExpiresAt == null) return Duration.zero;
    final now = DateTime.now();
    if (now.isAfter(_tokenExpiresAt!)) return Duration.zero;
    return _tokenExpiresAt!.difference(now);
  }

  String get remainingTimeFormatted {
    final duration = remainingTime;
    if (duration.inMinutes <= 0) return 'Expired';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours hour${hours > 1 ? 's' : ''} ${minutes} minute${minutes != 1 ? 's' : ''}';
    } else {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    }
  }

  bool get isTokenExpired {
    if (_tokenExpiresAt == null) return true;
    return DateTime.now().isAfter(_tokenExpiresAt!);
  }

  // Start countdown timer for token
  void _startCountdownTimer() {
    _stopCountdownTimer(); // Clear any existing timer

    if (_tokenExpiresAt != null && !isTokenExpired) {
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (isTokenExpired) {
          _stopCountdownTimer();
          _parentToken = null;
          _tokenExpiresAt = null;
          notifyListeners();
        } else {
          notifyListeners(); // Update UI every second
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

      debugLog(
          'ParentLinkProvider', 'Generated token expiresAt: $_tokenExpiresAt');

      // Start countdown timer
      _startCountdownTimer();

      _hasLoaded = true;
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
    // Don't show loading if we already have cached data and not forcing refresh
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
      debugLog('ParentLinkProvider', 'Fetching parent link status');
      final response = await apiService.getParentLinkStatus();
      final parentLink = response.data;

      if (parentLink != null) {
        // Store the full parent link data
        _parentLinkData = parentLink;

        // Stop any existing timer
        _stopCountdownTimer();

        // Update status based on parent link data
        _isLinked = parentLink.isLinked;
        _parentTelegramUsername = parentLink.parentTelegramUsername;
        _linkedAt = parentLink.linkedAt;
        _parentName = parentLink.parentName;

        if (!_isLinked) {
          _parentToken = parentLink.token;
          _tokenExpiresAt = parentLink.tokenExpiresAt;

          // Start countdown if we have a token
          if (_parentToken != null && _tokenExpiresAt != null) {
            _startCountdownTimer();
          }
        } else {
          _parentToken = null;
          _tokenExpiresAt = null;
        }
      } else {
        // No parent link data found
        _parentLinkData = null;
        _isLinked = false;
        _parentTelegramUsername = null;
        _linkedAt = null;
        _parentName = null;
        _parentToken = null;
        _tokenExpiresAt = null;
      }

      _hasLoaded = true;
      debugLog('ParentLinkProvider', 'Parent link status: isLinked=$_isLinked');
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'getParentLinkStatus error: $e');
      // Don't rethrow - we want to show cached data even if refresh fails
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> refreshParentLinkStatus() async {
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

      // Reset state
      _stopCountdownTimer();
      _isLinked = false;
      _parentTelegramUsername = null;
      _linkedAt = null;
      _parentToken = null;
      _tokenExpiresAt = null;
      _parentName = null;
      _parentLinkData = null;
      _hasLoaded = true;

      debugLog('ParentLinkProvider', 'Parent unlinked');
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'unlinkParent error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
  }

  // Manually update link status (for when parent links via Telegram)
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
    notifyListeners();
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _stopCountdownTimer();
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
