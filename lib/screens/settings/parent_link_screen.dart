import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/parent_link_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_bar.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/app_enums.dart';
import '../../widgets/common/responsive_widgets.dart';

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
  StreamSubscription? _connectivitySubscription;

  late AnimationController _pulseAnimationController;

  bool _hasCachedData = false;

  @override
  void initState() {
    super.initState();
    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);

    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _setupTimers();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) setState(() => _isOffline = !isOnline);
    });
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
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupTimers() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) _refreshDataInBackground();
    });
  }

  Future<void> _initializeData() async {
    final parentLinkProvider = context.read<ParentLinkProvider>();

    _hasCachedData = parentLinkProvider.hasLoaded;

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
      final parentLinkProvider = context.read<ParentLinkProvider>();
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      _refreshController.refreshFailed();
      SnackbarService().showOffline(context);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

    try {
      final parentLinkProvider = context.read<ParentLinkProvider>();
      await parentLinkProvider.clearCache();
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);

      setState(() => _isOffline = false);
      SnackbarService().showSuccess(context, 'Status updated');
    } catch (e) {
      setState(() => _isOffline = true);
      SnackbarService().showError(context, 'Refresh failed, using cached data');
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
      final parentLinkProvider = context.read<ParentLinkProvider>();
      await parentLinkProvider.clearCache();
      await parentLinkProvider.getParentLinkStatus(forceRefresh: true);

      _refreshController.refreshCompleted();

      if (showLoading && mounted)
        SnackbarService().showSuccess(context, 'Status updated');
    } catch (e) {
      _refreshController.refreshFailed();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _generateToken() async {
    final parentLinkProvider = context.read<ParentLinkProvider>();

    try {
      await parentLinkProvider.generateParentToken();

      final token = parentLinkProvider.parentToken;
      final expiresAt = parentLinkProvider.tokenExpiresAt;

      if (token != null && expiresAt != null) {
        _showTokenDialog(token, expiresAt);
      }
    } catch (e) {
      SnackbarService().showError(
          context, 'Failed to generate token: ${formatErrorMessage(e)}');
    }
  }

  Future<void> _unlinkParent() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Unlink Parent',
      message:
          'Are you sure you want to unlink the parent? This will stop all progress updates.',
      confirmText: 'Unlink',
    );
    if (confirmed == true) {
      final parentLinkProvider = context.read<ParentLinkProvider>();
      try {
        await parentLinkProvider.unlinkParent();
        await Future.delayed(const Duration(milliseconds: 500));
        await parentLinkProvider.getParentLinkStatus(forceRefresh: true);

        if (mounted)
          SnackbarService()
              .showSuccess(context, 'Parent unlinked successfully');
      } catch (e) {
        if (mounted)
          SnackbarService()
              .showError(context, 'Failed to unlink: ${formatErrorMessage(e)}');
      }
    }
  }

  Widget _buildSkeletonLoader() {
    return Center(
      child: AppCard.glass(
        child: Padding(
          padding: ResponsiveValues.dialogPadding(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppShimmer(type: ShimmerType.circle),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              const AppShimmer(type: ShimmerType.textLine, customWidth: 200),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              const AppShimmer(type: ShimmerType.textLine, customWidth: 250),
            ],
          ),
        ),
      ),
    );
  }

  void _showTokenDialog(String token, DateTime expiresAt) {
    AppDialog.showToken(
      context: context,
      token: token,
      expiresIn: _formatDuration(expiresAt.difference(DateTime.now())),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 1) return 'Less than a minute';
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
    return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
  }

  Widget _buildInstruction(String text, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveValues.spacingM(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ResponsiveValues.iconSizeL(context),
            height: ResponsiveValues.iconSizeL(context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.telegramBlue.withValues(alpha: 0.2),
                  AppColors.telegramPurple.withValues(alpha: 0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: ResponsiveValues.iconSizeXXS(context),
                color: AppColors.telegramBlue),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedState(ParentLinkProvider provider) {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: Column(
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
                        gradient: RadialGradient(
                          colors: [
                            AppColors.telegramGreen.withValues(alpha: 0.3),
                            AppColors.telegramGreen.withValues(alpha: 0.1),
                            Colors.transparent
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Container(
                  width: ResponsiveValues.avatarSizeLarge(context),
                  height: ResponsiveValues.avatarSizeLarge(context),
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: AppColors.successGradient),
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
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              'Parent Connected',
              style: AppTextStyles.headlineSmall(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            if (provider.parentTelegramUsername != null)
              AppCard.glass(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingL(context),
                    vertical: ResponsiveValues.spacingM(context),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.telegram,
                          size: 20, color: AppColors.telegramBlue),
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      Text(
                        '@${provider.parentTelegramUsername}',
                        style: AppTextStyles.bodyMedium(context)
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.danger(
                label: 'Disconnect Parent',
                icon: Icons.link_off_rounded,
                onPressed: _unlinkParent,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildTokenState(ParentLinkProvider provider) {
    final remainingTime = provider.remainingTime;
    final isExpiringSoon = remainingTime.inMinutes < 5;
    final statusColor =
        isExpiringSoon ? AppColors.telegramRed : AppColors.telegramBlue;

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: Column(
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
                        gradient: RadialGradient(
                          colors: [
                            statusColor.withValues(alpha: 0.3),
                            statusColor.withValues(alpha: 0.1),
                            Colors.transparent
                          ],
                        ),
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
                          ? AppColors.dangerGradient
                          : AppColors.telegramGradient,
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
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              'Token Active',
              style: AppTextStyles.headlineSmall(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            AppCard.glass(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingL(context),
                  vertical: ResponsiveValues.spacingM(context),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded,
                        size: ResponsiveValues.iconSizeS(context),
                        color: statusColor),
                    SizedBox(width: ResponsiveValues.spacingS(context)),
                    Text(
                      provider.remainingTimeFormatted,
                      style: AppTextStyles.titleMedium(context).copyWith(
                          color: statusColor, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: 'Show Token',
                icon: Icons.visibility_rounded,
                onPressed: () {
                  if (provider.parentToken != null &&
                      provider.tokenExpiresAt != null) {
                    _showTokenDialog(
                        provider.parentToken!, provider.tokenExpiresAt!);
                  }
                },
                expanded: true,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            AppButton.text(
              label: 'Generate New Token',
              icon: Icons.refresh_rounded,
              onPressed: _generateToken,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildNotLinkedState() {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: Column(
          children: [
            Container(
              width: ResponsiveValues.avatarSizeLarge(context),
              height: ResponsiveValues.avatarSizeLarge(context),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.telegramBlue.withValues(alpha: 0.2),
                    AppColors.telegramPurple.withValues(alpha: 0.1)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  size: 40, color: AppColors.telegramBlue),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              'Connect Parent',
              style: AppTextStyles.headlineSmall(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            Text(
              'Generate a token to link your parent\'s Telegram account and share your progress.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge(context).copyWith(
                  color: AppColors.getTextSecondary(context), height: 1.5),
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: 'Generate Token',
                icon: Icons.add_link_rounded,
                onPressed: _generateToken,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildInfoSection() {
    final settingsProvider = context.read<SettingsProvider>();
    final telegramBotUrl = settingsProvider.getTelegramBotUrl();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.info_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'What parents can see',
                  style: AppTextStyles.titleMedium(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildInstruction(
                'Study progress and completion', Icons.trending_up_rounded),
            _buildInstruction('Exam scores and results', Icons.quiz_rounded),
            _buildInstruction(
                'Subscription status', Icons.subscriptions_rounded),
            _buildInstruction(
                'Weekly progress summary', Icons.calendar_month_rounded),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.telegram,
                            size: 20, color: AppColors.telegramBlue),
                        SizedBox(width: ResponsiveValues.spacingM(context)),
                        Expanded(
                          child: Text(
                            'Parent Telegram Bot',
                            style: AppTextStyles.titleSmall(context)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    GestureDetector(
                      onTap: () => _openTelegramBot(telegramBotUrl!),
                      child: Container(
                        padding: ResponsiveValues.cardPadding(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
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
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    Text(
                      'Parents receive updates via Telegram. They cannot modify your account.',
                      style: AppTextStyles.bodySmall(context)
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
        .fadeIn(duration: AppThemes.animationMedium, delay: 100.ms)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Future<void> _openTelegramBot(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      SnackbarService().showError(context, 'Cannot open Telegram');
    }
  }

  Widget _buildInfoItem({required IconData icon, required String text}) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveValues.spacingM(context)),
      child: Row(
        children: [
          Container(
            width: ResponsiveValues.iconSizeL(context),
            height: ResponsiveValues.iconSizeL(context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.telegramGreen.withValues(alpha: 0.2),
                  AppColors.telegramGreen.withValues(alpha: 0.1)
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: ResponsiveValues.iconSizeXS(context),
                color: AppColors.telegramGreen),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo(AuthProvider authProvider) {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.avatarSizeMedium(context),
              height: ResponsiveValues.avatarSizeMedium(context),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppColors.blueGradient),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.telegramBlue, blurRadius: 10)
                ],
              ),
              child: Center(
                child: Text(
                  authProvider.currentUser!.username
                      .substring(0, 1)
                      .toUpperCase(),
                  style: AppTextStyles.titleMedium(context).copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingL(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authProvider.currentUser!.username,
                    style: AppTextStyles.titleSmall(context)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Text(
                    'Student ID: ${authProvider.currentUser!.id}',
                    style: AppTextStyles.bodySmall(context)
                        .copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium, delay: 200.ms);
  }

  @override
  Widget build(BuildContext context) {
    final parentLinkProvider = context.watch<ParentLinkProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (!_isInitialized && !_hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: 'Parent Link',
          subtitle: 'Loading...',
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
        ),
        body: Center(child: _buildSkeletonLoader()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: 'Parent Link',
        subtitle: _isRefreshing
            ? 'Refreshing...'
            : (_isOffline ? 'Offline mode' : 'Connect with parents'),
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
      ),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: ResponsiveValues.screenPadding(context),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (_isOffline)
                      Container(
                        margin: EdgeInsets.only(
                            bottom: ResponsiveValues.spacingL(context)),
                        padding: ResponsiveValues.cardPadding(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramYellow.withValues(alpha: 0.2),
                              AppColors.telegramYellow.withValues(alpha: 0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context)),
                          border: Border.all(
                              color: AppColors.telegramYellow
                                  .withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_off_rounded,
                                color: AppColors.telegramYellow, size: 20),
                            SizedBox(width: ResponsiveValues.spacingM(context)),
                            Expanded(
                              child: Text(
                                'Offline mode - showing cached data',
                                style: AppTextStyles.bodySmall(context)
                                    .copyWith(color: AppColors.telegramYellow),
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
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    _buildInfoSection(),
                    if (authProvider.currentUser != null) ...[
                      SizedBox(height: ResponsiveValues.spacingL(context)),
                      _buildUserInfo(authProvider),
                    ],
                    SizedBox(height: ResponsiveValues.spacingXXL(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}
