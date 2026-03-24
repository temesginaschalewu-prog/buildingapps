import 'package:flutter/material.dart';
import '../../themes/app_colors.dart';

class AppBrandLogo extends StatelessWidget {
  final double size;
  final double borderRadius;

  const AppBrandLogo({
    super.key,
    required this.size,
    this.borderRadius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border.all(
          color: isDark
              ? AppColors.getDivider(context).withValues(alpha: 0.5)
              : AppColors.getDivider(context),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.asset(
          'assets/images/logo_clean.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
              ),
              child: Center(
                child: Icon(
                  Icons.school_rounded,
                  color: AppColors.getTextSecondary(context),
                  size: 36,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
