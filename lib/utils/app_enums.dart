import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:flutter/material.dart';

enum AppSpacing {
  /// 0px - No spacing
  none(0),

  /// 2px - Extra extra small
  xxs(2),

  /// 4px - Extra small
  xs(4),

  /// 6px - Small
  s(6),

  /// 8px - Medium
  m(8),

  /// 12px - Large
  l(12),

  /// 16px - Extra large
  xl(16),

  /// 20px - Extra extra large
  xxl(20),

  /// 24px - Extra extra extra large
  xxxl(24),

  /// 32px - Huge
  xxxxl(32),

  /// 20px - Section spacing
  section(20),

  /// 12px - Card padding
  card(12),

  /// 120px - Avatar size (will be overridden in getValue)
  avatar(120),

  /// 24px - Status badge height
  statusBadge(24),

  /// 56px - Info item height
  infoItem(56),

  /// 56px - Menu item height
  menuItem(56),

  /// 40px - Splash screen spacing
  splash(40),

  /// 56px - Splash screen large spacing
  splashLarge(56);

  final double value;
  const AppSpacing(this.value);

  double getValue(BuildContext context) {
    // Special cases that use ResponsiveValues
    if (this == AppSpacing.avatar) {
      return ResponsiveValues.avatarSizeLarge(context);
    }
    if (this == AppSpacing.statusBadge) {
      return ResponsiveValues.statusBadgeHeight(context);
    }
    if (this == AppSpacing.infoItem) {
      return ResponsiveValues.infoSectionItemHeight(context);
    }
    if (this == AppSpacing.menuItem) {
      return ResponsiveValues.menuCardMinHeight(context);
    }

    // Scale for larger screens
    if (ScreenSize.isDesktop(context)) {
      return value * 1.1;
    }
    if (ScreenSize.isTablet(context)) {
      return value * 1.05;
    }
    return value;
  }
}

enum AppAnimation {
  fast(Duration(milliseconds: 150)),
  medium(Duration(milliseconds: 300)),
  slow(Duration(milliseconds: 500)),
  page(Duration(milliseconds: 350));

  final Duration duration;
  const AppAnimation(this.duration);
}

enum CardType {
  category,
  course,
  chapter,
  exam,
  payment,
  notification;
}
