import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'responsive.dart';
import 'app_enums.dart';

export 'app_enums.dart';

class ResponsiveValues {
  static double fontDisplayLarge(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 28,
      tablet: 30,
      desktop: 32,
      largeScreen: 34,
    );
  }

  static double fontDisplayMedium(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 24,
      tablet: 26,
      desktop: 28,
      largeScreen: 30,
    );
  }

  static double fontDisplaySmall(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 20,
      tablet: 22,
      desktop: 24,
      largeScreen: 26,
    );
  }

  static double fontHeadlineLarge(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 20,
      tablet: 21,
      desktop: 22,
      largeScreen: 23,
    );
  }

  static double fontHeadlineMedium(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 18,
      tablet: 19,
      desktop: 20,
      largeScreen: 21,
    );
  }

  static double fontHeadlineSmall(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 16,
      tablet: 17,
      desktop: 18,
      largeScreen: 19,
    );
  }

  static double fontTitleLarge(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 16,
      tablet: 16,
      desktop: 17,
      largeScreen: 18,
    );
  }

  static double fontTitleMedium(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 15,
      tablet: 15,
      desktop: 16,
      largeScreen: 17,
    );
  }

  static double fontTitleSmall(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 14,
      tablet: 14,
      desktop: 15,
      largeScreen: 16,
    );
  }

  static double fontBodyLarge(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 15,
      tablet: 15,
      desktop: 16,
      largeScreen: 17,
    );
  }

  static double fontBodyMedium(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 14,
      tablet: 14,
      desktop: 15,
      largeScreen: 16,
    );
  }

  static double fontBodySmall(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 12,
      tablet: 12,
      desktop: 13,
      largeScreen: 14,
    );
  }

  static double fontLabelLarge(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 14,
      tablet: 14,
      desktop: 15,
      largeScreen: 16,
    );
  }

  static double fontLabelMedium(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 12,
      tablet: 12,
      desktop: 13,
      largeScreen: 14,
    );
  }

  static double fontLabelSmall(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 10,
      tablet: 10,
      desktop: 11,
      largeScreen: 12,
    );
  }

  static double fontButtonLarge(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 15,
      tablet: 15,
      desktop: 16,
      largeScreen: 17,
    );
  }

  static double fontButtonMedium(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 14,
      tablet: 14,
      desktop: 15,
      largeScreen: 16,
    );
  }

  static double fontButtonSmall(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 12,
      tablet: 12,
      desktop: 13,
      largeScreen: 14,
    );
  }

  static double fontCaption(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 11,
      tablet: 11,
      desktop: 12,
      largeScreen: 13,
    );
  }

  static double fontOverline(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 9,
      tablet: 9,
      desktop: 10,
      largeScreen: 11,
    );
  }

  static double fontStatusBadge(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 10,
      tablet: 10,
      desktop: 11,
      largeScreen: 12,
    );
  }

  static double fontAppBarTitle(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 16,
      tablet: 17,
      desktop: 18,
      largeScreen: 19,
    );
  }

  static double fontBottomNavLabel(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 10,
      tablet: 10,
      desktop: 11,
      largeScreen: 12,
    );
  }

  static double iconSizeXXS(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 12;
    }
    return ScreenSize.iconSize(
      context: context,
      base: 14,
      tablet: 15,
      desktop: 16,
      largeScreen: 17,
    );
  }

  static double iconSizeXS(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 16;
    }
    return ScreenSize.iconSize(
      context: context,
      base: 18,
      tablet: 19,
      desktop: 20,
      largeScreen: 21,
    );
  }

  static double iconSizeS(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 18;
    }
    return ScreenSize.iconSize(
      context: context,
      base: 20,
      tablet: 21,
      desktop: 22,
      largeScreen: 23,
    );
  }

  static double iconSizeM(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 20;
    }
    return ScreenSize.iconSize(
      context: context,
      base: 22,
      tablet: 23,
      desktop: 24,
      largeScreen: 25,
    );
  }

  static double iconSizeL(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 22;
    }
    return ScreenSize.iconSize(
      context: context,
      base: 24,
      tablet: 25,
      desktop: 26,
      largeScreen: 27,
    );
  }

  static double iconSizeXL(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 24;
    }
    return ScreenSize.iconSize(
      context: context,
      base: 26,
      tablet: 27,
      desktop: 28,
      largeScreen: 29,
    );
  }

  static double iconSizeXXL(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 28;
    }
    return ScreenSize.iconSize(
      context: context,
      base: 32,
      tablet: 34,
      desktop: 36,
      largeScreen: 38,
    );
  }

  static double spacingXXS(BuildContext context) {
    return AppSpacing.xxs.getValue(context);
  }

  static double spacingXS(BuildContext context) {
    return AppSpacing.xs.getValue(context);
  }

  static double spacingS(BuildContext context) {
    return AppSpacing.s.getValue(context);
  }

  static double spacingM(BuildContext context) {
    return AppSpacing.m.getValue(context);
  }

  static double spacingL(BuildContext context) {
    return AppSpacing.l.getValue(context);
  }

  static double spacingXL(BuildContext context) {
    return AppSpacing.xl.getValue(context);
  }

  static double spacingXXL(BuildContext context) {
    return AppSpacing.xxl.getValue(context);
  }

  static double spacingXXXL(BuildContext context) {
    return AppSpacing.xxxl.getValue(context);
  }

  static double spacingXXXXL(BuildContext context) {
    return AppSpacing.xxxxl.getValue(context);
  }

  static EdgeInsets screenPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 24,
      );
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      );
    }
    return const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    );
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.all(20);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.all(16);
    }
    return const EdgeInsets.all(12);
  }

  static EdgeInsets dialogPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.all(28);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(20);
  }

  static EdgeInsets listItemPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
  }

  static EdgeInsets buttonPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
  }

  static double avatarSizeSmall(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 80.0;
    }
    if (ScreenSize.isTablet(context)) {
      return 100.0;
    }
    if (ScreenSize.isDesktop(context)) {
      return 120.0;
    }
    return 140.0;
  }

  static double avatarSizeMedium(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 100.0;
    }
    if (ScreenSize.isTablet(context)) {
      return 120.0;
    }
    if (ScreenSize.isDesktop(context)) {
      return 140.0;
    }
    return 160.0;
  }

  static double avatarSizeLarge(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 120.0;
    }
    if (ScreenSize.isTablet(context)) {
      return 140.0;
    }
    if (ScreenSize.isDesktop(context)) {
      return 160.0;
    }
    return 180.0;
  }

  static double menuCardMinHeight(BuildContext context) {
    return 56.0;
  }

  static double menuCardHeight(BuildContext context) {
    return 56.0;
  }

  static double menuIconSize(BuildContext context) {
    return iconSizeM(context);
  }

  static double menuIconContainerSize(BuildContext context) {
    return iconSizeXL(context);
  }

  static EdgeInsets menuCardPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: spacingL(context),
    );
  }

  static double menuCardBorderRadius(BuildContext context) {
    return radiusMedium(context);
  }

  static Color menuCardBorderColor(BuildContext context) {
    return AppColors.getDivider(context).withValues(alpha: 0.2);
  }

  static Color menuCardGradientStart(BuildContext context) {
    return AppColors.getCard(context).withValues(alpha: 0.4);
  }

  static Color menuCardGradientEnd(BuildContext context) {
    return AppColors.getCard(context).withValues(alpha: 0.2);
  }

  static double appBarButtonSize(BuildContext context) {
    return iconSizeXL(context) * 1.5;
  }

  static double appBarIconSize(BuildContext context) {
    return iconSizeM(context);
  }

  static double appBarButtonSpacing(BuildContext context) {
    if (isVerySmallScreen(context)) {
      return spacingXXS(context);
    }
    return spacingXS(context);
  }

  static bool isVerySmallScreen(BuildContext context) {
    return ScreenSize.getScreenWidth(context) < 360;
  }

  static double profileEditButtonSize(BuildContext context) {
    return appBarButtonSize(context);
  }

  static double profileEditIconSize(BuildContext context) {
    return appBarIconSize(context);
  }

  static Color profileEditButtonColor(BuildContext context) {
    return AppColors.telegramBlue.withValues(alpha: 0.15);
  }

  static double profileAvatarBorderWidth(BuildContext context) {
    return 2.0;
  }

  static Color profileAvatarBorderColor(BuildContext context) {
    return AppColors.telegramBlue.withValues(alpha: 0.3);
  }

  static double profileHeaderSpacing(BuildContext context) {
    return spacingM(context);
  }

  static double profileSectionSpacing(BuildContext context) {
    return spacingXL(context);
  }

  static double settingCardHeight(BuildContext context) {
    return 56.0;
  }

  static double settingIconSize(BuildContext context) {
    return iconSizeM(context);
  }

  static double settingIconContainerSize(BuildContext context) {
    return iconSizeXL(context);
  }

  static Color infoIconColor(BuildContext context) {
    return AppColors.telegramBlue;
  }

  static Color infoIconBackgroundColor(BuildContext context) {
    return AppColors.telegramBlue.withValues(alpha: 0.1);
  }

  static Color logoutDialogTextColor(BuildContext context) {
    return AppColors.getTextPrimary(context);
  }

  static Color logoutDialogBackgroundColor(BuildContext context) {
    return AppColors.getCard(context).withValues(alpha: 0.95);
  }

  static double logoutDialogIconSize(BuildContext context) {
    return iconSizeXXL(context);
  }

  static double logoutDialogButtonHeight(BuildContext context) {
    return buttonHeightMedium(context);
  }

  static double statusBadgeHeight(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return 24.0;
    }
    return 28.0;
  }

  static double statusBadgePadding(BuildContext context) {
    return spacingXS(context);
  }

  static double statusBadgeFontSize(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return fontLabelSmall(context);
    }
    return fontLabelMedium(context);
  }

  static double infoSectionItemHeight(BuildContext context) {
    return 56.0;
  }

  static double infoSectionVerticalPadding(BuildContext context) {
    return spacingXS(context);
  }

  static double infoSectionIconSize(BuildContext context) {
    return iconSizeM(context);
  }

  static double chatBubbleMaxWidth(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 600;
    }
    return double.infinity;
  }

  static double conversationCardMargin(BuildContext context) {
    return 2.0;
  }

  static double conversationCardIconSize(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return iconSizeXS(context);
    }
    return iconSizeM(context);
  }

  static double conversationCardTitleSize(BuildContext context) {
    if (ScreenSize.isMobile(context)) {
      return fontLabelSmall(context);
    }
    return fontBodySmall(context);
  }

  static double conversationCardSubtitleSize(BuildContext context) {
    return fontLabelSmall(context);
  }

  static double conversationCardPadding(BuildContext context) {
    return spacingS(context);
  }

  static double conversationCardRadius(BuildContext context) {
    return radiusSmall(context);
  }

  static double desktopSidebarWidth(BuildContext context) {
    return spacingXXXXL(context) * 8;
  }

  static double tabletSidebarWidth(BuildContext context) {
    return spacingXXXXL(context) * 5;
  }

  static double mobileDrawerWidth(BuildContext context) {
    return ScreenSize.getScreenWidth(context) * 0.7;
  }

  static double courseCardHeight(BuildContext context) {
    return ScreenSize.cardHeight(
      context: context,
      base: 180,
    );
  }

  static double courseCardIconSize(BuildContext context) {
    return iconSizeXL(context);
  }

  static double courseCardTitleSize(BuildContext context) {
    return fontTitleMedium(context);
  }

  static double courseCardDescSize(BuildContext context) {
    return fontBodyMedium(context);
  }

  static double courseCardBadgeSize(BuildContext context) {
    return fontBodySmall(context);
  }

  static double courseCardSpacing(BuildContext context) {
    return spacingM(context);
  }

  static double courseCardPadding(BuildContext context) {
    return spacingM(context);
  }

  static double courseCardVerticalPadding(BuildContext context) {
    return spacingM(context);
  }

  static double courseCardHorizontalPadding(BuildContext context) {
    return spacingL(context);
  }

  static double categoryCardHeight(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 180.0;
    }
    if (ScreenSize.isMobile(context)) {
      return 200.0;
    }
    return 220.0;
  }

  static double categoryCardTitleSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 14.0;
    }
    if (ScreenSize.isTablet(context)) {
      return fontTitleSmall(context);
    }
    return fontTitleSmall(context);
  }

  static double categoryCardPriceSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 11.0;
    }
    if (ScreenSize.isTablet(context)) {
      return fontLabelSmall(context);
    }
    return fontLabelSmall(context);
  }

  static double categoryCardBadgeTextSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 10.0;
    }
    if (ScreenSize.isTablet(context)) {
      return fontOverline(context);
    }
    return fontOverline(context);
  }

  static double categoryCardBadgeIconSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 9.0;
    }
    if (ScreenSize.isMobile(context)) {
      return 8.0;
    }
    return 9.0;
  }

  static double categoryCardBadgePadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 5.0;
    }
    if (ScreenSize.isMobile(context)) {
      return 4.0;
    }
    return 5.0;
  }

  static double chapterCardHeight(BuildContext context) {
    return ScreenSize.cardHeight(
      context: context,
      base: 100,
    );
  }

  static double examCardHeight(BuildContext context) {
    return ScreenSize.cardHeight(
      context: context,
      base: 140,
    );
  }

  static double sectionPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return 24;
    }
    if (ScreenSize.isTablet(context)) {
      return 20;
    }
    return 16;
  }

  static double statCircleSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 60,
      tablet: 65,
      desktop: 70,
      largeScreen: 75,
    );
  }

  static double chartHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 180,
      tablet: 200,
      desktop: 220,
      largeScreen: 240,
    );
  }

  static double progressBarHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 4,
      tablet: 5,
      desktop: 6,
      largeScreen: 7,
    );
  }

  static double splashSpacing(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 32,
      tablet: 36,
      desktop: 40,
      largeScreen: 44,
    );
  }

  static double splashLogoSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 100,
      tablet: 110,
      desktop: 120,
      largeScreen: 130,
    );
  }

  static double splashIconSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 48,
      tablet: 52,
      desktop: 56,
      largeScreen: 60,
    );
  }

  static double radiusSmall(BuildContext context) {
    return ScreenSize.borderRadius(
      context: context,
      base: 4,
      tablet: 5,
      desktop: 6,
      largeScreen: 7,
    );
  }

  static double radiusMedium(BuildContext context) {
    return ScreenSize.borderRadius(
      context: context,
      base: 8,
      tablet: 9,
      desktop: 10,
      largeScreen: 11,
    );
  }

  static double radiusLarge(BuildContext context) {
    return ScreenSize.borderRadius(
      context: context,
      base: 12,
      tablet: 13,
      desktop: 14,
      largeScreen: 15,
    );
  }

  static double radiusXLarge(BuildContext context) {
    return ScreenSize.borderRadius(
      context: context,
      base: 16,
      tablet: 17,
      desktop: 18,
      largeScreen: 19,
    );
  }

  static double radiusXXLarge(BuildContext context) {
    return ScreenSize.borderRadius(
      context: context,
      base: 20,
      tablet: 21,
      desktop: 22,
      largeScreen: 23,
    );
  }

  static double radiusFull(BuildContext context) {
    return 999.0;
  }

  static int gridColumns(BuildContext context) {
    return ScreenSize.gridColumns(
      context: context,
      mobile: 1,
      tablet: 2,
      desktop: 3,
      largeScreen: 4,
    );
  }

  static double gridSpacing(BuildContext context) {
    return spacingM(context);
  }

  static double gridRunSpacing(BuildContext context) {
    return spacingM(context);
  }

  static double buttonHeightSmall(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 32,
      tablet: 34,
      desktop: 36,
      largeScreen: 38,
    );
  }

  static double buttonHeightMedium(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 36,
      tablet: 38,
      desktop: 40,
      largeScreen: 42,
    );
  }

  static double buttonHeightLarge(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 42,
      tablet: 44,
      desktop: 46,
      largeScreen: 48,
    );
  }

  static double appBarHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 56,
      tablet: 58,
      desktop: 60,
      largeScreen: 62,
    );
  }

  static double bottomNavBarHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 56,
      tablet: 58,
      desktop: 60,
      largeScreen: 62,
    );
  }

  static double appBarGradientStartOpacity(BuildContext context) {
    return ScreenSize.isDarkMode(context) ? 0.35 : 0.25;
  }

  static double appBarGradientMidOpacity(BuildContext context) {
    return ScreenSize.isDarkMode(context) ? 0.25 : 0.18;
  }

  static double appBarGradientEndOpacity(BuildContext context) {
    return ScreenSize.isDarkMode(context) ? 0.15 : 0.1;
  }

  static const List<double> appBarGradientStops = [0.0, 0.4, 0.8, 1.0];
}
