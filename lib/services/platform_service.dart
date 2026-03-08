import 'dart:io';
import 'package:flutter/foundation.dart';

class PlatformService {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get isLinux => Platform.isLinux;
  static bool get isWindows => Platform.isWindows;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;

  static String get platformName {
    if (isAndroid) return 'Android';
    if (isIOS) return 'iOS';
    if (isWindows) return 'Windows';
    if (isLinux) return 'Linux';
    if (isMacOS) return 'macOS';
    return 'Unknown';
  }

  static bool get shouldAwaitServices => isMobile;
  static bool get shouldUseFirebase => isMobile;
  static bool get shouldUseSecureStorage => isMobile;
  static bool get shouldUseScreenProtection => isMobile;

  static void logPlatformInfo() {
    debugPrint('📱 Platform: $platformName');
    debugPrint('   - isMobile: $isMobile');
    debugPrint('   - isDesktop: $isDesktop');
    debugPrint('   - shouldAwaitServices: $shouldAwaitServices');
  }
}
