import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    if (fullScreen) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: _buildContent(context),
        ),
      );
    }

    return Center(
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showAnimation) _buildLoader(context),
        if (message != null) ...[
          const SizedBox(height: AppThemes.spacingL),
          _buildMessage(context),
        ],
      ],
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
    final effectiveSize = size ??
        (ScreenSize.isDesktop(context)
            ? 48.0
            : ScreenSize.isTablet(context)
                ? 40.0
                : 32.0);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12.0,
            offset: const Offset(0, 4),
          ),
        ],
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
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .rotate(
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
        );
  }

  Widget _buildLinearLoader(BuildContext context) {
    return Container(
      width: size ?? 200,
      height: 4,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  colors: [
                    color ?? AppColors.telegramBlue,
                    color?.withOpacity(0.7) ??
                        AppColors.telegramBlue.withOpacity(0.7),
                  ],
                ),
              ),
            ).animate(onPlay: (controller) => controller.repeat()).slideX(
                  begin: -1,
                  end: 1,
                  duration: const Duration(seconds: 1),
                  curve: Curves.easeInOut,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLottieLoader(BuildContext context) {
    final effectiveSize = size ??
        (ScreenSize.isDesktop(context)
            ? 120.0
            : ScreenSize.isTablet(context)
                ? 100.0
                : 80.0);

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
    final effectiveSize = size ??
        (ScreenSize.isDesktop(context)
            ? 120.0
            : ScreenSize.isTablet(context)
                ? 100.0
                : 80.0);

    return Shimmer.fromColors(
      baseColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2C2C2E)
          : const Color(0xFFE5E5EA),
      highlightColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3C3C3E)
          : const Color(0xFFF2F2F7),
      period: const Duration(seconds: 1),
      child: Container(
        width: effectiveSize,
        height: effectiveSize,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildPulseLoader(BuildContext context) {
    final effectiveSize = size ??
        (ScreenSize.isDesktop(context)
            ? 48.0
            : ScreenSize.isTablet(context)
                ? 40.0
                : 32.0);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        color: color ?? AppColors.telegramBlue,
        shape: BoxShape.circle,
      ),
    ).animate(onPlay: (controller) => controller.repeat()).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.2, 1.2),
          duration: const Duration(seconds: 1),
          curve: Curves.easeInOut,
        );
  }

  Widget _buildTelegramLoader(BuildContext context) {
    final effectiveSize = size ??
        (ScreenSize.isDesktop(context)
            ? 56.0
            : ScreenSize.isTablet(context)
                ? 48.0
                : 40.0);

    return Container(
      width: effectiveSize,
      height: effectiveSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.blueGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.telegramBlue.withOpacity(0.3),
            blurRadius: 16.0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.telegram,
          color: Colors.white,
          size: 24,
        ),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.1, 1.1),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
  }

  Widget _buildMessage(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingXL,
          tablet: AppThemes.spacingXXL,
          desktop: AppThemes.spacingXXXL,
        ),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.getTextSecondary(context),
              fontSize: ScreenSize.responsiveFontSize(
                context: context,
                mobile: 14,
                tablet: 15,
                desktop: 16,
              ),
            ),
        child: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              message!,
              speed: const Duration(milliseconds: 50),
            ),
          ],
          totalRepeatCount: 1,
          displayFullTextOnTap: true,
          stopPauseOnTap: true,
        ),
      ),
    );
  }
}

enum LoadingType {
  circular,
  linear,
  lottie,
  shimmer,
  pulse,
  telegram,
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
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA)),
      highlightColor: highlightColor ??
          (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF3C3C3E)
              : const Color(0xFFF2F2F7)),
      period: const Duration(seconds: 2),
      direction: ShimmerDirection.ltr,
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: isCircle
            ? const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              )
            : BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
        child: child,
      ),
    );
  }
}

class SkeletonLoader extends StatelessWidget {
  final bool isList;
  final int itemCount;
  final EdgeInsetsGeometry padding;
  final SkeletonType type;

  const SkeletonLoader({
    super.key,
    this.isList = false,
    this.itemCount = 3,
    this.padding = const EdgeInsets.all(AppThemes.spacingL),
    this.type = SkeletonType.card,
  });

  @override
  Widget build(BuildContext context) {
    if (isList) {
      return ListView.builder(
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppThemes.spacingL),
            child: _buildListSkeleton(context),
          );
        },
      );
    }

    return Padding(
      padding: padding,
      child: _buildGridSkeleton(context),
    );
  }

  Widget _buildListSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppThemes.spacingL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(
            width: 80,
            height: 80,
            borderRadius: AppThemes.borderRadiusMedium,
            isCircle: false,
          ),
          const SizedBox(width: AppThemes.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(
                  width: double.infinity,
                  height: 20,
                  borderRadius: AppThemes.borderRadiusSmall,
                  margin: const EdgeInsets.only(bottom: AppThemes.spacingS),
                ),
                ShimmerLoading(
                  width: double.infinity,
                  height: 16,
                  borderRadius: AppThemes.borderRadiusSmall,
                  margin: const EdgeInsets.only(bottom: AppThemes.spacingS),
                ),
                ShimmerLoading(
                  width: 100,
                  height: 16,
                  borderRadius: AppThemes.borderRadiusSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSkeleton(BuildContext context) {
    final columns = ScreenSize.isDesktop(context)
        ? 3
        : ScreenSize.isTablet(context)
            ? 2
            : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppThemes.spacingL,
        mainAxisSpacing: AppThemes.spacingL,
        childAspectRatio: 0.8,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildCardSkeleton(context);
      },
    );
  }

  Widget _buildCardSkeleton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(
            width: double.infinity,
            height: 120,
            borderRadius: AppThemes.borderRadiusMedium,
            margin: const EdgeInsets.all(AppThemes.spacingL),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppThemes.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(
                  width: double.infinity,
                  height: 20,
                  borderRadius: AppThemes.borderRadiusSmall,
                  margin: const EdgeInsets.only(bottom: AppThemes.spacingS),
                ),
                ShimmerLoading(
                  width: 120,
                  height: 16,
                  borderRadius: AppThemes.borderRadiusSmall,
                  margin: const EdgeInsets.only(bottom: AppThemes.spacingM),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(
                      width: 60,
                      height: 16,
                      borderRadius: AppThemes.borderRadiusSmall,
                    ),
                    ShimmerLoading(
                      width: 40,
                      height: 16,
                      borderRadius: AppThemes.borderRadiusSmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppThemes.spacingL),
        ],
      ),
    );
  }
}

enum SkeletonType { card, list, grid }

class ProgressiveImage extends StatelessWidget {
  final String imageUrl;
  final String? placeholderAsset;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool showLoading;
  final Duration fadeInDuration;
  final Curve fadeInCurve;

  const ProgressiveImage({
    super.key,
    required this.imageUrl,
    this.placeholderAsset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = AppThemes.borderRadiusMedium,
    this.placeholder,
    this.errorWidget,
    this.showLoading = true,
    this.fadeInDuration = AppThemes.animationDurationMedium,
    this.fadeInCurve = Curves.easeIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2E)
            : const Color(0xFFE5E5EA),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          imageUrl,
          width: width,
          height: height,
          fit: fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child.animate().fadeIn(
                    duration: fadeInDuration,
                    curve: fadeInCurve,
                  );
            }

            return showLoading
                ? Center(
                    child: LoadingIndicator(
                      type: LoadingType.telegram,
                      size: 32,
                    ),
                  )
                : placeholder ??
                    Container(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFE5E5EA),
                    );
          },
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ??
                Container(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFE5E5EA),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.getTextSecondary(context),
                      size: 40.0,
                    ),
                  ),
                );
          },
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? overlayColor;
  final double opacity;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.overlayColor,
    this.opacity = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: (overlayColor ?? Colors.black).withOpacity(opacity),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoadingIndicator(
                      type: LoadingType.telegram,
                      size: 56,
                      color: Colors.white,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: AppThemes.spacingL),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppThemes.spacingXL,
                        ),
                        child: Text(
                          message!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class StaggeredLoadingList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Duration interval;
  final EdgeInsetsGeometry padding;

  const StaggeredLoadingList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.interval = const Duration(milliseconds: 100),
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return itemBuilder(context, index)
            .animate(
              delay: interval * index,
            )
            .fadeIn(duration: const Duration(milliseconds: 300))
            .slideY(
              begin: 0.1,
              end: 0,
              duration: const Duration(milliseconds: 300),
            );
      },
    );
  }
}

// Telegram-like animated text input loader
class TypingIndicator extends StatelessWidget {
  final Color? color;
  final double size;

  const TypingIndicator({
    super.key,
    this.color,
    this.size = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          width: size / 3,
          height: size / 3,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color ?? AppColors.telegramGray,
            shape: BoxShape.circle,
          ),
        )
            .animate(
              delay: Duration(milliseconds: 200 * index),
              onPlay: (controller) => controller.repeat(),
            )
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
      }),
    );
  }
}

// Telegram-style refresh indicator
class TelegramRefreshIndicator extends StatelessWidget {
  final Widget child;
  final RefreshCallback onRefresh;
  final Color? color;

  const TelegramRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      backgroundColor: AppColors.getCard(context),
      color: color ?? AppColors.telegramBlue,
      strokeWidth: 2.5,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
