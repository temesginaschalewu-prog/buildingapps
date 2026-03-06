import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;
import '../themes/app_themes.dart';

class ScreenSize {
  static double getScreenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double getScreenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;
  static double getPixelRatio(BuildContext context) =>
      MediaQuery.of(context).devicePixelRatio;
  static EdgeInsets getViewInsets(BuildContext context) =>
      MediaQuery.of(context).viewInsets;
  static EdgeInsets getViewPadding(BuildContext context) =>
      MediaQuery.of(context).viewPadding;
  static Orientation getOrientation(BuildContext context) =>
      MediaQuery.of(context).orientation;
  static bool isLandscape(BuildContext context) =>
      getOrientation(context) == Orientation.landscape;
  static bool isPortrait(BuildContext context) =>
      getOrientation(context) == Orientation.portrait;
  static bool isMobile(BuildContext context) => getScreenWidth(context) < 600;
  static bool isTablet(BuildContext context) =>
      getScreenWidth(context) >= 600 && getScreenWidth(context) < 1024;
  static bool isDesktop(BuildContext context) =>
      getScreenWidth(context) >= 1024;
  static bool isLargeScreen(BuildContext context) =>
      getScreenWidth(context) >= 1200;

  static T responsiveValue<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
    T? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? mobile;
    return mobile;
  }

  static double responsiveDouble({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.15;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.1;
    if (isTablet(context)) return tablet ?? mobile * 1.05;
    return mobile;
  }

  static double fontSize({
    required BuildContext context,
    required double base,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    return responsiveDouble(
      context: context,
      mobile: base,
      tablet: tablet ?? base * 1.05,
      desktop: desktop ?? base * 1.1,
      largeScreen: largeScreen ?? base * 1.15,
    );
  }

  static double iconSize({
    required BuildContext context,
    required double base,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    return responsiveDouble(
      context: context,
      mobile: base,
      tablet: tablet ?? base * 1.05,
      desktop: desktop ?? base * 1.1,
      largeScreen: largeScreen ?? base * 1.15,
    );
  }

  static double borderRadius({
    required BuildContext context,
    required double base,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    return responsiveDouble(
      context: context,
      mobile: base,
      tablet: tablet ?? base * 1.05,
      desktop: desktop ?? base * 1.1,
      largeScreen: largeScreen ?? base * 1.15,
    );
  }

  static int gridColumns({
    required BuildContext context,
    required int mobile,
    int? tablet,
    int? desktop,
    int? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile * 2;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 2;
    if (isTablet(context)) return tablet ?? mobile + 1;
    return mobile;
  }

  static double cardAspectRatio({
    required BuildContext context,
    required int columns,
  }) {
    switch (columns) {
      case 1:
        return 1.4;
      case 2:
        return 1.1;
      case 3:
        return 0.95;
      case 4:
        return 0.85;
      default:
        return 0.8;
    }
  }

  static double cardHeight({
    required BuildContext context,
    required double base,
  }) {
    return responsiveDouble(
      context: context,
      mobile: base,
      tablet: base * 1.05,
      desktop: base * 1.1,
      largeScreen: base * 1.15,
    );
  }

  static EdgeInsets padding({
    required BuildContext context,
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
    EdgeInsets? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? _scaleEdgeInsets(desktop ?? tablet ?? mobile, 1.15);
    }
    if (isDesktop(context)) {
      return desktop ?? _scaleEdgeInsets(tablet ?? mobile, 1.1);
    }
    if (isTablet(context)) return tablet ?? _scaleEdgeInsets(mobile, 1.05);
    return mobile;
  }

  static EdgeInsets _scaleEdgeInsets(EdgeInsets insets, double scale) {
    return EdgeInsets.only(
      left: insets.left * scale,
      right: insets.right * scale,
      top: insets.top * scale,
      bottom: insets.bottom * scale,
    );
  }

  static double getSafeAreaTop(BuildContext context) =>
      MediaQuery.of(context).padding.top;
  static double getSafeAreaBottom(BuildContext context) =>
      MediaQuery.of(context).padding.bottom;
  static double getKeyboardHeight(BuildContext context) =>
      MediaQuery.of(context).viewInsets.bottom;
  static bool hasKeyboard(BuildContext context) =>
      getKeyboardHeight(context) > 0;
  static bool isFullScreen(BuildContext context) =>
      MediaQuery.of(context).padding.top == 0;
  static Brightness getPlatformBrightness(BuildContext context) =>
      MediaQuery.of(context).platformBrightness;
  static bool isDarkMode(BuildContext context) =>
      getPlatformBrightness(context) == Brightness.dark;
  static bool isLightMode(BuildContext context) =>
      getPlatformBrightness(context) == Brightness.light;
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget tablet;
  final Widget desktop;
  final Widget? largeScreen;
  final bool animateTransition;
  final Duration? animationDuration;
  final Curve? animationCurve;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
    this.largeScreen,
    this.animateTransition = true,
    this.animationDuration,
    this.animationCurve,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        Widget selectedWidget;

        if (screenWidth >= 1200) {
          selectedWidget = largeScreen ?? desktop;
        } else if (screenWidth >= 1024) {
          selectedWidget = desktop;
        } else if (screenWidth >= 600) {
          selectedWidget = tablet;
        } else {
          selectedWidget = mobile;
        }

        if (animateTransition) {
          return selectedWidget
              .animate()
              .fadeIn(
                duration: animationDuration ?? AppThemes.animationMedium,
                curve: animationCurve ?? Curves.easeOut,
              )
              .scale(
                begin: const Offset(0.97, 0.97),
                end: const Offset(1, 1),
                duration: animationDuration ?? AppThemes.animationMedium,
                curve: animationCurve ?? Curves.easeOut,
              );
        }
        return selectedWidget;
      },
    );
  }
}

class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool centerContent;
  final bool animate;
  final Alignment alignment;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centerContent = true,
    this.animate = true,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? _getMaxWidth(context),
      ),
      padding: padding ?? _getPadding(context),
      alignment: centerContent ? null : alignment,
      child: centerContent ? Center(child: child) : child,
    );

    if (animate) {
      return content
          .animate()
          .fadeIn(
            duration: AppThemes.animationMedium,
          )
          .slideY(
            begin: 0.05,
            end: 0,
            duration: AppThemes.animationMedium,
          );
    }
    return content;
  }

  double _getMaxWidth(BuildContext context) {
    if (ScreenSize.isLargeScreen(context)) return 1440;
    if (ScreenSize.isDesktop(context)) return 1200;
    if (ScreenSize.isTablet(context)) return 900;
    return double.infinity;
  }

  EdgeInsets _getPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: ScreenSize.responsiveDouble(
        context: context,
        mobile: 16,
        tablet: 20,
        desktop: 24,
        largeScreen: 32,
      ),
      vertical: ScreenSize.responsiveDouble(
        context: context,
        mobile: 16,
        tablet: 18,
        desktop: 20,
        largeScreen: 24,
      ),
    );
  }
}

class PlatformCheck {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;
  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;
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

  static void runOnMobile(Function() callback) {
    if (isMobile) callback();
  }

  static void runOnDesktop(Function() callback) {
    if (isDesktop) callback();
  }

  static bool canUseFirebase() => isMobile;
  static bool canUseLocalNotifications() => true;
  static bool canUseBiometrics() => isMobile;
  static bool canUseTelegramFeatures() => true;
}
