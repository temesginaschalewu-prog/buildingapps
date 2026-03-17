import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/responsive_values.dart';

class AppShimmer extends StatelessWidget {
  final ShimmerType type;
  final double? customWidth;
  final double? customHeight;
  final int index;
  final Color? baseColor;
  final Color? highlightColor;
  final bool isOffline;

  const AppShimmer({
    super.key,
    required this.type,
    this.customWidth,
    this.customHeight,
    this.index = 0,
    this.baseColor,
    this.highlightColor,
    this.isOffline = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBaseColor = baseColor ??
        (isDark
                ? (isOffline ? Colors.grey[700]! : Colors.grey[800]!)
                : (isOffline ? Colors.grey[200]! : Colors.grey[300]!))
            .withValues(alpha: isOffline ? 0.2 : 0.3);

    final effectiveHighlightColor = highlightColor ??
        (isDark
                ? (isOffline ? Colors.grey[600]! : Colors.grey[700]!)
                : (isOffline ? Colors.grey[100]! : Colors.grey[100]!))
            .withValues(alpha: isOffline ? 0.4 : 0.6);

    return Animate(
      effects: [FadeEffect(duration: 400.ms, delay: (index * 50).ms)],
      child: Shimmer.fromColors(
        baseColor: effectiveBaseColor,
        highlightColor: effectiveHighlightColor,
        child: _buildShimmerChild(context),
      ),
    );
  }

  Widget _buildShimmerChild(BuildContext context) {
    switch (type) {
      case ShimmerType.categoryCard:
        return _CategoryCardShimmer(context);
      case ShimmerType.courseCard:
        return _CourseCardShimmer(context);
      case ShimmerType.chapterCard:
        return _ChapterCardShimmer(context);
      case ShimmerType.examCard:
        return _ExamCardShimmer(context);
      case ShimmerType.videoCard:
        return _VideoCardShimmer(context);
      case ShimmerType.noteCard:
        return _NoteCardShimmer(context);
      case ShimmerType.notificationCard:
        return _NotificationCardShimmer(context);
      case ShimmerType.schoolCard:
        return _SchoolCardShimmer(context);
      case ShimmerType.paymentCard:
        return _PaymentCardShimmer(context);
      case ShimmerType.subscriptionCard:
        return _SubscriptionCardShimmer(context);
      case ShimmerType.contactCard:
        return _ContactCardShimmer(context);
      case ShimmerType.statusCard:
        return _StatusCardShimmer(context);
      case ShimmerType.pairingCard:
        return _PairingCardShimmer(context);
      case ShimmerType.textLine:
        return _TextLineShimmer(context);
      case ShimmerType.circle:
        return _CircleShimmer(context);
      case ShimmerType.rectangle:
        return _RectangleShimmer(context);
      case ShimmerType.statCircle:
        return _StatCircleShimmer(context);
    }
  }

  Widget _CategoryCardShimmer(BuildContext context) {
    final cardHeight = ResponsiveValues.categoryCardHeight(context);
    final spacing = ResponsiveValues.spacingM(context);
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final titleSize = ResponsiveValues.categoryCardTitleSize(context);
    final badgeTextSize = ResponsiveValues.categoryCardBadgeTextSize(context);

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      ),
      child: Stack(
        children: [
          // Background image placeholder
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
              ),
            ),
          ),
          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
              ),
            ),
          ),
          // Title badge
          Positioned(
            top: spacing,
            left: spacing,
            child: Container(
              width: isDesktop ? 80 : 100,
              height: titleSize + 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context)),
              ),
            ),
          ),
          // Status badge
          Positioned(
            top: spacing,
            right: spacing,
            child: Container(
              width: isDesktop ? 60 : 70,
              height: isDesktop ? 18 : 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context)),
              ),
            ),
          ),
          // Price badge (if applicable)
          Positioned(
            bottom: spacing,
            left: spacing,
            child: Container(
              width: isDesktop ? 50 : 60,
              height: badgeTextSize + 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusSmall(context)),
              ),
            ),
          ),
          // Border overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
                borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusXLarge(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _CourseCardShimmer(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXL(context);
    final padding = ResponsiveValues.cardPadding(context);
    final iconSpacing = ResponsiveValues.spacingS(context);

    return Container(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
            ),
          ),
          SizedBox(width: iconSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: iconSpacing,
                  runSpacing: iconSpacing,
                  children: [
                    Container(
                      width: 100,
                      height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: iconSpacing),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ChapterCardShimmer(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final padding = ResponsiveValues.cardPadding(context);

    return Container(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 100,
                  height: 24,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _ExamCardShimmer(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final padding = ResponsiveValues.cardPadding(context);

    return Container(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 70,
                      height: 24,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _VideoCardShimmer(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 180,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
          ),
          Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 80,
                      height: 16,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _NoteCardShimmer(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXXL(context);
    final padding = ResponsiveValues.cardPadding(context);

    return Container(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 16,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 50,
                      height: 16,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
          ),
        ],
      ),
    );
  }

  Widget _NotificationCardShimmer(BuildContext context) {
    return Container(
      padding: ResponsiveValues.cardPadding(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 18,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 20,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _SchoolCardShimmer(BuildContext context) {
    final iconSize = ResponsiveValues.iconSizeXL(context) * 1.5;

    return Container(
      padding: ResponsiveValues.cardPadding(context),
      child: Row(
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }

  Widget _TextLineShimmer(BuildContext context) {
    return Container(
      width: customWidth ?? double.infinity,
      height: customHeight ?? 16,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
    );
  }

  Widget _CircleShimmer(BuildContext context) {
    return Container(
      width: customWidth ?? ResponsiveValues.avatarSizeLarge(context),
      height: customHeight ?? ResponsiveValues.avatarSizeLarge(context),
      decoration:
          const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    );
  }

  Widget _RectangleShimmer(BuildContext context) {
    return Container(
      width: customWidth ?? double.infinity,
      height: customHeight ?? 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
      ),
    );
  }

  Widget _StatCircleShimmer(BuildContext context) {
    return Container(
      width: ResponsiveValues.statCircleSize(context),
      height: ResponsiveValues.statCircleSize(context),
      padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
      child: Container(
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }

  Widget _PaymentCardShimmer(BuildContext context) =>
      _RectangleShimmer(context);
  Widget _SubscriptionCardShimmer(BuildContext context) =>
      _RectangleShimmer(context);
  Widget _ContactCardShimmer(BuildContext context) =>
      _RectangleShimmer(context);
  Widget _StatusCardShimmer(BuildContext context) => _RectangleShimmer(context);
  Widget _PairingCardShimmer(BuildContext context) =>
      _RectangleShimmer(context);
}
