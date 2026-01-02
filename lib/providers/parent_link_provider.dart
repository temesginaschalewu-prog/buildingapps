import 'package:flutter/material.dart';
import '../services/api_service.dart';
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

  ParentLinkProvider({required this.apiService});

  String? get parentToken => _parentToken;
  DateTime? get tokenExpiresAt => _tokenExpiresAt;
  bool get isLinked => _isLinked;
  bool get hasLoaded => _hasLoaded;
  String? get parentTelegramUsername => _parentTelegramUsername;
  DateTime? get linkedAt => _linkedAt;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Add the missing getter
  Duration get remainingTime {
    if (_tokenExpiresAt == null) return Duration.zero;
    final now = DateTime.now();
    if (now.isAfter(_tokenExpiresAt!)) return Duration.zero;
    return _tokenExpiresAt!.difference(now);
  }

  bool get isTokenExpired {
    if (_tokenExpiresAt == null) return true;
    return DateTime.now().isAfter(_tokenExpiresAt!);
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

      debugLog(
          'ParentLinkProvider', 'Generated token expiresAt: $_tokenExpiresAt');
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
    if (_isLoading) return;
    if (_hasLoaded && !forceRefresh) return;

    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('ParentLinkProvider', 'Fetching parent link status');
      final response = await apiService.getParentLinkStatus();
      final parentLink = response.data;

      if (parentLink != null) {
        // Check if parentLink has status field or linked status
        // Adjust based on your actual ParentLink model
        _isLinked = parentLink.status == 'linked' ||
            parentLink.parentTelegramUsername != null;

        _parentTelegramUsername = parentLink.parentTelegramUsername;
        _linkedAt = parentLink.linkedAt;

        if (!_isLinked) {
          _parentToken = parentLink.token;
          _tokenExpiresAt = parentLink.tokenExpiresAt;
        }
      }

      _hasLoaded = true;
      debugLog('ParentLinkProvider', 'Parent link status: isLinked=$_isLinked');
    } catch (e) {
      _error = e.toString();
      debugLog('ParentLinkProvider', 'getParentLinkStatus error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      _notifySafely();
    }
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
      _isLinked = false;
      _parentTelegramUsername = null;
      _linkedAt = null;
      _parentToken = null;
      _tokenExpiresAt = null;
      _hasLoaded = false;

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

  void clearError() {
    _error = null;
    _notifySafely();
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
