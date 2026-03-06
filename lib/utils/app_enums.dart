import 'package:flutter/material.dart';
import 'responsive.dart';
import 'responsive_values.dart';

enum AppSpacing {
  none(0),

  xxs(2),

  xs(4),

  s(6),

  m(8),

  l(12),

  xl(16),

  xxl(20),

  xxxl(24),

  xxxxl(32),

  section(20),

  card(12),

  avatar(120),

  statusBadge(24),

  infoItem(56),

  menuItem(56),

  splash(40),

  splashLarge(56);

  final double value;
  const AppSpacing(this.value);

  double getValue(BuildContext context) {
    if (this == AppSpacing.avatar)
      return ResponsiveValues.avatarSizeLarge(context);

    if (ScreenSize.isDesktop(context)) return value * 1.1;
    if (ScreenSize.isTablet(context)) return value * 1.05;
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
  notification,
}

enum ButtonVariant {
  primary,
  secondary,
  success,
  danger,
  outline,
  text,
  icon,
}

enum ButtonSize {
  small,
  medium,
  large,
}

enum TextFieldVariant {
  glass,
  filled,
  outline,
}

enum CardVariant {
  glass,
  solid,
  outline,
  elevated,
  flat,
}

enum CardSize {
  small,
  medium,
  large,
  compact,
}

enum DialogVariant {
  info,
  success,
  warning,
  error,
  confirm,
  input,
}

enum EmptyStateType {
  general,
  error,
  noInternet,
  noResults,
  noData,
  success,
  offline,
}

enum ShimmerType {
  categoryCard,
  courseCard,
  chapterCard,
  examCard,
  videoCard,
  noteCard,
  notificationCard,
  schoolCard,
  paymentCard,
  subscriptionCard,
  contactCard,
  statusCard,
  pairingCard,
  textLine,
  circle,
  rectangle,
  statCircle,
}

enum VideoQualityLevel {
  low(360, '360p'),
  medium(480, '480p'),
  high(720, '720p'),
  highest(1080, '1080p');

  final int height;
  final String label;
  const VideoQualityLevel(this.height, this.label);
}

enum ContactType {
  phone,
  email,
  whatsapp,
  telegram,
  address,
  hours,
  website,
  social,
  other,
}

enum SnackbarType {
  success,
  error,
  warning,
  info,
  offline,
}
