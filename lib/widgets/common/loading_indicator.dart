import 'dart:ui';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/utils/app_enums.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'responsive_widgets.dart';

enum LoadingType {
  circular,
  linear,
  lottie,
  shimmer,
  pulse,
  telegram,
}

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final bool fullScreen;
  final Color? color;
  final double? size;
  final LoadingType type;
  final bool showAnimation;
  final String? customAnimationAsset;

  const LoadingIndicator({
    super.key,
    this.message,
    this.fullScreen = false,
    this.color,
    this.size,
    this.type = LoadingType.circular,
    this.showAnimation = true,
    this.customAnimationAsset,
  });

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (fullScreen) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(child: _buildContent(context)),
      );
    }
    return Center(child: _buildContent(context));
  }

  Widget _buildContent(BuildContext context) {
    return _buildGlassContainer(
      context,
      child: Padding(
        padding: EdgeInsets.all(ResponsiveValues.spacingXL(context)),
        child: ResponsiveColumn(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showAnimation) _buildLoader(context),
            if (message != null) ...[
              ResponsiveSizedBox(height: AppSpacing.l),
              _buildMessage(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoader(BuildContext context) {
    switch (type) {
      case LoadingType.circular:
        return _buildCircularLoader(context);
      case LoadingType.linear:
        return _buildLinearLoader(context);
      case LoadingType.lottie:
        return _buildLottieLoader(context);
      case LoadingType.shimmer:
        return _buildShimmerLoader(context);
      case LoadingType.pulse:
        return _buildPulseLoader(context);
      case LoadingType.telegram:
        return _buildTelegramLoader(context);
    }
  }

  Widget _buildCircularLoader(BuildContext context) {
    final effectiveSize = size ?? ResponsiveValues.iconSizeXXL(context);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (color ?? AppColors.telegramBlue).withValues(alpha: 0.2),
            (color ?? AppColors.telegramBlue).withValues(alpha: 0.05),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SizedBox(
          width: effectiveSize * 0.6,
          height: effectiveSize * 0.6,
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppColors.telegramBlue,
            ),
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .rotate(duration: const Duration(seconds: 1), curve: Curves.linear);
  }

  Widget _buildLinearLoader(BuildContext context) {
    final effectiveWidth = size ?? ResponsiveValues.spacingXXXL(context) * 6;

    return Container(
      width: effectiveWidth,
      height: ResponsiveValues.progressBarHeight(context),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusSmall(context)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context)),
                gradient: LinearGradient(
                  colors: [
                    color ?? AppColors.telegramBlue,
                    (color ?? AppColors.telegramBlue).withValues(alpha: 0.7),
                  ],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat()).slideX(
                begin: -1,
                end: 1,
                duration: const Duration(seconds: 1),
                curve: Curves.easeInOut),
          ),
        ],
      ),
    );
  }

  Widget _buildLottieLoader(BuildContext context) {
    final effectiveSize = size ?? ResponsiveValues.iconSizeXXL(context) * 2;

    return SizedBox(
      width: effectiveSize,
      height: effectiveSize,
      child: Lottie.asset(
        customAnimationAsset ?? 'assets/lottie/loading.json',
        width: effectiveSize,
        height: effectiveSize,
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
      ),
    );
  }

  Widget _buildShimmerLoader(BuildContext context) {
    final effectiveSize = size ?? ResponsiveValues.iconSizeXXL(context) * 2;

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (color ?? AppColors.telegramBlue).withValues(alpha: 0.2),
            (color ?? AppColors.telegramBlue).withValues(alpha: 0.05),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: effectiveSize * 0.8,
          height: effectiveSize * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildPulseLoader(BuildContext context) {
    final effectiveSize = size ?? ResponsiveValues.iconSizeXXL(context);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (color ?? AppColors.telegramBlue).withValues(alpha: 0.2),
            (color ?? AppColors.telegramBlue).withValues(alpha: 0.05),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: effectiveSize * 0.6,
        height: effectiveSize * 0.6,
        decoration: BoxDecoration(
          color: color ?? AppColors.telegramBlue,
          shape: BoxShape.circle,
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.2, 1.2),
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOut);
  }

  Widget _buildTelegramLoader(BuildContext context) {
    final effectiveSize = size ?? ResponsiveValues.iconSizeXXL(context) * 1.5;

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.blueGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.telegramBlue.withValues(alpha: 0.3),
            blurRadius: ResponsiveValues.spacingL(context),
            offset: Offset(0, ResponsiveValues.spacingS(context)),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.telegram, color: Colors.white, size: 32),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).scale(
        begin: const Offset(1.0, 1.0),
        end: const Offset(1.1, 1.1),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut);
  }

  Widget _buildMessage(BuildContext context) {
    return ResponsiveText(
      message!,
      style: AppTextStyles.bodyMedium(context).copyWith(
        color: AppColors.getTextSecondary(context),
        fontSize: ResponsiveValues.fontBodyLarge(context),
      ),
      textAlign: TextAlign.center,
    );
  }
}

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;
  final Widget? child;
  final bool isCircle;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = AppThemes.borderRadiusMedium,
    this.margin,
    this.child,
    this.isCircle = false,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ??
          (Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : AppColors.lightSurface),
      highlightColor: highlightColor ??
          (Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkCard
              : AppColors.lightCard),
      period: const Duration(seconds: 2),
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: isCircle
            ? const BoxDecoration(shape: BoxShape.circle, color: Colors.white)
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  borderRadius,
                ),
              ),
        child: child,
      ),
    );
  }
}
