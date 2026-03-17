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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.telegramBlue.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppColors.blueGradient),
              ),
              child: const Center(
                child:
                    Icon(Icons.school_rounded, color: Colors.white, size: 36),
              ),
            );
          },
        ),
      ),
    );
  }
}
