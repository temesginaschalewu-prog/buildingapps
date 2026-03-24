import 'package:flutter/material.dart';
import 'responsive.dart';
import 'app_enums.dart';

export 'app_enums.dart';

class ResponsiveValues {
  static double fontDisplayLarge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 28, tablet: 30, desktop: 32, largeScreen: 34);
  }

  static double fontDisplayMedium(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 24, tablet: 26, desktop: 28, largeScreen: 30);
  }

  static double fontDisplaySmall(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 20, tablet: 22, desktop: 24, largeScreen: 26);
  }

  static double fontHeadlineLarge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 20, tablet: 21, desktop: 22, largeScreen: 23);
  }

  static double fontHeadlineMedium(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 18, tablet: 19, desktop: 20, largeScreen: 21);
  }

  static double fontHeadlineSmall(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 16, tablet: 17, desktop: 18, largeScreen: 19);
  }

  static double fontTitleLarge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 16, tablet: 16, desktop: 17, largeScreen: 18);
  }

  static double fontTitleMedium(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 15, tablet: 15, desktop: 16, largeScreen: 17);
  }

  static double fontTitleSmall(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 14, tablet: 14, desktop: 15, largeScreen: 16);
  }

  static double fontBodyLarge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 15, tablet: 15, desktop: 16, largeScreen: 17);
  }

  static double fontBodyMedium(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 14, tablet: 14, desktop: 15, largeScreen: 16);
  }

  static double fontBodySmall(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 12, tablet: 12, desktop: 13, largeScreen: 14);
  }

  static double fontLabelLarge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 14, tablet: 14, desktop: 15, largeScreen: 16);
  }

  static double fontLabelMedium(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 12, tablet: 12, desktop: 13, largeScreen: 14);
  }

  static double fontLabelSmall(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 10, tablet: 10, desktop: 11, largeScreen: 12);
  }

  static double fontButtonLarge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 15, tablet: 15, desktop: 16, largeScreen: 17);
  }

  static double fontButtonMedium(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 14, tablet: 14, desktop: 15, largeScreen: 16);
  }

  static double fontButtonSmall(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 12, tablet: 12, desktop: 13, largeScreen: 14);
  }

  static double fontCaption(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 11, tablet: 11, desktop: 12, largeScreen: 13);
  }

  static double fontOverline(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 9, tablet: 9, desktop: 10, largeScreen: 11);
  }

  static double fontStatusBadge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 10, tablet: 10, desktop: 11, largeScreen: 12);
  }

  static double fontAppBarTitle(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 16, tablet: 17, desktop: 18, largeScreen: 19);
  }

  static double fontBottomNavLabel(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 10, tablet: 10, desktop: 11, largeScreen: 12);
  }

  static double fontNotificationBadge(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 9, tablet: 9, desktop: 10, largeScreen: 11);
  }

  static double fontBadgeSmall(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 8, tablet: 8, desktop: 9, largeScreen: 10);
  }

  static double fontErrorIcon(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 36, tablet: 40, desktop: 44, largeScreen: 48);
  }

  static double fontCategoryInitials(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 32, tablet: 36, desktop: 40, largeScreen: 44);
  }

  static double fontCategoryTitle(BuildContext context) {
    return ScreenSize.fontSize(
        context: context, base: 24, tablet: 26, desktop: 28, largeScreen: 30);
  }

  static double iconSizeXXS(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 12
        : ScreenSize.iconSize(
            context: context,
            base: 14,
            tablet: 15,
            desktop: 16,
            largeScreen: 17);
  }

  static double iconSizeXS(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 16
        : ScreenSize.iconSize(
            context: context,
            base: 18,
            tablet: 19,
            desktop: 20,
            largeScreen: 21);
  }

  static double iconSizeS(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 18
        : ScreenSize.iconSize(
            context: context,
            base: 20,
            tablet: 21,
            desktop: 22,
            largeScreen: 23);
  }

  static double iconSizeM(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 20
        : ScreenSize.iconSize(
            context: context,
            base: 22,
            tablet: 23,
            desktop: 24,
            largeScreen: 25);
  }

  static double iconSizeL(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 22
        : ScreenSize.iconSize(
            context: context,
            base: 24,
            tablet: 25,
            desktop: 26,
            largeScreen: 27);
  }

  static double iconSizeXL(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 24
        : ScreenSize.iconSize(
            context: context,
            base: 26,
            tablet: 27,
            desktop: 28,
            largeScreen: 29);
  }

  static double iconSizeXXL(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 28
        : ScreenSize.iconSize(
            context: context,
            base: 32,
            tablet: 34,
            desktop: 36,
            largeScreen: 38);
  }

  static double iconSizeXXXL(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 32
        : ScreenSize.iconSize(
            context: context,
            base: 36,
            tablet: 40,
            desktop: 44,
            largeScreen: 48);
  }

  static double iconSizeXXXXL(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? 40
        : ScreenSize.iconSize(
            context: context,
            base: 48,
            tablet: 52,
            desktop: 56,
            largeScreen: 60);
  }

  static double spacingXXS(BuildContext context) =>
      AppSpacing.xxs.getValue(context);
  static double spacingXS(BuildContext context) =>
      AppSpacing.xs.getValue(context);
  static double spacingS(BuildContext context) =>
      AppSpacing.s.getValue(context);
  static double spacingM(BuildContext context) =>
      AppSpacing.m.getValue(context);
  static double spacingL(BuildContext context) =>
      AppSpacing.l.getValue(context);
  static double spacingXL(BuildContext context) =>
      AppSpacing.xl.getValue(context);
  static double spacingXXL(BuildContext context) =>
      AppSpacing.xxl.getValue(context);
  static double spacingXXXL(BuildContext context) =>
      AppSpacing.xxxl.getValue(context);
  static double spacingXXXXL(BuildContext context) =>
      AppSpacing.xxxxl.getValue(context);

  static double sectionPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 24;
    if (ScreenSize.isTablet(context)) return 20;
    return 16;
  }

  static double splashLogoSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context,
        mobile: 100,
        tablet: 110,
        desktop: 120,
        largeScreen: 130);
  }

  static double splashIconSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 48, tablet: 52, desktop: 56, largeScreen: 60);
  }

  static double spacingSplash(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 32, tablet: 36, desktop: 40, largeScreen: 44);
  }

  static EdgeInsets screenPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }

  static EdgeInsets cardPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return const EdgeInsets.all(20);
    if (ScreenSize.isTablet(context)) return const EdgeInsets.all(16);
    return const EdgeInsets.all(12);
  }

  static EdgeInsets dialogPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return const EdgeInsets.all(28);
    if (ScreenSize.isTablet(context)) return const EdgeInsets.all(24);
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
    if (ScreenSize.isMobile(context)) return 80;
    if (ScreenSize.isTablet(context)) return 100;
    return 120;
  }

  static double avatarSizeMedium(BuildContext context) {
    if (ScreenSize.isMobile(context)) return 100;
    if (ScreenSize.isTablet(context)) return 120;
    return 140;
  }

  static double avatarSizeLarge(BuildContext context) {
    if (ScreenSize.isMobile(context)) return 120;
    if (ScreenSize.isTablet(context)) return 140;
    return 160;
  }

  static double radiusSmall(BuildContext context) {
    return ScreenSize.borderRadius(
        context: context, base: 4, tablet: 5, desktop: 6, largeScreen: 7);
  }

  static double radiusMedium(BuildContext context) {
    return ScreenSize.borderRadius(
        context: context, base: 8, tablet: 9, desktop: 10, largeScreen: 11);
  }

  static double radiusLarge(BuildContext context) {
    return ScreenSize.borderRadius(
        context: context, base: 12, tablet: 13, desktop: 14, largeScreen: 15);
  }

  static double radiusXLarge(BuildContext context) {
    return ScreenSize.borderRadius(
        context: context, base: 16, tablet: 17, desktop: 18, largeScreen: 19);
  }

  static double radiusXXLarge(BuildContext context) {
    return ScreenSize.borderRadius(
        context: context, base: 20, tablet: 21, desktop: 22, largeScreen: 23);
  }

  static double radiusFull(BuildContext context) => 999;

  static int gridColumns(BuildContext context) {
    return ScreenSize.gridColumns(
        context: context, mobile: 1, tablet: 2, desktop: 3, largeScreen: 4);
  }

  static double gridSpacing(BuildContext context) => spacingM(context);
  static double gridRunSpacing(BuildContext context) => spacingM(context);

  static EdgeInsets onboardingHeaderPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.fromLTRB(24, 24, 24, 12);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.fromLTRB(20, 20, 20, 12);
    }
    return const EdgeInsets.fromLTRB(16, 16, 16, 8);
  }

  static EdgeInsets onboardingFooterPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return const EdgeInsets.all(24);
    if (ScreenSize.isTablet(context)) return const EdgeInsets.all(20);
    return const EdgeInsets.all(16);
  }

  static double onboardingListSpacing(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 16;
    if (ScreenSize.isTablet(context)) return 14;
    return 12;
  }

  static double schoolSelectionIconContainerSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 40;
    if (ScreenSize.isTablet(context)) return 38;
    return 34;
  }

  static double schoolSelectionTitleFont(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 15,
      tablet: 16,
      desktop: 17,
      largeScreen: 18,
    );
  }

  static double supportActionIconContainerSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 40;
    if (ScreenSize.isTablet(context)) return 38;
    return 34;
  }

  static double featureCardIconContainerSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 42;
    if (ScreenSize.isTablet(context)) return 39;
    return 36;
  }

  static EdgeInsets sectionLoadingPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return const EdgeInsets.all(24);
    if (ScreenSize.isTablet(context)) return const EdgeInsets.all(20);
    return const EdgeInsets.all(16);
  }

  static double successStateOuterSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 204,
      tablet: 238,
      desktop: 272,
      largeScreen: 288,
    );
  }

  static double sidebarBrandIconContainerSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 36,
      tablet: 39,
      desktop: 42,
      largeScreen: 44,
    );
  }

  static double sidebarAvatarSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 56,
      tablet: 60,
      desktop: 64,
      largeScreen: 68,
    );
  }

  static double sidebarAvatarInitialsFontSize(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 15,
      tablet: 16,
      desktop: 17,
      largeScreen: 18,
    );
  }

  static double profileAvatarActionSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 28,
      tablet: 30,
      desktop: 32,
      largeScreen: 34,
    );
  }

  static double listItemIconContainerSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 40,
      tablet: 42,
      desktop: 44,
      largeScreen: 46,
    );
  }

  static double listItemIconSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 20,
      tablet: 21,
      desktop: 22,
      largeScreen: 24,
    );
  }

  static EdgeInsets modalInsetPaddingSmall(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return const EdgeInsets.all(16);
    if (ScreenSize.isTablet(context)) return const EdgeInsets.all(12);
    return const EdgeInsets.all(8);
  }

  static double modalHandleWidth(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 40,
      tablet: 44,
      desktop: 48,
      largeScreen: 52,
    );
  }

  static double modalHandleHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 4,
      tablet: 4,
      desktop: 5,
      largeScreen: 5,
    );
  }

  static EdgeInsets modalHeaderPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return const EdgeInsets.all(20);
    if (ScreenSize.isTablet(context)) return const EdgeInsets.all(18);
    return const EdgeInsets.all(16);
  }

  static EdgeInsets mediaOverlayChipPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 14, vertical: 7);
    }
    if (ScreenSize.isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 13, vertical: 6);
    }
    return const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
  }

  static double mediaOverlayChipTextSize(BuildContext context) {
    return ScreenSize.fontSize(
      context: context,
      base: 12,
      tablet: 12,
      desktop: 13,
      largeScreen: 14,
    );
  }

  static double selectionSheetLeadingSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
      context: context,
      mobile: 48,
      tablet: 50,
      desktop: 52,
      largeScreen: 56,
    );
  }

  static double homeGridHorizontalPadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 16;
    if (ScreenSize.isTablet(context)) return 14;
    return 12;
  }

  static double homeCategoryGridAspectRatio(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 0.74;
    if (ScreenSize.isTablet(context)) return 0.73;
    return 0.92;
  }

  static double buttonHeightSmall(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 32, tablet: 34, desktop: 36, largeScreen: 38);
  }

  static double buttonHeightMedium(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 36, tablet: 38, desktop: 40, largeScreen: 42);
  }

  static double buttonHeightLarge(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 42, tablet: 44, desktop: 46, largeScreen: 48);
  }

  static double appBarHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 56, tablet: 58, desktop: 60, largeScreen: 62);
  }

  static double bottomNavBarHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 56, tablet: 58, desktop: 60, largeScreen: 62);
  }

  static double progressBarHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 4, tablet: 5, desktop: 6, largeScreen: 7);
  }

  static double statCircleSize(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 60, tablet: 65, desktop: 70, largeScreen: 75);
  }

  static double categoryCardHeight(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 198;
    if (ScreenSize.isMobile(context)) return 186;
    return 204;
  }

  static double categoryCardTitleSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 14;
    if (ScreenSize.isMobile(context)) return 13;
    return fontTitleSmall(context);
  }

  static double categoryCardPriceSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 11;
    return fontLabelSmall(context);
  }

  static double categoryCardBadgeTextSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 10;
    if (ScreenSize.isMobile(context)) return 8.5;
    return fontOverline(context);
  }

  static double categoryCardBadgeIconSize(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 9;
    if (ScreenSize.isMobile(context)) return 7.5;
    return 9;
  }

  static double categoryCardBadgePadding(BuildContext context) {
    if (ScreenSize.isDesktop(context)) return 5;
    if (ScreenSize.isMobile(context)) return 3.5;
    return 5;
  }

  static double desktopSidebarWidth(BuildContext context) =>
      spacingXXXXL(context) * 8;
  static double tabletSidebarWidth(BuildContext context) =>
      spacingXXXXL(context) * 7.5;
  static double mobileDrawerWidth(BuildContext context) =>
      ScreenSize.getScreenWidth(context) * 0.7;

  static double chatBubbleMaxWidth(BuildContext context) {
    return ScreenSize.isDesktop(context) ? 600 : double.infinity;
  }

  static double conversationCardMargin(BuildContext context) => 2;
  static double conversationCardIconSize(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? iconSizeXS(context)
        : iconSizeM(context);
  }

  static double conversationCardTitleSize(BuildContext context) {
    return ScreenSize.isMobile(context)
        ? fontLabelSmall(context)
        : fontBodySmall(context);
  }

  static double conversationCardSubtitleSize(BuildContext context) =>
      fontLabelSmall(context);
  static double conversationCardPadding(BuildContext context) =>
      spacingS(context);
  static double conversationCardRadius(BuildContext context) =>
      radiusSmall(context);

  static double appBarButtonSize(BuildContext context) =>
      iconSizeXL(context) * 1.5;
  static double appBarIconSize(BuildContext context) =>
      iconSizeM(context) * 1.3;
  static double appBarButtonSpacing(BuildContext context) {
    return isVerySmallScreen(context)
        ? spacingXXS(context)
        : spacingXS(context);
  }

  static bool isVerySmallScreen(BuildContext context) =>
      ScreenSize.getScreenWidth(context) < 360;

  static double statusBadgeHeight(BuildContext context) {
    return ScreenSize.responsiveDouble(
        context: context, mobile: 24, tablet: 26, desktop: 28, largeScreen: 30);
  }

  static double infoSectionItemHeight(BuildContext context) => 56;
  static double menuCardMinHeight(BuildContext context) => 56;
}
