import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'platform_helper.dart';
import 'helpers.dart';

class ScreenProtectionService {
  static bool _protectionEnabled = true;
  static bool _initialized = false;
  static const MethodChannel _channel =
      MethodChannel('com.familyacademy/screen_protection');

  static bool _isSecureModeEnabled = false;
  static DeviceOrientation? _lastOrientation;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!PlatformHelper.isMobile) {
      debugLog('ScreenProtection', '🖥️ Skipping initialization on desktop');
      _initialized = true;
      return;
    }

    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      _lastOrientation = DeviceOrientation.portraitUp;

      await enableSecureMode();
      _initialized = true;
      debugLog('ScreenProtection', '✅ Initialized with full protection');
    } catch (e) {
      debugLog('ScreenProtection', '❌ Initialization error: $e');
      _initialized = true;
    }
  }

  static Future<void> enableSecureMode() async {
    if (!PlatformHelper.isMobile) return;
    if (_isSecureModeEnabled) return;

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('protectScreen');

        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [SystemUiOverlay.top],
        );

        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
        );

        _isSecureModeEnabled = true;
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('protectScreen');

        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [],
        );

        _isSecureModeEnabled = true;
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error enabling secure mode: $e');
      await _setSafeSystemUiFlags();
    }
  }

  static Future<void> _setSafeSystemUiFlags() async {
    if (!PlatformHelper.isMobile) return;

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('setSystemUiMode', 'immersive');
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
        _isSecureModeEnabled = true;
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error setting safe UI flags: $e');
    }
  }

  static Future<void> disableSplitScreen() async {
    if (!PlatformHelper.isMobile) return;

    try {
      if (Platform.isAndroid) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        _lastOrientation = DeviceOrientation.portraitUp;

        try {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
            overlays: [],
          );
        } catch (e) {
          await _setSafeSystemUiFlags();
        }

        await _channel.invokeMethod('disableSplitScreen');
        debugLog('ScreenProtection', '✅ Split screen disabled');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error disabling split screen: $e');
    }
  }

  static void enableOnResume() {
    if (!PlatformHelper.isMobile) return;
    if (!_protectionEnabled) return;

    _setSecureFlags(true);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _lastOrientation = DeviceOrientation.portraitUp;

    debugLog('ScreenProtection', '🛡️ Protection enabled on resume');
  }

  static void disableOnPause() {
    if (!PlatformHelper.isMobile) return;
    if (_protectionEnabled) {
      _setSecureFlags(true);
      debugLog('ScreenProtection', '🛡️ Protection kept active while paused');
      return;
    }

    _setSecureFlags(false);
    debugLog('ScreenProtection', '⚠️ Protection disabled on pause');
  }

  static void disable() {
    if (!PlatformHelper.isMobile) return;
    _protectionEnabled = false;
    _setSecureFlags(false);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _lastOrientation = null;
    debugLog('ScreenProtection', '🔓 Protection disabled');
  }

  static void enable() {
    if (!PlatformHelper.isMobile) return;
    _protectionEnabled = true;
    _setSecureFlags(true);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _lastOrientation = DeviceOrientation.portraitUp;
    debugLog('ScreenProtection', '🔒 Protection enabled');
  }

  static void _setSecureFlags(bool secure) {
    if (!PlatformHelper.isMobile) return;

    try {
      if (Platform.isAndroid) {
        _channel.invokeMethod(secure ? 'protectScreen' : 'unprotectScreen');
      } else if (Platform.isIOS) {
        _channel.invokeMethod(secure ? 'protectScreen' : 'unprotectScreen');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error setting secure flags: $e');
    }
  }

  static bool isEnabled() => _protectionEnabled;

  static Widget protectWidget(Widget child, {bool enableProtection = true}) {
    if (!PlatformHelper.isMobile) return child;
    if (!enableProtection || !_protectionEnabled) return child;

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) {
          enableOnResume();
        }
        return false;
      },
      child: RepaintBoundary(
        child: child,
      ),
    );
  }

  static Widget preventScreenshot(Widget child) {
    if (!PlatformHelper.isMobile) return child;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: RepaintBoundary(
        child: child,
      ),
    );
  }

  static Future<void> clear() async {
    if (!PlatformHelper.isMobile) return;

    _protectionEnabled = true;
    _initialized = false;
    _isSecureModeEnabled = false;
    _lastOrientation = null;

    await SystemChrome.setPreferredOrientations([]);
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
    }
    debugLog('ScreenProtection', '🧹 Protection cleared');
  }

  // Get current protection status
  static Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _initialized,
      'isProtectionEnabled': _protectionEnabled,
      'isSecureModeEnabled': _isSecureModeEnabled,
      'lastOrientation': _lastOrientation?.toString(),
      'platform': PlatformHelper.platformName,
    };
  }

  // Toggle protection on/off
  static Future<void> toggleProtection() async {
    if (_protectionEnabled) {
      disable();
    } else {
      enable();
    }
  }

  // Force reapply protection settings
  static Future<void> reapplyProtection() async {
    if (!PlatformHelper.isMobile) return;
    if (!_protectionEnabled) return;

    await enableSecureMode();
    if (_lastOrientation != null) {
      await SystemChrome.setPreferredOrientations([_lastOrientation!]);
    }
    debugLog('ScreenProtection', '🔄 Protection reapplied');
  }
}
