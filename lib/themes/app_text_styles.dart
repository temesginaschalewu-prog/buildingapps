import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:flutter/material.dart';
import '../utils/responsive_values.dart';

class AppTextStyles {
  static TextStyle displayLarge(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontDisplayLarge(context),
        fontWeight: FontWeight.w800,
        height: 1.2,
        letterSpacing: -0.5,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle displayMedium(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontDisplayMedium(context),
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.25,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle displaySmall(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontDisplaySmall(context),
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle headlineLarge(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontHeadlineLarge(context),
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle headlineMedium(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontHeadlineMedium(context),
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle headlineSmall(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontHeadlineSmall(context),
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle titleLarge(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontTitleLarge(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle titleMedium(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontTitleMedium(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle titleSmall(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontTitleSmall(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle bodyLarge(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontBodyLarge(context),
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle bodyMedium(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontBodyMedium(context),
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle bodySmall(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontBodySmall(context),
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.getTextSecondary(context),
      );

  static TextStyle labelLarge(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontLabelLarge(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle labelMedium(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontLabelMedium(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.1,
        color: AppColors.getTextSecondary(context),
      );

  static TextStyle labelSmall(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontLabelSmall(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.2,
        color: AppColors.getTextTertiary(context),
      );

  static TextStyle buttonLarge(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontButtonLarge(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle buttonMedium(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontButtonMedium(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle buttonSmall(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontButtonSmall(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontCaption(context),
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.getTextSecondary(context),
      );

  static TextStyle overline(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontOverline(context),
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 1.5,
        color: AppColors.getTextSecondary(context),
      );

  static TextStyle statusBadge(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontStatusBadge(context),
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.3,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle appBarTitle(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontAppBarTitle(context),
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle bottomNavLabel(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontBottomNavLabel(context),
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: AppColors.getTextSecondary(context),
      );

  static TextStyle chatMessage(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontBodyLarge(context),
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.getTextPrimary(context),
      );

  static TextStyle chatTime(BuildContext context) => TextStyle(
        fontSize: ResponsiveValues.fontCaption(context),
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.getTextSecondary(context),
      );
}
