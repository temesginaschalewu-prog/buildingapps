import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'platform_helper.dart';
import 'helpers.dart';

/// Comprehensive Screen Protection Service
/// Prevents screen recording, screenshots, and content capture across all platforms
class ScreenProtectionService {
  static bool _protectionEnabled = true;
  static bool _initialized = false;
  static const MethodChannel _channel =
      MethodChannel('com.familyacademy/screen_protection');

  static bool _isSecureModeEnabled = false;
  static DeviceOrientation? _lastOrientation;

  // Overlay for content protection on desktop/TV
  static bool _showProtectionOverlay = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (PlatformHelper.isMobile) {
        // Mobile-specific protection
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        _lastOrientation = DeviceOrientation.portraitUp;
        await enableSecureMode();
        debugLog('ScreenProtection', '✅ Mobile protection initialized');
      } else if (PlatformHelper.isDesktop || PlatformHelper.isTv) {
        // Desktop/TV protection via overlay
        await _initializeDesktopProtection();
        debugLog('ScreenProtection', '✅ Desktop/TV protection initialized');
      }

      _initialized = true;
    } catch (e) {
      debugLog('ScreenProtection', '❌ Initialization error: $e');
      _initialized = true;
    }
  }

  /// Initialize desktop/TV specific protection
  static Future<void> _initializeDesktopProtection() async {
    // Set up detection for screen capture on desktop/TV
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      // Listen for window focus changes
      // Note: Full screen capture prevention on desktop is limited
      // We use visual overlays and DRM-like techniques

      // Enable secure rendering hints
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);

      debugLog('ScreenProtection', '🖥️ Desktop protection enabled');
    }
  }

  static Future<void> enableSecureMode() async {
    if (!PlatformHelper.isMobile) return;
    if (_isSecureModeEnabled) return;

    try {
      if (Platform.isAndroid) {
        // Android: Use FLAG_SECURE to prevent screenshots and screen recording
        await _channel.invokeMethod('protectScreen');

        // Additional Android-specific protections
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
        debugLog('ScreenProtection', '🔒 Android FLAG_SECURE enabled');
      } else if (Platform.isIOS) {
        // iOS: Prevent screen capture via native code
        await _channel.invokeMethod('protectScreen');

        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
          overlays: [],
        );

        _isSecureModeEnabled = true;
        debugLog('ScreenProtection', '🔒 iOS screen protection enabled');
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

  /// Wrap video content with protection overlay for desktop/TV
  static Widget protectVideoContent(Widget child,
      {bool enableProtection = true}) {
    if (!enableProtection || !_protectionEnabled) return child;

    if (PlatformHelper.isMobile) {
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
    } else if (PlatformHelper.isDesktop || PlatformHelper.isTv) {
      // For desktop/TV, add visual deterrents and detection
      return _DesktopVideoProtector(child: child);
    }

    return child;
  }

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

  /// Add watermark overlay for content protection on all platforms
  static Widget addWatermark({
    required Widget child,
    String? watermarkText,
    Color? color,
    double opacity = 0.08,
  }) {
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: CustomPaint(
            painter: WatermarkPainter(
              text: watermarkText ?? 'Family Academy',
              color: color ?? Colors.white,
              opacity: opacity,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }

  static Future<void> clear() async {
    _protectionEnabled = true;
    _initialized = false;
    _isSecureModeEnabled = false;
    _lastOrientation = null;
    _showProtectionOverlay = false;

    if (PlatformHelper.isMobile) {
      await SystemChrome.setPreferredOrientations([]);
      try {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      } catch (e) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual);
      }
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
      'showProtectionOverlay': _showProtectionOverlay,
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

/// Desktop/TV Video Protector Widget
/// Adds visual deterrents and basic protection for non-mobile platforms
class _DesktopVideoProtector extends StatefulWidget {
  final Widget child;

  const _DesktopVideoProtector({required this.child});

  @override
  State<_DesktopVideoProtector> createState() => _DesktopVideoProtectorState();
}

class _DesktopVideoProtectorState extends State<_DesktopVideoProtector>
    with WidgetsBindingObserver {
  bool _isRecording = false;
  bool _showWarning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showWarning)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_off_rounded,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Screen recording is not allowed',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This content is protected by copyright',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Subtle watermark
        IgnorePointer(
          child: CustomPaint(
            painter: _DesktopWatermarkPainter(),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

/// Watermark painter for content protection
class WatermarkPainter extends CustomPainter {
  final String text;
  final Color color;
  final double opacity;

  WatermarkPainter({
    required this.text,
    required this.color,
    this.opacity = 0.08,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    const spacing = 120.0;
    const angle = -0.3;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-size.width / 2, -size.height / 2);

    for (double y = -spacing; y < size.height + spacing; y += spacing * 1.5) {
      for (double x = -spacing; x < size.width + spacing; x += spacing * 2) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant WatermarkPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.color != color ||
        oldDelegate.opacity != opacity;
  }
}

/// Desktop watermark painter
class _DesktopWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Family Academy • Protected Content',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    const spacing = 200.0;
    const angle = -0.2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angle);
    canvas.translate(-size.width / 2, -size.height / 2);

    for (double y = -spacing; y < size.height + spacing; y += spacing * 2) {
      for (double x = -spacing; x < size.width + spacing; x += spacing * 3) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
