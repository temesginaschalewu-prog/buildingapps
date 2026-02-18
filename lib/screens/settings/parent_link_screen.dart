import 'dart:async';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../providers/parent_link_provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../utils/helpers.dart';

class ParentLinkScreen extends StatefulWidget {
  const ParentLinkScreen({super.key});

  @override
  State<ParentLinkScreen> createState() => _ParentLinkScreenState();
}

class _ParentLinkScreenState extends State<ParentLinkScreen>
    with TickerProviderStateMixin {
  late Timer _refreshTimer;
  bool _isRefreshing = false;
  bool _isInitialized = false;

  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

    _initializeData();
    _setupTimers();
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _setupTimers() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _refreshDataInBackground();
      }
    });
  }

  Future<void> _initializeData() async {
    final parentLinkProvider =
        Provider.of<ParentLinkProvider>(context, listen: false);

    try {
      await parentLinkProvider.getParentLinkStatus(forceRefresh: false);
    } finally {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  Future<void> _refreshDataInBackground() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final parentLinkProvider =
          Provider.of<ParentLinkProvider>(context, listen: false);
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _refreshData() async {
    await _refreshDataInBackground();
  }

  Future<void> _generateToken() async {
    final parentLinkProvider =
        Provider.of<ParentLinkProvider>(context, listen: false);

    try {
      await parentLinkProvider.generateParentToken();

      final token = parentLinkProvider.parentToken;
      final expiresAt = parentLinkProvider.tokenExpiresAt;

      if (token != null && expiresAt != null) {
        _showTokenDialog(token, expiresAt);
      }
    } catch (e) {
      showSnackBar(
        context,
        'Failed to generate token: ${formatErrorMessage(e)}',
        isError: true,
      );
    }
  }

  Future<void> _unlinkParent() async {
    final confirmed = await showConfirmDialog(
      context,
      'Unlink Parent',
      'Are you sure you want to unlink the parent? This will stop all progress updates.',
      () async {
        final parentLinkProvider =
            Provider.of<ParentLinkProvider>(context, listen: false);
        try {
          await parentLinkProvider.unlinkParent();
          showSimpleSnackBar(context, 'Parent unlinked successfully');
        } catch (e) {
          showSnackBar(
            context,
            'Failed to unlink: ${formatErrorMessage(e)}',
            isError: true,
          );
        }
      },
    );
  }

  void _showTokenDialog(String token, DateTime expiresAt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: ScreenSize.isMobile(context) ? 400 : 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppThemes.spacingM),
                      decoration: BoxDecoration(
                        color: AppColors.telegramBlue.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        color: AppColors.telegramBlue,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: AppThemes.spacingM),
                    Text(
                      'Link Token',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: AppThemes.spacingL),

                Text(
                  'Share this token with parent:',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),

                SizedBox(height: AppThemes.spacingM),

                // Token display
                Container(
                  padding: EdgeInsets.all(AppThemes.spacingL),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                    border: Border.all(
                      color: AppColors.telegramBlue.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      SelectableText(
                        token,
                        style: TextStyle(
                          fontSize: ScreenSize.responsiveFontSize(
                            context: context,
                            mobile: 20,
                            tablet: 22,
                            desktop: 24,
                          ),
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                          color: AppColors.telegramBlue,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: AppThemes.spacingM),

                      // Expiry timer
                      Consumer<ParentLinkProvider>(
                        builder: (context, provider, child) {
                          final remainingTime = provider.remainingTime;
                          final isExpiringSoon = remainingTime.inMinutes < 5;

                          return Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppThemes.spacingM,
                              vertical: AppThemes.spacingXS,
                            ),
                            decoration: BoxDecoration(
                              color: isExpiringSoon
                                  ? AppColors.telegramRed.withOpacity(0.1)
                                  : AppColors.telegramGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusFull),
                              border: Border.all(
                                color: isExpiringSoon
                                    ? AppColors.telegramRed
                                    : AppColors.telegramGreen,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_rounded,
                                  size: 16,
                                  color: isExpiringSoon
                                      ? AppColors.telegramRed
                                      : AppColors.telegramGreen,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Expires in: ${provider.remainingTimeFormatted}',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: isExpiringSoon
                                        ? AppColors.telegramRed
                                        : AppColors.telegramGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppThemes.spacingL),

                // Instructions
                Text(
                  'Instructions:',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),

                SizedBox(height: AppThemes.spacingM),

                _buildInstruction(
                  '1. Send this token to your parent via Telegram',
                  Icons.send_rounded,
                ),
                _buildInstruction(
                  '2. Parent uses /link command in Telegram with the token',
                  Icons.telegram,
                ),
                _buildInstruction(
                  '3. Connection will be established automatically',
                  Icons.link_rounded,
                ),

                SizedBox(height: AppThemes.spacingXL),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => GoRouter.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                          ),
                          padding: EdgeInsets.symmetric(
                              vertical: AppThemes.spacingM),
                        ),
                        child: Text('Close', style: AppTextStyles.buttonMedium),
                      ),
                    ),
                    SizedBox(width: AppThemes.spacingM),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: token));
                          showSimpleSnackBar(context, 'Copied to clipboard');
                          GoRouter.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.telegramBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                          ),
                          padding: EdgeInsets.symmetric(
                              vertical: AppThemes.spacingM),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.copy_rounded, size: 18),
                            SizedBox(width: 4),
                            Text('Copy', style: AppTextStyles.buttonMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.telegramBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 12,
              color: AppColors.telegramBlue,
            ),
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🎯 State 1: Linked
  Widget _buildLinkedState(ParentLinkProvider provider) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingXL,
        tablet: AppThemes.spacingXXL,
        desktop: AppThemes.spacingXXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Success icon with pulse
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimationController,
                builder: (context, child) {
                  return Container(
                    width: 80 * (1 + _pulseAnimationController.value * 0.1),
                    height: 80 * (1 + _pulseAnimationController.value * 0.1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.telegramGreen.withOpacity(0.3),
                          AppColors.telegramGreen.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.telegramGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.telegramGreen,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 32,
                  color: AppColors.telegramGreen,
                ),
              ),
            ],
          ),

          SizedBox(height: AppThemes.spacingL),

          Text(
            'Parent Connected',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: AppThemes.spacingM),

          // Parent Telegram info
          if (provider.parentTelegramUsername != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppThemes.spacingL,
                vertical: AppThemes.spacingM,
              ),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
                border: Border.all(
                  color: Theme.of(context).dividerColor,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.telegram,
                    size: 20,
                    color: AppColors.telegramBlue,
                  ),
                  SizedBox(width: AppThemes.spacingS),
                  Text(
                    '@${provider.parentTelegramUsername}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: AppThemes.spacingXL),

          // Disconnect button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _unlinkParent,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.telegramRed,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off_rounded, size: 20),
                  SizedBox(width: AppThemes.spacingS),
                  Text('Disconnect Parent', style: AppTextStyles.buttonMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  // 🎯 State 2: Token Active
  Widget _buildTokenState(ParentLinkProvider provider) {
    final remainingTime = provider.remainingTime;
    final isExpiringSoon = remainingTime.inMinutes < 5;
    final statusColor =
        isExpiringSoon ? AppColors.telegramRed : AppColors.telegramBlue;

    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingXL,
        tablet: AppThemes.spacingXXL,
        desktop: AppThemes.spacingXXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Timer icon with pulse
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimationController,
                builder: (context, child) {
                  return Container(
                    width: 80 * (1 + _pulseAnimationController.value * 0.1),
                    height: 80 * (1 + _pulseAnimationController.value * 0.1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          statusColor.withOpacity(0.3),
                          statusColor.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.timer_rounded,
                  size: 32,
                  color: statusColor,
                ),
              ),
            ],
          ),

          SizedBox(height: AppThemes.spacingL),

          Text(
            'Token Active',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: AppThemes.spacingM),

          // Timer display
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemes.spacingL,
              vertical: AppThemes.spacingM,
            ),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: statusColor,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 20,
                  color: statusColor,
                ),
                SizedBox(width: AppThemes.spacingS),
                Text(
                  provider.remainingTimeFormatted,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppThemes.spacingXL),

          // Show token button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (provider.parentToken != null &&
                    provider.tokenExpiresAt != null) {
                  _showTokenDialog(
                    provider.parentToken!,
                    provider.tokenExpiresAt!,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.telegramBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility_rounded, size: 20),
                  SizedBox(width: AppThemes.spacingS),
                  Text('Show Token', style: AppTextStyles.buttonMedium),
                ],
              ),
            ),
          ),

          SizedBox(height: AppThemes.spacingM),

          // Generate new token button
          TextButton(
            onPressed: _generateToken,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.telegramBlue,
              padding: EdgeInsets.symmetric(
                horizontal: AppThemes.spacingXL,
                vertical: AppThemes.spacingM,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, size: 18),
                SizedBox(width: AppThemes.spacingXS),
                Text('Generate New Token', style: AppTextStyles.buttonMedium),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  // 🎯 State 3: Not Linked
  Widget _buildNotLinkedState() {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingXL,
        tablet: AppThemes.spacingXXL,
        desktop: AppThemes.spacingXXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Add person icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.getTextSecondary(context).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person_add_alt_1_rounded,
              size: 32,
              color: AppColors.getTextSecondary(context),
            ),
          ),

          SizedBox(height: AppThemes.spacingL),

          Text(
            'Connect Parent',
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: AppThemes.spacingM),

          Text(
            'Generate a token to link your parent\'s Telegram account and share your progress.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.5,
            ),
          ),

          SizedBox(height: AppThemes.spacingXL),

          // Generate token button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _generateToken,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.telegramBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_link_rounded, size: 20),
                  SizedBox(width: AppThemes.spacingS),
                  Text('Generate Token', style: AppTextStyles.buttonMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  // ℹ️ Info section
  Widget _buildInfoSection() {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_rounded,
                  color: AppColors.telegramBlue,
                  size: 20,
                ),
              ),
              SizedBox(width: AppThemes.spacingM),
              Text(
                'What parents can see',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),
          SizedBox(height: AppThemes.spacingL),
          _buildInfoItem(
            icon: Icons.trending_up_rounded,
            text: 'Study progress and completion',
          ),
          _buildInfoItem(
            icon: Icons.quiz_rounded,
            text: 'Exam scores and results',
          ),
          _buildInfoItem(
            icon: Icons.subscriptions_rounded,
            text: 'Subscription status',
          ),
          _buildInfoItem(
            icon: Icons.calendar_month_rounded,
            text: 'Weekly progress summary',
          ),
          SizedBox(height: AppThemes.spacingL),
          Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            decoration: BoxDecoration(
              color: AppColors.telegramBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: AppColors.telegramBlue.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 20,
                  color: AppColors.telegramBlue,
                ),
                SizedBox(width: AppThemes.spacingM),
                Expanded(
                  child: Text(
                    'Parents receive updates via Telegram. They cannot modify your account.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: 100.ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.telegramGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color: AppColors.telegramGreen,
            ),
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 👤 User info card
  Widget _buildUserInfo(AuthProvider authProvider) {
    return Container(
      padding: EdgeInsets.all(AppThemes.spacingL),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.telegramBlue,
            radius: 24,
            child: Text(
              authProvider.currentUser!.username.substring(0, 1).toUpperCase(),
              style: AppTextStyles.titleMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: AppThemes.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authProvider.currentUser!.username,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Student ID: ${authProvider.currentUser!.id}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: 200.ms,
        );
  }

  // 📱 Mobile layout
  Widget _buildMobileLayout(BuildContext context) {
    final parentLinkProvider = Provider.of<ParentLinkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Parent Link',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.telegramBlue,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context),
                  ),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL,
          ),
        ),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: ScreenSize.responsiveValue(
                context: context,
                mobile: double.infinity,
                tablet: 600,
                desktop: 800,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!_isInitialized)
                  Container(
                    padding: EdgeInsets.all(AppThemes.spacingXXL),
                    child: LoadingIndicator(
                      message: 'Loading...',
                      type: LoadingType.circular,
                      color: AppColors.telegramBlue,
                    ),
                  )
                else if (parentLinkProvider.isLinked)
                  _buildLinkedState(parentLinkProvider)
                else if (parentLinkProvider.parentToken != null &&
                    !parentLinkProvider.isTokenExpired)
                  _buildTokenState(parentLinkProvider)
                else
                  _buildNotLinkedState(),
                SizedBox(height: AppThemes.spacingXL),
                _buildInfoSection(),
                if (authProvider.currentUser != null) ...[
                  SizedBox(height: AppThemes.spacingL),
                  _buildUserInfo(authProvider),
                ],
                SizedBox(height: AppThemes.spacingXXL),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 💻 Desktop/Tablet layout
  Widget _buildDesktopLayout(BuildContext context) {
    final parentLinkProvider = Provider.of<ParentLinkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Parent Link',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.telegramBlue,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context),
                  ),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppThemes.spacingXXL),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 1000,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column - Main content
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      if (!_isInitialized)
                        Container(
                          padding: EdgeInsets.all(AppThemes.spacingXXL),
                          child: LoadingIndicator(
                            message: 'Loading...',
                            type: LoadingType.circular,
                            color: AppColors.telegramBlue,
                          ),
                        )
                      else if (parentLinkProvider.isLinked)
                        _buildLinkedState(parentLinkProvider)
                      else if (parentLinkProvider.parentToken != null &&
                          !parentLinkProvider.isTokenExpired)
                        _buildTokenState(parentLinkProvider)
                      else
                        _buildNotLinkedState(),
                      if (authProvider.currentUser != null) ...[
                        SizedBox(height: AppThemes.spacingXL),
                        _buildUserInfo(authProvider),
                      ],
                    ],
                  ),
                ),

                SizedBox(width: AppThemes.spacingXXL),

                // Right column - Info
                Expanded(
                  flex: 1,
                  child: _buildInfoSection(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }
}
