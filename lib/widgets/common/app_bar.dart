import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/widgets/common/notification_button.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showThemeToggle;
  final bool showNotification;
  final bool showRefresh;
  final bool isLoading;
  final VoidCallback? onRefresh;
  final double expandedHeight;
  final Widget? customTrailing;
  final bool useSliver;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showThemeToggle = true,
    this.showNotification = true,
    this.showRefresh = false,
    this.isLoading = false,
    this.onRefresh,
    this.expandedHeight = 80.0,
    this.customTrailing,
    this.useSliver = false,
  });

  @override
  Size get preferredSize => Size.fromHeight(expandedHeight);

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final Widget appBarContent = Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 8,
          ),
          child: Row(
            children: [
              if (leading != null) leading!,
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showRefresh)
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.telegramBlue),
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: onRefresh,
                        child: _buildGlassContainer(
                          context,
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: Icon(
                                Icons.refresh_rounded,
                                color: AppColors.telegramBlue,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                  if (showThemeToggle) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: themeProvider.toggleTheme,
                      child: _buildGlassContainer(
                        context,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(
                            child: Icon(
                              themeProvider.themeMode == ThemeMode.dark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 22,
                              color: AppColors.getTextPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (showNotification) ...[
                    const SizedBox(width: 4),
                    const NotificationButton(),
                  ],
                  if (customTrailing != null) ...[
                    const SizedBox(width: 4),
                    customTrailing!,
                  ],
                  if (actions != null) ...actions!,
                ],
              ),
            ],
          ),
        );

        // If using sliver, wrap in SliverToBoxAdapter
        if (useSliver) {
          return SliverToBoxAdapter(child: appBarContent);
        }

        return appBarContent;
      },
    );
  }
}
