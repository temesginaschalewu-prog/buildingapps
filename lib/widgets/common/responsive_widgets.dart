import 'package:flutter/material.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/app_enums.dart';

class ResponsiveInfo {
  final BuildContext context;
  late final bool isMobile;
  late final bool isTablet;
  late final bool isDesktop;
  late final bool isLargeScreen;
  late final double width;
  late final double height;

  ResponsiveInfo(this.context) {
    isMobile = ScreenSize.isMobile(context);
    isTablet = ScreenSize.isTablet(context);
    isDesktop = ScreenSize.isDesktop(context);
    isLargeScreen = ScreenSize.isLargeScreen(context);
    width = ScreenSize.getScreenWidth(context);
    height = ScreenSize.getScreenHeight(context);
  }

  double spacing(AppSpacing level) => level.getValue(context);
  double get spacingXXS => spacing(AppSpacing.xxs);
  double get spacingXS => spacing(AppSpacing.xs);
  double get spacingS => spacing(AppSpacing.s);
  double get spacingM => spacing(AppSpacing.m);
  double get spacingL => spacing(AppSpacing.l);
  double get spacingXL => spacing(AppSpacing.xl);
  double get spacingXXL => spacing(AppSpacing.xxl);
  double get spacingXXXL => spacing(AppSpacing.xxxl);
  double get spacingXXXXL => spacing(AppSpacing.xxxxl);

  double get fontDisplayLarge => ResponsiveValues.fontDisplayLarge(context);
  double get fontDisplayMedium => ResponsiveValues.fontDisplayMedium(context);
  double get fontDisplaySmall => ResponsiveValues.fontDisplaySmall(context);
  double get fontHeadlineLarge => ResponsiveValues.fontHeadlineLarge(context);
  double get fontHeadlineMedium => ResponsiveValues.fontHeadlineMedium(context);
  double get fontHeadlineSmall => ResponsiveValues.fontHeadlineSmall(context);
  double get fontTitleLarge => ResponsiveValues.fontTitleLarge(context);
  double get fontTitleMedium => ResponsiveValues.fontTitleMedium(context);
  double get fontTitleSmall => ResponsiveValues.fontTitleSmall(context);
  double get fontBodyLarge => ResponsiveValues.fontBodyLarge(context);
  double get fontBodyMedium => ResponsiveValues.fontBodyMedium(context);
  double get fontBodySmall => ResponsiveValues.fontBodySmall(context);

  double get iconSizeXXS => ResponsiveValues.iconSizeXXS(context);
  double get iconSizeXS => ResponsiveValues.iconSizeXS(context);
  double get iconSizeS => ResponsiveValues.iconSizeS(context);
  double get iconSizeM => ResponsiveValues.iconSizeM(context);
  double get iconSizeL => ResponsiveValues.iconSizeL(context);
  double get iconSizeXL => ResponsiveValues.iconSizeXL(context);
  double get iconSizeXXL => ResponsiveValues.iconSizeXXL(context);

  EdgeInsets get screenPadding => ResponsiveValues.screenPadding(context);
  EdgeInsets get cardPadding => ResponsiveValues.cardPadding(context);
  EdgeInsets get dialogPadding => ResponsiveValues.dialogPadding(context);
  EdgeInsets get buttonPadding => ResponsiveValues.buttonPadding(context);
  EdgeInsets get listItemPadding => ResponsiveValues.listItemPadding(context);

  double scale(double value) {
    if (isMobile) return value;
    if (isTablet) return value * 1.05;
    if (isDesktop) return value * 1.1;
    return value * 1.15;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
          BuildContext context, BoxConstraints constraints, ResponsiveInfo info)
      builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          builder(context, constraints, ResponsiveInfo(context)),
    );
  }
}

class ResponsiveSizedBox extends StatelessWidget {
  final Widget? child;
  final AppSpacing? width;
  final AppSpacing? height;

  const ResponsiveSizedBox({super.key, this.child, this.width, this.height});

  const ResponsiveSizedBox.shrink({super.key})
      : child = null,
        width = AppSpacing.none,
        height = AppSpacing.none;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width?.getValue(context),
      height: height?.getValue(context),
      child: child,
    );
  }
}

class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Decoration? decoration;
  final Alignment? alignment;
  final Clip clipBehavior;
  final bool useMaxWidth;
  final double? maxWidth;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.decoration,
    this.alignment,
    this.clipBehavior = Clip.none,
    this.useMaxWidth = true,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, info) {
        return Container(
          width: width ?? (useMaxWidth ? info.width : null),
          height: height,
          margin: margin ?? EdgeInsets.zero,
          padding: padding ?? info.cardPadding,
          decoration: decoration,
          alignment: alignment,
          clipBehavior: clipBehavior,
          constraints: maxWidth != null
              ? BoxConstraints(maxWidth: maxWidth!)
              : (useMaxWidth
                  ? BoxConstraints(
                      maxWidth: info.isDesktop ? 1200 : double.infinity)
                  : null),
          child: child,
        );
      },
    );
  }
}

class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final AppSpacing? spacing;
  final EdgeInsetsGeometry? padding;

  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, info) {
        final effectiveSpacing = spacing?.getValue(context) ?? info.spacingL;

        bool hasExpanded = false;
        for (var child in children) {
          if (child is Expanded || child is Flexible) {
            hasExpanded = true;
            break;
          }
        }

        if (hasExpanded) {
          return Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Column(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: mainAxisSize,
              children: children,
            ),
          );
        }

        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Column(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: children
                .expand((child) => [
                      child,
                      if (child != children.last)
                        SizedBox(height: effectiveSpacing)
                    ])
                .toList(),
          ),
        );
      },
    );
  }
}

class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final AppSpacing? spacing;
  final EdgeInsetsGeometry? padding;
  final bool wrap;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
    this.padding,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, info) {
        final effectiveSpacing = spacing?.getValue(context) ?? info.spacingM;

        bool hasExpanded = false;
        for (var child in children) {
          if (child is Expanded || child is Flexible) {
            hasExpanded = true;
            break;
          }
        }

        if (hasExpanded) {
          return Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: mainAxisSize,
              children: children,
            ),
          );
        }

        bool hasSpacer = false;
        for (var child in children) {
          if (child is Spacer) {
            hasSpacer = true;
            break;
          }
        }

        if (hasSpacer) {
          return Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              mainAxisSize: mainAxisSize,
              children: children,
            ),
          );
        }

        double totalWidth = 0;
        for (var child in children) {
          if (child is SizedBox && child.width != null) {
            totalWidth += child.width!;
          } else {
            totalWidth = constraints.maxWidth + 1;
            break;
          }
        }

        if (totalWidth > constraints.maxWidth ||
            (info.isMobile && children.length > 2) ||
            wrap) {
          return Padding(
            padding: padding ?? EdgeInsets.zero,
            child: Wrap(
              spacing: effectiveSpacing,
              runSpacing: effectiveSpacing,
              alignment: _getWrapAlignment(mainAxisAlignment),
              crossAxisAlignment: _getWrapCrossAlignment(crossAxisAlignment),
              children: children,
            ),
          );
        }

        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: mainAxisAlignment,
            crossAxisAlignment: crossAxisAlignment,
            mainAxisSize: mainAxisSize,
            children: children,
          ),
        );
      },
    );
  }

  WrapAlignment _getWrapAlignment(MainAxisAlignment alignment) {
    switch (alignment) {
      case MainAxisAlignment.start:
        return WrapAlignment.start;
      case MainAxisAlignment.end:
        return WrapAlignment.end;
      case MainAxisAlignment.center:
        return WrapAlignment.center;
      case MainAxisAlignment.spaceBetween:
        return WrapAlignment.spaceBetween;
      case MainAxisAlignment.spaceAround:
        return WrapAlignment.spaceAround;
      case MainAxisAlignment.spaceEvenly:
        return WrapAlignment.spaceEvenly;
      default:
        return WrapAlignment.start;
    }
  }

  WrapCrossAlignment _getWrapCrossAlignment(CrossAxisAlignment alignment) {
    switch (alignment) {
      case CrossAxisAlignment.start:
        return WrapCrossAlignment.start;
      case CrossAxisAlignment.end:
        return WrapCrossAlignment.end;
      case CrossAxisAlignment.center:
        return WrapCrossAlignment.center;
      default:
        return WrapCrossAlignment.start;
    }
  }
}

class ResponsiveText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final TextScaler? textScaler;

  const ResponsiveText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.textScaler,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, info) {
        TextStyle effectiveStyle = style ?? const TextStyle();

        if (effectiveStyle.fontSize != null) {
          effectiveStyle = effectiveStyle.copyWith(
              fontSize: info.scale(effectiveStyle.fontSize!));
        }

        return Text(
          data,
          style: effectiveStyle,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
          textScaler: textScaler ?? MediaQuery.textScalerOf(context),
        );
      },
    );
  }
}

class ResponsiveIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;

  const ResponsiveIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, constraints, info) {
        final effectiveSize = size ?? info.iconSizeM;
        return Icon(icon, size: effectiveSize, color: color);
      },
    );
  }
}
