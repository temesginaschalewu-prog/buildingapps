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
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/parent_link_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';

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
    setState(() => _isRefreshing = true);

    try {
      final parentLinkProvider =
          Provider.of<ParentLinkProvider>(context, listen: false);
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Shimmer.fromColors(
          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
          child: Container(
            width: 150,
            height: 24,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
      ),
      body: Center(
        child: _buildGlassContainer(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: 200,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Shimmer.fromColors(
                  baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                  highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                  child: Container(
                    width: 300,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
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
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: ScreenSize.isMobile(context) ? 400 : 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
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
                      const SizedBox(width: 16),
                      Text('Link Token',
                          style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.getTextPrimary(context))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Share this token with parent:',
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextSecondary(context))),
                  const SizedBox(height: 16),
                  _buildGlassContainer(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          SelectableText(
                            token,
                            style: TextStyle(
                              fontSize: ScreenSize.responsiveFontSize(
                                  context: context,
                                  mobile: 20,
                                  tablet: 22,
                                  desktop: 24),
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                              color: AppColors.telegramBlue,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Consumer<ParentLinkProvider>(
                            builder: (context, provider, child) {
                              final remainingTime = provider.remainingTime;
                              final isExpiringSoon =
                                  remainingTime.inMinutes < 5;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
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
                                      AppThemes.borderRadiusFull),
                                  border: Border.all(
                                      color: isExpiringSoon
                                          ? AppColors.telegramRed
                                          : AppColors.telegramGreen),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_rounded,
                                        size: 16,
                                        color: isExpiringSoon
                                            ? AppColors.telegramRed
                                            : AppColors.telegramGreen),
                                    const SizedBox(width: 4),
                                    Text(
                                        'Expires in: ${provider.remainingTimeFormatted}',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                                color: isExpiringSoon
                                                    ? AppColors.telegramRed
                                                    : AppColors.telegramGreen,
                                                fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Instructions:',
                      style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context))),
                  const SizedBox(height: 12),
                  _buildInstruction(
                      '1. Send this token to your parent via Telegram',
                      Icons.send_rounded),
                  _buildInstruction(
                      '2. Parent uses /link command in Telegram with the token',
                      Icons.telegram),
                  _buildInstruction(
                      '3. Connection will be established automatically',
                      Icons.link_rounded),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => GoRouter.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                AppColors.getTextSecondary(context),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusMedium)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child:
                              const Text('Close', style: AppTextStyles.buttonMedium),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                            ),
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.telegramBlue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: token));
                              showTopSnackBar(context, 'Copied to clipboard');
                              GoRouter.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppThemes.borderRadiusMedium)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.copy_rounded, size: 18),
                                SizedBox(width: 4),
                                Text('Copy', style: AppTextStyles.buttonMedium),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildInstruction(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.telegramBlue.withValues(alpha: 0.2),
                      AppColors.telegramPurple.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle),
              child: Icon(icon, size: 12, color: AppColors.telegramBlue)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextPrimary(context)))),
        ],
      ),
    );
  }

  Widget _buildLinkedState(ParentLinkProvider provider) {
    return _buildGlassContainer(
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context, mobile: 24, tablet: 32, desktop: 40)),
        child: Column(
          children: [
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
                        gradient: RadialGradient(colors: [
                          AppColors.telegramGreen.withValues(alpha: 0.3),
                          AppColors.telegramGreen.withValues(alpha: 0.1),
                          Colors.transparent
                        ]),
                      ),
                    );
                  },
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF34C759), Color(0xFF2CAE4A)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.telegramGreen.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 32, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Parent Connected',
                style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (provider.parentTelegramUsername != null)
              _buildGlassContainer(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.telegram,
                          size: 20, color: AppColors.telegramBlue),
                      const SizedBox(width: 8),
                      Text('@${provider.parentTelegramUsername}',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramRed.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _unlinkParent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.link_off_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Disconnect Parent',
                          style: AppTextStyles.buttonMedium),
                    ],
                  ),
                ),
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
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context, mobile: 24, tablet: 32, desktop: 40)),
        child: Column(
          children: [
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
                        gradient: RadialGradient(colors: [
                          statusColor.withValues(alpha: 0.3),
                          statusColor.withValues(alpha: 0.1),
                          Colors.transparent
                        ]),
                      ),
                    );
                  },
                ),
                Container(
                  width: 64,
                  height: 64,
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
                          blurRadius: 20,
                          spreadRadius: 2),
                    ],
                  ),
                  child:
                      const Icon(Icons.timer_rounded, size: 32, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Token Active',
                style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildGlassContainer(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded, size: 20, color: statusColor),
                    const SizedBox(width: 8),
                    Text(provider.remainingTimeFormatted,
                        style: AppTextStyles.titleMedium.copyWith(
                            color: statusColor, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (provider.parentToken != null &&
                        provider.tokenExpiresAt != null) {
                      _showTokenDialog(
                          provider.parentToken!, provider.tokenExpiresAt!);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.visibility_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Show Token', style: AppTextStyles.buttonMedium),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _generateToken,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.telegramBlue,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 4),
                  Text('Generate New Token', style: AppTextStyles.buttonMedium),
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
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context, mobile: 24, tablet: 32, desktop: 40)),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
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
                  size: 32, color: AppColors.telegramBlue),
            ),
            const SizedBox(height: 16),
            Text('Connect Parent',
                style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(
              'Generate a token to link your parent\'s Telegram account and share your progress.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context), height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                  ),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _generateToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_link_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Generate Token', style: AppTextStyles.buttonMedium),
                    ],
                  ),
                ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.2),
                            AppColors.telegramPurple.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.info_rounded,
                        color: AppColors.telegramBlue, size: 20)),
                const SizedBox(width: 12),
                Text('What parents can see',
                    style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context))),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoItem(
                icon: Icons.trending_up_rounded,
                text: 'Study progress and completion'),
            _buildInfoItem(
                icon: Icons.quiz_rounded, text: 'Exam scores and results'),
            _buildInfoItem(
                icon: Icons.subscriptions_rounded, text: 'Subscription status'),
            _buildInfoItem(
                icon: Icons.calendar_month_rounded,
                text: 'Weekly progress summary'),
            const SizedBox(height: 16),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.telegram,
                            size: 20, color: AppColors.telegramBlue),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Parent Telegram Bot',
                                style: AppTextStyles.titleSmall.copyWith(
                                    color: AppColors.getTextPrimary(context),
                                    fontWeight: FontWeight.w600))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openTelegramBot(telegramBotUrl),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                telegramBotUrl!,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.telegramBlue,
                                    decoration: TextDecoration.underline),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.open_in_new,
                                size: 16, color: AppColors.telegramBlue),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Parents receive updates via Telegram. They cannot modify your account.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.getTextSecondary(context)),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.telegramGreen.withValues(alpha: 0.2),
                      AppColors.telegramGreen.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: AppColors.telegramGreen)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextPrimary(context)))),
        ],
      ),
    );
  }

  Widget _buildUserInfo(AuthProvider authProvider) {
    return _buildGlassContainer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  authProvider.currentUser!.username
                      .substring(0, 1)
                      .toUpperCase(),
                  style: AppTextStyles.titleMedium.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(authProvider.currentUser!.username,
                      style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.getTextPrimary(context))),
                  const SizedBox(height: 4),
                  Text('Student ID: ${authProvider.currentUser!.id}',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context))),
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

  Widget _buildMobileLayout(BuildContext context) {
    final parentLinkProvider = Provider.of<ParentLinkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('Parent Link',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.telegramBlue))
                : Icon(Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context)),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _refreshData,
        header: const WaterDropHeader(
          waterDropColor: AppColors.telegramBlue,
          refresh: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue))),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(ScreenSize.responsiveValue(
              context: context, mobile: 16, tablet: 20, desktop: 24)),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                  maxWidth: ScreenSize.responsiveValue(
                      context: context,
                      mobile: double.infinity,
                      tablet: 600,
                      desktop: 800)),
              child: Column(
                children: [
                  if (!_isInitialized)
                    _buildSkeletonLoader()
                  else if (parentLinkProvider.isLinked)
                    _buildLinkedState(parentLinkProvider)
                  else if (parentLinkProvider.parentToken != null &&
                      !parentLinkProvider.isTokenExpired)
                    _buildTokenState(parentLinkProvider)
                  else
                    _buildNotLinkedState(),
                  const SizedBox(height: 24),
                  _buildInfoSection(),
                  if (authProvider.currentUser != null) ...[
                    const SizedBox(height: 16),
                    _buildUserInfo(authProvider),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final parentLinkProvider = Provider.of<ParentLinkProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('Parent Link',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.telegramBlue))
                : Icon(Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context)),
            onPressed: _isRefreshing ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _refreshData,
        header: const WaterDropHeader(
          waterDropColor: AppColors.telegramBlue,
          refresh: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue))),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        if (!_isInitialized)
                          _buildSkeletonLoader()
                        else if (parentLinkProvider.isLinked)
                          _buildLinkedState(parentLinkProvider)
                        else if (parentLinkProvider.parentToken != null &&
                            !parentLinkProvider.isTokenExpired)
                          _buildTokenState(parentLinkProvider)
                        else
                          _buildNotLinkedState(),
                        if (authProvider.currentUser != null) ...[
                          const SizedBox(height: 24),
                          _buildUserInfo(authProvider),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(child: _buildInfoSection()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return _buildSkeletonLoader();

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }
}
