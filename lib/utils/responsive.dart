import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'dart:io' show Platform;

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

  static double responsiveValue({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.75;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.5;
    if (isTablet(context)) return tablet ?? mobile * 1.25;
    return mobile;
  }

  static int responsiveGridCount({
    required BuildContext context,
    required int mobile,
    int? tablet,
    int? desktop,
    int? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? (desktop ?? (tablet ?? mobile) * 2);
    }
    if (isDesktop(context)) return desktop ?? (tablet ?? mobile * 2);
    if (isTablet(context)) return tablet ?? mobile + 1;
    return mobile;
  }

  static EdgeInsetsGeometry responsivePadding({
    required BuildContext context,
    required EdgeInsets mobile,
    EdgeInsets? tablet,
    EdgeInsets? desktop,
    EdgeInsets? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? _scaleEdgeInsets(desktop ?? tablet ?? mobile, 2.0);
    }
    if (isDesktop(context)) {
      return desktop ?? _scaleEdgeInsets(tablet ?? mobile, 1.5);
    }
    if (isTablet(context)) return tablet ?? _scaleEdgeInsets(mobile, 1.25);
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

  static double responsiveFontSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.3;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.2;
    if (isTablet(context)) return tablet ?? mobile * 1.1;
    return mobile;
  }

  static double responsiveIconSize({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.5;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.35;
    if (isTablet(context)) return tablet ?? mobile * 1.2;
    return mobile;
  }

  static double responsiveBorderRadius({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.3;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.2;
    if (isTablet(context)) return tablet ?? mobile * 1.1;
    return mobile;
  }

  static double responsiveElevation({
    required BuildContext context,
    required double mobile,
    double? tablet,
    double? desktop,
    double? largeScreen,
  }) {
    if (isLargeScreen(context)) {
      return largeScreen ?? desktop ?? tablet ?? mobile * 1.2;
    }
    if (isDesktop(context)) return desktop ?? tablet ?? mobile * 1.1;
    if (isTablet(context)) return tablet ?? mobile * 1.05;
    return mobile;
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

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    required this.tablet,
    required this.desktop,
    this.largeScreen,
    this.animateTransition = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        Widget selectedWidget;

        if (screenWidth >= 1200) {
          selectedWidget = largeScreen ?? desktop;
        } else if (screenWidth >= 1024)
          selectedWidget = desktop;
        else if (screenWidth >= 600)
          selectedWidget = tablet;
        else
          selectedWidget = mobile;

        if (animateTransition) {
          return selectedWidget
              .animate()
              .fadeIn(duration: AppThemes.animationDurationMedium)
              .scaleXY(
                  begin: 0.95,
                  end: 1,
                  duration: AppThemes.animationDurationMedium);
        }
        return selectedWidget;
      },
    );
  }
}

class ResponsiveWidget extends StatelessWidget {
  final Widget Function(BuildContext, BoxConstraints) builder;
  final bool animate;

  const ResponsiveWidget(
      {super.key, required this.builder, this.animate = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widget = builder(context, constraints);
        if (animate) {
          return widget
              .animate()
              .fadeIn(duration: AppThemes.animationDurationFast)
              .slideY(
                  begin: 0.05,
                  end: 0,
                  duration: AppThemes.animationDurationMedium);
        }
        return widget;
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

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.centerContent = true,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? _getMaxWidth(context)),
      padding: padding ?? _getPadding(context),
      child: child,
    );

    final centeredContent = centerContent ? Center(child: content) : content;

    if (animate) {
      return centeredContent
          .animate()
          .fadeIn(duration: AppThemes.animationDurationMedium)
          .scale(
              begin: const Offset(0.98, 0.98),
              end: const Offset(1, 1),
              duration: AppThemes.animationDurationMedium);
    }
    return centeredContent;
  }

  double _getMaxWidth(BuildContext context) {
    if (ScreenSize.isLargeScreen(context)) return 1440;
    if (ScreenSize.isDesktop(context)) return 1200;
    if (ScreenSize.isTablet(context)) return 900;
    return double.infinity;
  }

  EdgeInsetsGeometry _getPadding(BuildContext context) {
    if (ScreenSize.isLargeScreen(context)) {
      return const EdgeInsets.symmetric(horizontal: 64, vertical: 32);
    }
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final int? largeScreenColumns;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final bool animateItems;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns,
    this.desktopColumns,
    this.largeScreenColumns,
    this.spacing = AppThemes.spacingL,
    this.runSpacing = AppThemes.spacingL,
    this.padding = EdgeInsets.zero,
    this.animateItems = true,
    this.shrinkWrap = true,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: GridView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics ?? const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getColumnCount(context),
          crossAxisSpacing: spacing,
          mainAxisSpacing: runSpacing,
          childAspectRatio: _getAspectRatio(_getColumnCount(context)),
        ),
        itemCount: children.length,
        itemBuilder: (context, index) {
          final child = children[index];
          if (animateItems) {
            return child
                .animate()
                .fadeIn(duration: AppThemes.animationDurationMedium)
                .slideY(
                    begin: 0.1,
                    end: 0,
                    duration: AppThemes.animationDurationMedium);
          }
          return child;
        },
      ),
    );
  }

  int _getColumnCount(BuildContext context) {
    if (ScreenSize.isLargeScreen(context)) {
      return largeScreenColumns ??
          (desktopColumns ?? (tabletColumns ?? mobileColumns) * 2);
    }
    if (ScreenSize.isDesktop(context)) {
      return desktopColumns ?? (tabletColumns ?? mobileColumns * 2);
    }
    if (ScreenSize.isTablet(context)) {
      return tabletColumns ?? (mobileColumns + 1);
    }
    return mobileColumns;
  }

  double _getAspectRatio(int columns) {
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

  static void runOnWindows(Function() callback) {
    if (isWindows) callback();
  }

  static bool canUseFirebase() => isMobile;
  static bool canUseLocalNotifications() => true;
  static bool canUseBiometrics() => isMobile;
  static bool canUseTelegramFeatures() => true;
}
