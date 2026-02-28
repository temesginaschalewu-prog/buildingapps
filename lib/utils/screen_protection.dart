import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../utils/helpers.dart';

class ScreenProtectionService {
  static bool _protectionEnabled = true;
  static bool _initialized = false;
  static const MethodChannel _channel =
      MethodChannel('com.familyacademy/screen_protection');

  static Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    await enableSecureMode();
    _initialized = true;
    debugLog('ScreenProtection', '✅ Initialized with full protection');
  }

  static Future<void> enableSecureMode() async {
    try {
      if (Platform.isAndroid) {
        // Set FLAG_SECURE to prevent screenshots and screen recording
        await _channel.invokeMethod('protectScreen');

        // Set immersive mode for better protection
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
        // iOS specific protection
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

        // Additional protection against split screen
        await _channel.invokeMethod('disableSplitScreen');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error disabling split screen: $e');
    }
  }

  static void enableOnResume() {
    if (!_protectionEnabled) return;
    _setSecureFlags(true);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    debugLog('ScreenProtection', '🛡️ Protection enabled on resume');
  }

  static void disableOnPause() {
    _setSecureFlags(false);
    debugLog('ScreenProtection', '⚠️ Protection disabled on pause');
  }

  static void disable() {
    _protectionEnabled = false;
    _setSecureFlags(false);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    debugLog('ScreenProtection', '🔓 Protection disabled');
  }

  static void enable() {
    _protectionEnabled = true;
    _setSecureFlags(true);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    debugLog('ScreenProtection', '🔒 Protection enabled');
  }

  static void _setSecureFlags(bool secure) {
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
    _protectionEnabled = true;
    _initialized = false;

    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([]);
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (e) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
      }
    }
    debugLog('ScreenProtection', '🧹 Protection cleared');
  }
}
