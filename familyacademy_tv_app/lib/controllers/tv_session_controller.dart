import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/content_models.dart';
import '../services/tv_api_service.dart';

enum TvBootState { loading, pairing, authenticated, error }

class TvSessionController extends ChangeNotifier with WidgetsBindingObserver {
  TvSessionController(this._apiService);

  static const _tokenKey = 'tv_token';
  static const _deviceIdKey = 'tv_device_id';
  static const _pairingCodeKey = 'tv_pairing_code';
  static const _pairingExpiresAtKey = 'tv_pairing_expires_at';
  static const _pairingStartRetryDelay = Duration(seconds: 5);
  static const _maxPairingStartAttempts = 3;
  static const _pairingStartTimeout = Duration(seconds: 15);

  final TvApiService _apiService;
  final Uuid _uuid = const Uuid();

  TvBootState state = TvBootState.loading;
  String? errorMessage;
  String? deviceId;
  String? pairingCode;
  DateTime? pairingExpiresAt;
  TvUser? currentUser;

  Timer? _pollTimer;
  Timer? _sessionTimer;
  Timer? _countdownTimer;
  bool _bootstrapped = false;
  DateTime? _loadingStartedAt;
  bool _isStartingPairing = false;
  bool _isPollingPairing = false;
  int _sessionValidationFailures = 0;
  int _pairingStartAttempts = 0;

  bool get isAuthenticated => state == TvBootState.authenticated;
  bool get isPairing => state == TvBootState.pairing;

  Duration get pairingRemaining {
    if (pairingExpiresAt == null) return Duration.zero;
    final diff = pairingExpiresAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  String get pairingCountdown {
    final remaining = pairingRemaining;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    WidgetsBinding.instance.addObserver(this);
    await _restoreState();
  }

  Future<void> _restoreState() async {
    _setLoadingState();
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_tokenKey);
    deviceId = prefs.getString(_deviceIdKey) ?? _uuid.v4();
    await prefs.setString(_deviceIdKey, deviceId!);

    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        debugPrint('[TV] Restoring saved token');
        _apiService.setToken(savedToken);
        final userData = await _apiService.getSessionUser();
        currentUser = TvUser.fromJson(userData);
        pairingCode = null;
        pairingExpiresAt = null;
        state = TvBootState.authenticated;
        errorMessage = null;
        _sessionValidationFailures = 0;
        await prefs.remove(_pairingCodeKey);
        await prefs.remove(_pairingExpiresAtKey);
        debugPrint('[TV] Restored TV session successfully');
        _startSessionValidation();
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        notifyListeners();
        return;
      } on DioException catch (error) {
        final statusCode = error.response?.statusCode;
        if (statusCode == 401 || statusCode == 403) {
          debugPrint('[TV] Saved TV token was rejected ($statusCode), resetting pairing');
          await prefs.remove(_tokenKey);
          _apiService.setToken(null);
        } else {
          currentUser = const TvUser(
            id: 0,
            username: '',
            accountStatus: 'active',
          );
          state = TvBootState.authenticated;
          errorMessage = null;
          _sessionValidationFailures = 0;
          debugPrint(
            '[TV] Saved TV token restore hit a temporary error ($statusCode); keeping session and retrying validation',
          );
          _startSessionValidation();
          notifyListeners();
          return;
        }
      } catch (error) {
        currentUser = const TvUser(
          id: 0,
          username: '',
          accountStatus: 'active',
        );
        state = TvBootState.authenticated;
        errorMessage = null;
        _sessionValidationFailures = 0;
        debugPrint(
          '[TV] Saved TV token restore hit a local error; keeping session and retrying validation: $error',
        );
        _startSessionValidation();
        notifyListeners();
        return;
      }
    }

    pairingCode = prefs.getString(_pairingCodeKey);
    final savedExpiry = prefs.getInt(_pairingExpiresAtKey);
    if (savedExpiry != null) {
      pairingExpiresAt = DateTime.fromMillisecondsSinceEpoch(savedExpiry);
    }

    if (pairingCode == null ||
        pairingCode!.isEmpty ||
        pairingExpiresAt == null ||
        pairingExpiresAt!.isBefore(DateTime.now())) {
      debugPrint('[TV] No valid saved pairing session, starting new one');
      state = TvBootState.pairing;
      pairingCode = null;
      pairingExpiresAt = null;
      errorMessage = 'Generating your TV pairing code...';
      notifyListeners();
      unawaited(startPairingSession(showLoadingState: false));
      return;
    }

    debugPrint(
      '[TV] Restored saved pairing session deviceId=$deviceId code=$pairingCode expiresAt=$pairingExpiresAt',
    );
    state = TvBootState.pairing;
    errorMessage = null;
    _startPolling();
    _startCountdownTicker();
    notifyListeners();
  }

  Future<void> startPairingSession({bool showLoadingState = false}) async {
    if (_isStartingPairing) return;
    _isStartingPairing = true;
    try {
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      if (showLoadingState) {
        _setLoadingState();
      } else {
        state = TvBootState.pairing;
        errorMessage = 'Generating your TV pairing code...';
      }
      notifyListeners();

      if (deviceId == null || deviceId!.isEmpty) {
        deviceId = _uuid.v4();
      }

      debugPrint('[TV] Requesting new pairing session for deviceId=$deviceId');
      final data = await _apiService
          .startTvPairingSession(deviceId!)
          .timeout(_pairingStartTimeout);
      pairingCode = data['pairing_code']?.toString();
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 1800;
      pairingExpiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      _pairingStartAttempts = 0;
      debugPrint(
        '[TV] Started pairing session deviceId=$deviceId code=$pairingCode expiresIn=$expiresIn',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceIdKey, deviceId!);
      await prefs.setString(_pairingCodeKey, pairingCode ?? '');
      await prefs.setInt(
        _pairingExpiresAtKey,
        pairingExpiresAt!.millisecondsSinceEpoch,
      );

      state = TvBootState.pairing;
      errorMessage = null;
      _startPolling();
      _startCountdownTicker();
      notifyListeners();
    } catch (error) {
      debugPrint('[TV] Failed to start pairing session: $error');
      _countdownTimer?.cancel();
      _pairingStartAttempts += 1;

      if (_pairingStartAttempts < _maxPairingStartAttempts) {
        state = TvBootState.pairing;
        errorMessage =
            'Starting TV pairing... retrying connection (${_pairingStartAttempts + 1}/$_maxPairingStartAttempts)';
        notifyListeners();
        await Future<void>.delayed(_pairingStartRetryDelay);
        if (!_isStartingPairing) {
          return;
        }
      } else {
        state = TvBootState.error;
        errorMessage =
            'Could not start TV pairing. Check the internet connection and try again.';
        notifyListeners();
      }
    } finally {
      _isStartingPairing = false;
    }

    if (state != TvBootState.pairing &&
        _pairingStartAttempts > 0 &&
        _pairingStartAttempts < _maxPairingStartAttempts) {
      await startPairingSession();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    unawaited(pollPairingStatus());
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      pollPairingStatus();
    });
  }

  void _startCountdownTicker() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state == TvBootState.pairing) {
        if (pairingExpiresAt != null &&
            !pairingExpiresAt!.isAfter(DateTime.now())) {
          unawaited(startPairingSession());
          return;
        }
        notifyListeners();
      }
    });
  }

  Future<void> pollPairingStatus() async {
    if (_isPollingPairing ||
        deviceId == null ||
        pairingCode == null ||
        pairingCode!.isEmpty) {
      return;
    }

    if (pairingExpiresAt != null &&
        pairingExpiresAt!.isBefore(DateTime.now())) {
      await startPairingSession(showLoadingState: false);
      return;
    }

    _isPollingPairing = true;
    try {
      final data = await _apiService.getTvPairingStatus(
        deviceId: deviceId!,
        pairingCode: pairingCode!,
      );
      final status = data['status']?.toString() ?? 'pending';
      final expiresAtRaw = data['expires_at']?.toString();
      if (expiresAtRaw != null && expiresAtRaw.isNotEmpty) {
        final parsedExpiresAt = DateTime.tryParse(expiresAtRaw)?.toLocal();
        if (parsedExpiresAt != null) {
          pairingExpiresAt = parsedExpiresAt;
        }
      }
      debugPrint(
        '[TV] Poll status deviceId=$deviceId code=$pairingCode status=$status token=${data['token'] != null}',
      );
      if (status != 'paired' || data['token'] == null) {
        if (status == 'expired') {
          await startPairingSession(showLoadingState: false);
        } else {
          notifyListeners();
        }
        return;
      }

      final token = data['token']?.toString() ?? '';
      if (token.isEmpty) return;
      debugPrint('[TV] Pairing authorized, storing token');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      _apiService.setToken(token);

      final userData = Map<String, dynamic>.from(
        data['user'] as Map? ?? const {},
      );
      currentUser = TvUser.fromJson(userData);
      state = TvBootState.authenticated;
      errorMessage = null;
      _sessionValidationFailures = 0;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      _startSessionValidation();
      notifyListeners();
    } catch (error) {
      debugPrint('[TV] Poll failed: $error');
      notifyListeners();
    } finally {
      _isPollingPairing = false;
    }
  }

  void _setLoadingState() {
    state = TvBootState.loading;
    _loadingStartedAt = DateTime.now();
    Future<void>.delayed(const Duration(seconds: 16), () {
      if (state == TvBootState.loading) {
        state = TvBootState.error;
        errorMessage =
            'Starting TV pairing is taking too long. Please try Refresh Code.';
        notifyListeners();
      }
    });
  }

  bool get loadingTimedOut {
    if (state != TvBootState.loading || _loadingStartedAt == null) {
      return false;
    }
    return DateTime.now().difference(_loadingStartedAt!) >
        const Duration(seconds: 15);
  }

  void _startSessionValidation() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(validateActiveSession());
    });
  }

  Future<void> validateActiveSession() async {
    if (!isAuthenticated) return;
    try {
      final userData = await _apiService.getSessionUser();
      currentUser = TvUser.fromJson(userData);
      _sessionValidationFailures = 0;
      debugPrint('[TV] Session validation succeeded');
      notifyListeners();
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        debugPrint('[TV] Session validation rejected token ($statusCode), resetting pairing');
        await resetPairing();
        return;
      }

      _sessionValidationFailures += 1;
      debugPrint(
        '[TV] Session validation failed ($statusCode), keeping session alive for now',
      );
      if (_sessionValidationFailures >= 3) {
        state = TvBootState.error;
        errorMessage =
            'We could not refresh the TV session. Please try pairing again.';
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (isAuthenticated) {
        unawaited(validateActiveSession());
      } else if (isPairing) {
        unawaited(pollPairingStatus());
      }
    }
  }

  Future<void> resetPairing({bool unpairServer = false}) async {
    debugPrint('[TV] Resetting TV pairing (unpairServer=$unpairServer)');
    try {
      if (unpairServer && isAuthenticated) {
        await _apiService.unpairTv();
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_pairingCodeKey);
    await prefs.remove(_pairingExpiresAtKey);

    currentUser = null;
    pairingCode = null;
    pairingExpiresAt = null;
    _sessionTimer?.cancel();
    _countdownTimer?.cancel();
    _pollTimer?.cancel();
    _sessionValidationFailures = 0;
    _apiService.setToken(null);
    await startPairingSession(showLoadingState: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _sessionTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }
}
