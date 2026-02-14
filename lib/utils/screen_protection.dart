import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../utils/helpers.dart';

class ScreenProtectionService {
  static bool _protectionEnabled = true;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    debugLog('ScreenProtection', 'Initializing screen protection');

    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    await enableSecureMode();

    _initialized = true;
    debugLog('ScreenProtection', '✅ Screen protection initialized');
  }

  static Future<void> enableSecureMode() async {
    try {
      // Use safe system UI mode that works on all platforms
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          // Try edgeToEdge first (for newer devices)
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        } catch (e) {
          debugLog('ScreenProtection', 'edgeToEdge not supported: $e');
          // Fallback to manual flags
          await _setSafeSystemUiFlags();
        }

        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.black,
          ),
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
        // Use manual flags for compatibility
        final methodChannel =
            const MethodChannel('com.familyacademy/screen_protection');
        await methodChannel.invokeMethod('setSystemUiMode', 'immersive');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error setting manual flags: $e');
    }
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
          debugLog('ScreenProtection', 'immersiveSticky not supported: $e');
          await _setSafeSystemUiFlags();
        }
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error disabling split screen: $e');
    }
  }

  static void enableOnResume() {
    if (!_protectionEnabled) return;

    debugLog('ScreenProtection', '🛡️ Enabling screen protection on resume');

    _setSecureFlags(true);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  static void disableOnPause() {
    debugLog('ScreenProtection',
        '🔓 Temporarily disabling screen protection on pause');

    _setSecureFlags(false);
  }

  static void disable() {
    debugLog('ScreenProtection', '🔓 Permanently disabling screen protection');

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
  }

  static void enable() {
    debugLog('ScreenProtection', '🛡️ Permanently enabling screen protection');

    _protectionEnabled = true;
    _setSecureFlags(true);

    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  static void _setSecureFlags(bool secure) {
    try {
      if (Platform.isAndroid) {
        final methodChannel =
            const MethodChannel('com.familyacademy/screen_protection');
        methodChannel
            .invokeMethod(secure ? 'protectScreen' : 'unprotectScreen');
      }
    } catch (e) {
      debugLog('ScreenProtection', 'Error setting secure flags: $e');
    }
  }

  static bool isEnabled() {
    return _protectionEnabled;
  }

  static Widget protectWidget(Widget child, {bool enableProtection = true}) {
    if (!enableProtection || !_protectionEnabled) {
      return child;
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (notification.direction != ScrollDirection.idle) {
          enableOnResume();
        }
        return false;
      },
      child: child,
    );
  }

  static Widget preventScreenshot(Widget child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: child,
    );
  }

  static Future<void> clear() async {
    debugLog('ScreenProtection', '🧹 Clearing screen protection settings');

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
  }
}
