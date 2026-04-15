import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'helpers.dart';

enum DeviceType {
  mobile,
  tablet,
  desktop,
  tv,
}

enum PlatformVideoPlayer {
  mediaKit, // For desktop (Windows, macOS, Linux)
  videoPlayer, // For mobile (Android, iOS)
}

class PlatformHelper {
  static DeviceType _deviceType = DeviceType.mobile;
  static bool _isInitialized = false;
  static double _screenWidth = 0;
  static double _pixelRatio = 1.0;
  static bool _isLowEndDevice = false;
  static bool _hasHardwareAcceleration = true;

  static bool _platformInfoLogged = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      _screenWidth = view.physicalSize.width;
      _pixelRatio = view.devicePixelRatio;

      if (Platform.isAndroid || Platform.isIOS) {
        final widthInDp = _screenWidth / _pixelRatio;

        if (widthInDp >= 600) {
          _deviceType = DeviceType.tablet;
        } else {
          _deviceType = DeviceType.mobile;
        }

        if (Platform.isAndroid) {
          try {
            final deviceInfo = await DeviceInfoPlugin().androidInfo;

            final isPossibleTv = deviceInfo.model.contains('TV') ||
                deviceInfo.model.contains('tv') ||
                deviceInfo.manufacturer.contains('Sony') ||
                deviceInfo.manufacturer.contains('Philips') ||
                deviceInfo.manufacturer.contains('Sharp') ||
                deviceInfo.manufacturer.contains('Toshiba') ||
                deviceInfo.manufacturer.contains('NVIDIA') ||
                deviceInfo.manufacturer.contains('SHIELD');

            if (isPossibleTv && widthInDp >= 800) {
              _deviceType = DeviceType.tv;
            }

            _isLowEndDevice = deviceInfo.version.sdkInt < 29;
          } catch (e) {
            debugLog('PlatformHelper', 'Android info error: $e');
          }
        } else if (Platform.isIOS) {
          final deviceInfo = await DeviceInfoPlugin().iosInfo;
          _isLowEndDevice = deviceInfo.systemVersion.startsWith('12');
        }
      } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        _deviceType = DeviceType.desktop;

        if (Platform.isLinux) {
          _hasHardwareAcceleration = false;
        }
      }

      try {
        await PackageInfo.fromPlatform();
      } catch (_) {}
      _isInitialized = true;

      logPlatformInfo();
    } catch (e) {
      debugLog('PlatformHelper', 'Initialization error: $e');
      _isInitialized = true;
    }
  }

  static void logPlatformInfo() {
    if (_platformInfoLogged) return;
    if (!kDebugMode) {
      _platformInfoLogged = true;
      return;
    }

    debugLog('PlatformHelper',
        'Platform ready: ${Platform.operatingSystem}, $_deviceType');
    _platformInfoLogged = true;
  }

  static String get platformName {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }

  static DeviceType get deviceType => _deviceType;
  static bool get isMobile => _deviceType == DeviceType.mobile;
  static bool get isTablet => _deviceType == DeviceType.tablet;
  static bool get isDesktop => _deviceType == DeviceType.desktop;
  static bool get isTv => _deviceType == DeviceType.tv;

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;

  static bool get isLowEndDevice => _isLowEndDevice;
  static bool get hasHardwareAcceleration => _hasHardwareAcceleration;

  static PlatformVideoPlayer get recommendedPlayer {
    if (isDesktop) return PlatformVideoPlayer.mediaKit;
    return PlatformVideoPlayer.videoPlayer;
  }

  static bool get shouldUseMediaKit =>
      recommendedPlayer == PlatformVideoPlayer.mediaKit;
  static bool get shouldUseVideoPlayer =>
      recommendedPlayer == PlatformVideoPlayer.videoPlayer;

  static double get videoDialogPadding {
    if (isTv) return 40;
    if (isTablet) return 24;
    if (isDesktop) return 16;
    return 8;
  }

  static double get closeButtonSize {
    if (isTv) return 48;
    if (isTablet) return 32;
    return 24;
  }

  static double get qualityBadgeSize {
    if (isTv) return 16;
    if (isTablet) return 14;
    return 12;
  }

  static double get buttonSize {
    if (isTv) return 56;
    if (isTablet) return 48;
    return 40;
  }

  static Duration get videoTimeout {
    if (isTv) return const Duration(seconds: 30);
    if (isMobile) return const Duration(seconds: 15);
    return const Duration(seconds: 20);
  }

  static String getVideoPlayerName() {
    switch (recommendedPlayer) {
      case PlatformVideoPlayer.mediaKit:
        return 'MediaKit (MPV)';
      case PlatformVideoPlayer.videoPlayer:
        return 'VideoPlayer';
    }
  }

  static Map<String, dynamic> getMediaKitOptions(String videoUrl) {
    final options = {
      'video_url': videoUrl,
      'user_agent': 'FamilyAcademy/${isTv ? 'TV' : 'Mobile'}/1.0',
      'cache': true,
      'cache_secs': 300, // 5 minutes
    };

    // Platform-specific options
    if (isLinux) {
      options['hwdec'] = 'no'; // Force software decoding on Linux
    } else if (isWindows) {
      options['hwdec'] = 'auto'; // Auto hardware decoding on Windows
    } else if (isMacOS) {
      options['hwdec'] = 'auto'; // Auto hardware decoding on macOS
    }

    // For low-end devices, force software decoding
    if (isLowEndDevice) {
      options['hwdec'] = 'no';
    }

    return options;
  }

  // Network optimization
  static int get maxCacheSize {
    if (isTv) return 500 * 1024 * 1024; // 500MB for TV
    if (isDesktop) return 200 * 1024 * 1024; // 200MB for desktop
    return 100 * 1024 * 1024; // 100MB for mobile
  }

  static int get preloadSize {
    if (isTv) return 50 * 1024 * 1024; // 50MB for TV
    if (isDesktop) return 20 * 1024 * 1024; // 20MB for desktop
    return 10 * 1024 * 1024; // 10MB for mobile
  }

  // Quality recommendations based on device
  static String getRecommendedQualityForDevice() {
    if (isTv) return '1080p';
    if (isTablet) return '720p';
    if (isLowEndDevice) return '360p';
    return '480p'; // Default for mobile
  }

  // Battery optimization
  static bool get shouldReduceVideoQualityOnBattery => isMobile;

  // Accessibility
  static double get textScaleFactor {
    if (isTv) return 1.2;
    if (isTablet) return 1.1;
    return 1.0;
  }
}
