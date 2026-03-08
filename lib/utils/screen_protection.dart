import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:familyacademyclient/services/platform_service.dart';
import 'helpers.dart';

class ScreenProtectionService {
  static bool _protectionEnabled = true;
  static bool _initialized = false;
  static const MethodChannel _channel =
      MethodChannel('com.familyacademy/screen_protection');

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!PlatformService.isMobile) {
      debugLog('ScreenProtection', '🖥️ Skipping initialization on desktop');
      _initialized = true;
      return;
    }

    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      await enableSecureMode();
      _initialized = true;
      debugLog('ScreenProtection', '✅ Initialized with full protection');
    } catch (e) {
      debugLog('ScreenProtection', '❌ Initialization error: $e');
      _initialized = true;
    }
  }

  static Future<void> enableSecureMode() async {
    if (!PlatformService.isMobile) return;

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
      } else if (Platform.isIOS) {
        await _channel.invokeMethod('protectScreen');

        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [],
        );
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error enabling secure mode: $e');
      await _setSafeSystemUiFlags();
    }
  }

  static Future<void> _setSafeSystemUiFlags() async {
    if (!PlatformService.isMobile) return;

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('setSystemUiMode', 'immersive');
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
          overlays: [],
        );
      }
    } catch (e) {}
  }

  static Future<void> disableSplitScreen() async {
    if (!PlatformService.isMobile) return;

    try {
      if (Platform.isAndroid) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);

        try {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
            overlays: [],
          );
        } catch (e) {
          await _setSafeSystemUiFlags();
        }

        await _channel.invokeMethod('disableSplitScreen');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error disabling split screen: $e');
    }
  }

  static void enableOnResume() {
    if (!PlatformService.isMobile) return;
    if (!_protectionEnabled) return;
    _setSecureFlags(true);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    debugLog('ScreenProtection', '🛡️ Protection enabled on resume');
  }

  static void disableOnPause() {
    if (!PlatformService.isMobile) return;
    _setSecureFlags(false);
    debugLog('ScreenProtection', '⚠️ Protection disabled on pause');
  }

  static void disable() {
    if (!PlatformService.isMobile) return;
    _protectionEnabled = false;
    _setSecureFlags(false);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    debugLog('ScreenProtection', '🔓 Protection disabled');
  }

  static void enable() {
    if (!PlatformService.isMobile) return;
    _protectionEnabled = true;
    _setSecureFlags(true);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    debugLog('ScreenProtection', '🔒 Protection enabled');
  }

  static void _setSecureFlags(bool secure) {
    if (!PlatformService.isMobile) return;

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
    if (!PlatformService.isMobile) return child;
    if (!enableProtection || !_protectionEnabled) return child;

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) enableOnResume();
        return false;
      },
      child: RepaintBoundary(
        child: child,
      ),
    );
  }

  static Widget preventScreenshot(Widget child) {
    if (!PlatformService.isMobile) return child;

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
    if (!PlatformService.isMobile) return;

    _protectionEnabled = true;
    _initialized = false;

    await SystemChrome.setPreferredOrientations([]);
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (e) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
    }
    debugLog('ScreenProtection', '🧹 Protection cleared');
  }
}
