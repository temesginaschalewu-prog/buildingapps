import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/parent_link_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/responsive_widgets.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/empty_state.dart';

class ParentLinkScreen extends StatefulWidget {
  const ParentLinkScreen({super.key});

  @override
  State<ParentLinkScreen> createState() => _ParentLinkScreenState();
}

class _ParentLinkScreenState extends State<ParentLinkScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late Timer _refreshTimer;
  bool _isRefreshing = false;
  bool _isInitialized = false;
  bool _isOffline = false;
  String _refreshSubtitle = '';
  final RefreshController _refreshController = RefreshController();

  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();
    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);

    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _setupTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshData(showLoading: false);
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _pulseAnimationController.dispose();
    _refreshController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildGlassContainer({required Widget child}) {
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

  Widget _buildGlassButton({
    required String label,
    required VoidCallback? onPressed,
    required List<Color> gradient,
    IconData? icon,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? LinearGradient(colors: gradient) : null,
        color: onPressed != null
            ? null
            : AppColors.getTextSecondary(context).withValues(alpha: 0.2),
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.3),
                  blurRadius: ResponsiveValues.spacingS(context),
                  offset: Offset(0, ResponsiveValues.spacingXS(context)),
                ),
              ]
            : null,
      ),
      child: Material(
        color: onPressed != null ? Colors.transparent : Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingL(context),
            ),
            alignment: Alignment.center,
            child: isLoading
                ? SizedBox(
                    width: ResponsiveValues.iconSizeM(context),
                    height: ResponsiveValues.iconSizeM(context),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : ResponsiveRow(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: ResponsiveValues.iconSizeS(context),
                          color: Colors.white,
                        ),
                        ResponsiveSizedBox(width: AppSpacing.s),
                      ],
                      ResponsiveText(
                        label,
                        style: AppTextStyles.buttonMedium(context).copyWith(
                          color: onPressed != null
                              ? Colors.white
                              : AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  void _setupTimers() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _refreshDataInBackground();
    });
  }

  Future<void> _initializeData() async {
    final parentLinkProvider =
        Provider.of<ParentLinkProvider>(context, listen: false);

    try {
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isInitialized = true);
    }
  }

  Future<void> _refreshDataInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final parentLinkProvider =
          Provider.of<ParentLinkProvider>(context, listen: false);
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      _refreshController.refreshFailed();
      showTopSnackBar(context, 'You are offline. Using cached data.',
          isError: true);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

    try {
      final parentLinkProvider =
          Provider.of<ParentLinkProvider>(context, listen: false);
      await parentLinkProvider.clearCache();
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);

      setState(() => _isOffline = false);
      showTopSnackBar(context, 'Status updated');
    } catch (e) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'Refresh failed, using cached data',
          isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
      });
      _refreshController.refreshCompleted();
    }
  }

  Future<void> _refreshData({bool showLoading = true}) async {
    if (_isRefreshing) return;

    if (showLoading) setState(() => _isRefreshing = true);

    try {
      final parentLinkProvider =
          Provider.of<ParentLinkProvider>(context, listen: false);
      await parentLinkProvider.clearCache();
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);

      _refreshController.refreshCompleted();

      if (showLoading && mounted) showTopSnackBar(context, 'Status updated');
    } catch (e) {
      _refreshController.refreshFailed();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
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
      showTopSnackBar(
          context, 'Failed to generate token: ${formatErrorMessage(e)}',
          isError: true);
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
          await Future.delayed(const Duration(milliseconds: 500));
          await parentLinkProvider.getParentLinkStatus(forceRefresh: true);

          if (mounted) showTopSnackBar(context, 'Parent unlinked successfully');
        } catch (e) {
          if (mounted) {
            showTopSnackBar(
                context, 'Failed to unlink: ${formatErrorMessage(e)}',
                isError: true);
          }
        }
      },
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: ResponsiveValues.avatarSizeLarge(context),
                    height: ResponsiveValues.avatarSizeLarge(context),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: ResponsiveValues.spacingXXXL(context) * 4,
                    height: ResponsiveValues.spacingXL(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context),
                      ),
                    ),
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: ResponsiveValues.spacingXXXL(context) * 5,
                    height: ResponsiveValues.spacingL(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusSmall(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTokenDialog(String token, DateTime expiresAt) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: ScreenSize.isMobile(context) ? 400 : 500,
              ),
              child: ResponsiveColumn(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveRow(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.all(ResponsiveValues.spacingM(context)),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.link_rounded,
                            color: AppColors.telegramBlue, size: 24),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.l),
                      ResponsiveText(
                        'Link Token',
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  ResponsiveText(
                    'Share this token with parent:',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  _buildGlassContainer(
                    child: Padding(
                      padding: ResponsiveValues.cardPadding(context),
                      child: ResponsiveColumn(
                        children: [
                          SelectableText(
                            token,
                            style: TextStyle(
                              fontSize:
                                  ResponsiveValues.fontTitleLarge(context),
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              color: AppColors.telegramBlue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          ResponsiveSizedBox(height: AppSpacing.l),
                          Consumer<ParentLinkProvider>(
                            builder: (context, provider, child) {
                              final remainingTime = provider.remainingTime;
                              final isExpiringSoon =
                                  remainingTime.inMinutes < 5;

                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      ResponsiveValues.spacingM(context),
                                  vertical: ResponsiveValues.spacingXS(context),
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isExpiringSoon
                                        ? [
                                            AppColors.telegramRed
                                                .withValues(alpha: 0.2),
                                            AppColors.telegramRed
                                                .withValues(alpha: 0.1),
                                          ]
                                        : [
                                            AppColors.telegramGreen
                                                .withValues(alpha: 0.2),
                                            AppColors.telegramGreen
                                                .withValues(alpha: 0.1),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveValues.radiusFull(context),
                                  ),
                                  border: Border.all(
                                    color: isExpiringSoon
                                        ? AppColors.telegramRed
                                        : AppColors.telegramGreen,
                                  ),
                                ),
                                child: ResponsiveRow(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_rounded,
                                      size:
                                          ResponsiveValues.iconSizeXS(context),
                                      color: isExpiringSoon
                                          ? AppColors.telegramRed
                                          : AppColors.telegramGreen,
                                    ),
                                    ResponsiveSizedBox(width: AppSpacing.xs),
                                    ResponsiveText(
                                      'Expires in: ${provider.remainingTimeFormatted}',
                                      style: AppTextStyles.labelSmall(context)
                                          .copyWith(
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
                  ),
                  ResponsiveSizedBox(height: AppSpacing.l),
                  ResponsiveText(
                    'Instructions:',
                    style: AppTextStyles.titleSmall(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.m),
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
                  ResponsiveSizedBox(height: AppSpacing.xl),
                  ResponsiveRow(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => GoRouter.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                AppColors.getTextSecondary(context),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                      ResponsiveSizedBox(width: AppSpacing.m),
                      Expanded(
                        child: _buildGlassButton(
                          label: 'Copy',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: token));
                            showTopSnackBar(context, 'Copied to clipboard');
                            GoRouter.of(context).pop();
                          },
                          gradient: AppColors.blueGradient,
                          icon: Icons.copy_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingM(context),
      ),
      child: ResponsiveRow(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ResponsiveValues.iconSizeL(context),
            height: ResponsiveValues.iconSizeL(context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.telegramBlue.withValues(alpha: 0.2),
                  AppColors.telegramPurple.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: ResponsiveValues.iconSizeXXS(context),
              color: AppColors.telegramBlue,
            ),
          ),
          ResponsiveSizedBox(width: AppSpacing.m),
          Expanded(
            child: ResponsiveText(
              text,
              style: AppTextStyles.bodyMedium(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedState(ParentLinkProvider provider) {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: ResponsiveColumn(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimationController,
                  builder: (context, child) {
                    return Container(
                      width: ResponsiveValues.avatarSizeLarge(context) *
                          (1 + _pulseAnimationController.value * 0.1),
                      height: ResponsiveValues.avatarSizeLarge(context) *
                          (1 + _pulseAnimationController.value * 0.1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.telegramGreen.withValues(alpha: 0.3),
                          AppColors.telegramGreen.withValues(alpha: 0.1),
                          Colors.transparent,
                        ]),
                      ),
                    );
                  },
                ),
                Container(
                  width: ResponsiveValues.avatarSizeLarge(context),
                  height: ResponsiveValues.avatarSizeLarge(context),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34C759), Color(0xFF2CAE4A)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.telegramGreen.withValues(alpha: 0.3),
                        blurRadius: ResponsiveValues.spacingXL(context),
                        spreadRadius: ResponsiveValues.spacingXS(context),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 40, color: Colors.white),
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              'Parent Connected',
              style: AppTextStyles.headlineSmall(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.m),
            if (provider.parentTelegramUsername != null)
              _buildGlassContainer(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingL(context),
                    vertical: ResponsiveValues.spacingM(context),
                  ),
                  child: ResponsiveRow(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.telegram,
                          size: 20, color: AppColors.telegramBlue),
                      ResponsiveSizedBox(width: AppSpacing.s),
                      ResponsiveText(
                        '@${provider.parentTelegramUsername}',
                        style: AppTextStyles.bodyMedium(context).copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ResponsiveSizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: _buildGlassButton(
                label: 'Disconnect Parent',
                onPressed: _unlinkParent,
                gradient: AppColors.pinkGradient,
                icon: Icons.link_off_rounded,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildTokenState(ParentLinkProvider provider) {
    final remainingTime = provider.remainingTime;
    final isExpiringSoon = remainingTime.inMinutes < 5;
    final statusColor =
        isExpiringSoon ? AppColors.telegramRed : AppColors.telegramBlue;

    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: ResponsiveColumn(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnimationController,
                  builder: (context, child) {
                    return Container(
                      width: ResponsiveValues.avatarSizeLarge(context) *
                          (1 + _pulseAnimationController.value * 0.1),
                      height: ResponsiveValues.avatarSizeLarge(context) *
                          (1 + _pulseAnimationController.value * 0.1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          statusColor.withValues(alpha: 0.3),
                          statusColor.withValues(alpha: 0.1),
                          Colors.transparent,
                        ]),
                      ),
                    );
                  },
                ),
                Container(
                  width: ResponsiveValues.avatarSizeLarge(context),
                  height: ResponsiveValues.avatarSizeLarge(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isExpiringSoon
                          ? [AppColors.telegramRed, AppColors.telegramOrange]
                          : [AppColors.telegramBlue, AppColors.telegramPurple],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.3),
                        blurRadius: ResponsiveValues.spacingXL(context),
                        spreadRadius: ResponsiveValues.spacingXS(context),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.timer_rounded,
                      size: 40, color: Colors.white),
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              'Token Active',
              style: AppTextStyles.headlineSmall(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.m),
            _buildGlassContainer(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingL(context),
                  vertical: ResponsiveValues.spacingM(context),
                ),
                child: ResponsiveRow(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: ResponsiveValues.iconSizeS(context),
                      color: statusColor,
                    ),
                    ResponsiveSizedBox(width: AppSpacing.s),
                    ResponsiveText(
                      provider.remainingTimeFormatted,
                      style: AppTextStyles.titleMedium(context).copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: _buildGlassButton(
                label: 'Show Token',
                onPressed: () {
                  if (provider.parentToken != null &&
                      provider.tokenExpiresAt != null) {
                    _showTokenDialog(
                        provider.parentToken!, provider.tokenExpiresAt!);
                  }
                },
                gradient: AppColors.blueGradient,
                icon: Icons.visibility_rounded,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.m),
            TextButton(
              onPressed: _generateToken,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.telegramBlue,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingXL(context),
                  vertical: ResponsiveValues.spacingM(context),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                ),
              ),
              child: ResponsiveRow(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, size: 18),
                  ResponsiveSizedBox(width: AppSpacing.xs),
                  ResponsiveText(
                    'Generate New Token',
                    style: AppTextStyles.buttonMedium(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildNotLinkedState() {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: ResponsiveColumn(
          children: [
            Container(
              width: ResponsiveValues.avatarSizeLarge(context),
              height: ResponsiveValues.avatarSizeLarge(context),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.telegramBlue.withValues(alpha: 0.2),
                    AppColors.telegramPurple.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  size: 40, color: AppColors.telegramBlue),
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            ResponsiveText(
              'Connect Parent',
              style: AppTextStyles.headlineSmall(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.m),
            ResponsiveText(
              'Generate a token to link your parent\'s Telegram account and share your progress.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge(context).copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.5,
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: _buildGlassButton(
                label: 'Generate Token',
                onPressed: _generateToken,
                gradient: AppColors.blueGradient,
                icon: Icons.add_link_rounded,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildInfoSection() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final telegramBotUrl = settingsProvider.getTelegramBotUrl();

    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: ResponsiveColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveRow(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                ResponsiveSizedBox(width: AppSpacing.m),
                ResponsiveText(
                  'What parents can see',
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
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
            ResponsiveSizedBox(height: AppSpacing.l),
            _buildGlassContainer(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: ResponsiveColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveRow(
                      children: [
                        const Icon(Icons.telegram,
                            size: 20, color: AppColors.telegramBlue),
                        ResponsiveSizedBox(width: AppSpacing.m),
                        Expanded(
                          child: ResponsiveText(
                            'Parent Telegram Bot',
                            style: AppTextStyles.titleSmall(context).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ResponsiveSizedBox(height: AppSpacing.s),
                    GestureDetector(
                      onTap: () => _openTelegramBot(telegramBotUrl!),
                      child: Container(
                        padding: ResponsiveValues.cardPadding(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        child: ResponsiveRow(
                          children: [
                            Expanded(
                              child: ResponsiveText(
                                telegramBotUrl!,
                                style:
                                    AppTextStyles.bodySmall(context).copyWith(
                                  color: AppColors.telegramBlue,
                                  decoration: TextDecoration.underline,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.open_in_new,
                                size: 16, color: AppColors.telegramBlue),
                          ],
                        ),
                      ),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.s),
                    ResponsiveText(
                      'Parents receive updates via Telegram. They cannot modify your account.',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium, delay: 100.ms)
        .slideY(
            begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Future<void> _openTelegramBot(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      showTopSnackBar(context, 'Cannot open Telegram', isError: true);
    }
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingM(context),
      ),
      child: ResponsiveRow(
        children: [
          Container(
            width: ResponsiveValues.iconSizeL(context),
            height: ResponsiveValues.iconSizeL(context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.telegramGreen.withValues(alpha: 0.2),
                  AppColors.telegramGreen.withValues(alpha: 0.1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: ResponsiveValues.iconSizeXS(context),
              color: AppColors.telegramGreen,
            ),
          ),
          ResponsiveSizedBox(width: AppSpacing.m),
          Expanded(
            child: ResponsiveText(
              text,
              style: AppTextStyles.bodyMedium(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(AuthProvider authProvider) {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: ResponsiveRow(
          children: [
            Container(
              width: ResponsiveValues.avatarSizeMedium(context),
              height: ResponsiveValues.avatarSizeMedium(context),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.blueGradient,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.telegramBlue,
                    blurRadius: 10,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Center(
                child: ResponsiveText(
                  authProvider.currentUser!.username
                      .substring(0, 1)
                      .toUpperCase(),
                  style: AppTextStyles.titleMedium(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ResponsiveSizedBox(width: AppSpacing.l),
            Expanded(
              child: ResponsiveColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveText(
                    authProvider.currentUser!.username,
                    style: AppTextStyles.titleSmall(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ResponsiveSizedBox(height: AppSpacing.xs),
                  ResponsiveText(
                    'Student ID: ${authProvider.currentUser!.id}',
                    style: AppTextStyles.bodySmall(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationDurationMedium, delay: 200.ms);
  }

  Widget _buildMobileLayout() {
    final parentLinkProvider = Provider.of<ParentLinkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: _buildSkeletonLoader(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // App bar with back button
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: ResponsiveValues.spacingL(context),
                  right: ResponsiveValues.spacingL(context),
                  top: MediaQuery.of(context).padding.top +
                      ResponsiveValues.spacingM(context),
                  bottom: ResponsiveValues.spacingS(context),
                ),
                child: Row(
                  children: [
                    Container(
                      width: ResponsiveValues.appBarButtonSize(context),
                      height: ResponsiveValues.appBarButtonSize(context),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context) / 2,
                        ),
                      ),
                      child: IconButton(
                        icon: ResponsiveIcon(
                          Icons.arrow_back_rounded,
                          size: ResponsiveValues.appBarIconSize(context),
                          color: AppColors.getTextPrimary(context),
                        ),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parent Link',
                            style:
                                AppTextStyles.headlineSmall(context).copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isRefreshing
                                ? 'Refreshing...'
                                : (_isOffline
                                    ? 'Offline mode'
                                    : 'Connect with parents'),
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            SliverPadding(
              padding: ResponsiveValues.screenPadding(context),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: ScreenSize.responsiveDouble(
                        context: context,
                        mobile: double.infinity,
                        tablet: 600,
                        desktop: 800,
                      ),
                    ),
                    child: ResponsiveColumn(
                      children: [
                        if (_isOffline)
                          Container(
                            margin: EdgeInsets.only(
                                bottom: ResponsiveValues.spacingL(context)),
                            padding: ResponsiveValues.cardPadding(context),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.telegramYellow
                                      .withValues(alpha: 0.2),
                                  AppColors.telegramYellow
                                      .withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
                              border: Border.all(
                                color: AppColors.telegramYellow
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: ResponsiveRow(
                              children: [
                                const Icon(Icons.wifi_off_rounded,
                                    color: AppColors.telegramYellow, size: 20),
                                ResponsiveSizedBox(width: AppSpacing.m),
                                Expanded(
                                  child: ResponsiveText(
                                    'Offline mode - showing cached data',
                                    style: AppTextStyles.bodySmall(context)
                                        .copyWith(
                                      color: AppColors.telegramYellow,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (parentLinkProvider.isLinked)
                          _buildLinkedState(parentLinkProvider)
                        else if (parentLinkProvider.parentToken != null &&
                            !parentLinkProvider.isTokenExpired)
                          _buildTokenState(parentLinkProvider)
                        else
                          _buildNotLinkedState(),
                        ResponsiveSizedBox(height: AppSpacing.xl),
                        _buildInfoSection(),
                        if (authProvider.currentUser != null) ...[
                          ResponsiveSizedBox(height: AppSpacing.l),
                          _buildUserInfo(authProvider),
                        ],
                        ResponsiveSizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return _buildMobileLayout();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildDesktopLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}
