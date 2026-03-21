// lib/screens/settings/parent_link_screen.dart
// PRODUCTION STANDARD - NO FULL SCREEN SHIMMER - FIXED LATE INIT

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:url_launcher/url_launcher.dart';

import '../../providers/parent_link_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_dialog.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class ParentLinkScreen extends StatefulWidget {
  const ParentLinkScreen({super.key});

  @override
  State<ParentLinkScreen> createState() => _ParentLinkScreenState();
}

class _ParentLinkScreenState extends State<ParentLinkScreen>
    with
        BaseScreenMixin<ParentLinkScreen>,
        TickerProviderStateMixin,
        WidgetsBindingObserver {
  Timer? _refreshTimer;
  final RefreshController _refreshController = RefreshController();
  bool _dialogOpen = false;
  bool _isLoadingData = true;
  bool _didInitializeProviders = false;

  late AnimationController _pulseAnimationController;
  late ParentLinkProvider _parentLinkProvider;
  late AuthProvider _authProvider;
  late SettingsProvider _settingsProvider;

  @override
  String get screenTitle => AppStrings.parentLink;

  @override
  String? get screenSubtitle => isRefreshing
      ? AppStrings.refreshing
      : (isOffline ? AppStrings.offlineMode : AppStrings.connectWithParents);

  // ✅ Override isLoading to return false - we handle loading manually
  @override
  bool get isLoading => false;

  @override
  bool get hasCachedData => true;

  @override
  dynamic get errorMessage => null;

  @override
  Widget? get appBarLeading => IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: AppColors.getTextPrimary(context),
        ),
        onPressed: () => context.pop(),
      );

  @override
  void initState() {
    super.initState();
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeProviders) return;

    _parentLinkProvider = context.read<ParentLinkProvider>();
    _authProvider = context.read<AuthProvider>();
    _settingsProvider = context.read<SettingsProvider>();

    _setupTimers();
    _didInitializeProviders = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (mounted && !_isLoadingData) {
      setState(() => _isLoadingData = true);
    }
    await _parentLinkProvider.getParentLinkStatus();

    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseAnimationController.dispose();
    _refreshController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupTimers() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isMounted) {
        setState(() {}); // Update countdown every second
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isOffline) {
      _refreshData(showLoading: false);
    }
  }

  @override
  Future<void> onRefresh() async {
    if (isOffline) {
      _refreshController.refreshFailed();
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      return;
    }

    try {
      await _parentLinkProvider.clearCache();
      await _parentLinkProvider.getParentLinkStatus(forceRefresh: true);
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
      rethrow;
    }
  }

  Future<void> _refreshData({bool showLoading = true}) async {
    if (isRefreshing) return;

    try {
      await _parentLinkProvider.clearCache();
      await _parentLinkProvider.getParentLinkStatus(forceRefresh: true);
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    }
  }

  Future<void> _generateToken() async {
    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.generateToken);
      return;
    }

    try {
      await _parentLinkProvider.generateParentToken();
      final token = _parentLinkProvider.parentToken;
      if (token != null) {
        _showTokenDialog(token);
      }
    } catch (e) {
      SnackbarService().showError(
        context,
        '${AppStrings.failedToGenerateToken}: ${getUserFriendlyErrorMessage(e)}',
      );
    }
  }

  Future<void> _unlinkParent() async {
    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.unlinkParent);
      return;
    }

    final confirmed = await AppDialog.confirm(
      context: context,
      title: AppStrings.unlinkParent,
      message: AppStrings.unlinkParentConfirm,
      confirmText: AppStrings.unlink,
    );

    if (confirmed == true) {
      try {
        await _parentLinkProvider.unlinkParent();
        await Future.delayed(const Duration(milliseconds: 500));
        await _parentLinkProvider.getParentLinkStatus(forceRefresh: true);

        if (isMounted) {
          SnackbarService().showSuccess(context, AppStrings.parentUnlinked);
        }
      } catch (e) {
        if (isMounted) {
          SnackbarService().showError(
            context,
            '${AppStrings.failedToUnlink}: ${getUserFriendlyErrorMessage(e)}',
          );
        }
      }
    }
  }

  void _showTokenDialog(String token) {
    if (_dialogOpen) return;
    _dialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        ResponsiveValues.spacingM(context),
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.blueGradient,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.link_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingL(context)),
                    Expanded(
                      child: Text(
                        AppStrings.linkToken,
                        style: AppTextStyles.titleMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Container(
                  padding: ResponsiveValues.cardPadding(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.1),
                        AppColors.telegramPurple.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    border: Border.all(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: SelectableText(
                    token,
                    style: TextStyle(
                      fontSize: ResponsiveValues.fontTitleLarge(context),
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      color: AppColors.telegramBlue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Consumer<ParentLinkProvider>(
                  builder: (context, provider, _) {
                    final remaining = provider.remainingTime;
                    final isExpired = provider.isTokenExpired;

                    return Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingM(context),
                        vertical: ResponsiveValues.spacingXS(context),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.telegramYellow.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusFull(context),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_rounded,
                            size: ResponsiveValues.iconSizeXS(context),
                            color: AppColors.telegramYellow,
                          ),
                          SizedBox(width: ResponsiveValues.spacingXS(context)),
                          Text(
                            isExpired
                                ? AppStrings.expired
                                : '${AppStrings.expiresIn}: ${_formatDuration(remaining)}',
                            style: AppTextStyles.labelSmall(context).copyWith(
                              color: isExpired
                                  ? AppColors.telegramRed
                                  : AppColors.telegramYellow,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.outline(
                        label: AppStrings.close,
                        onPressed: () {
                          _dialogOpen = false;
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: AppButton.primary(
                        label: AppStrings.copy,
                        icon: Icons.copy_rounded,
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: token));
                          if (isMounted) {
                            SnackbarService().showSuccess(
                              context,
                              AppStrings.tokenCopied,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _dialogOpen = false;
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 0) return AppStrings.expired;
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds} ${AppStrings.seconds}';
    }
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} ${duration.inMinutes > 1 ? AppStrings.minutes : AppStrings.minute}';
    }
    return '${duration.inHours} ${duration.inHours > 1 ? AppStrings.hours : AppStrings.hour}';
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
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium(context))),
        ],
      ),
    );
  }

  Widget _buildLinkedState() {
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
                            Colors.transparent,
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
                    gradient: const LinearGradient(
                      colors: AppColors.successGradient,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.telegramGreen.withValues(
                          alpha: 0.3,
                        ),
                        blurRadius: ResponsiveValues.spacingXL(context),
                        spreadRadius: ResponsiveValues.spacingXS(context),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: ResponsiveValues.iconSizeXXXL(context),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              AppStrings.parentConnected,
              style: AppTextStyles.headlineSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            if (_parentLinkProvider.parentTelegramUsername != null)
              AppCard.glass(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingL(context),
                    vertical: ResponsiveValues.spacingM(context),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.telegram,
                        size: ResponsiveValues.iconSizeS(context),
                        color: AppColors.telegramBlue,
                      ),
                      SizedBox(width: ResponsiveValues.spacingS(context)),
                      Text(
                        '@${_parentLinkProvider.parentTelegramUsername}',
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.danger(
                label: AppStrings.disconnectParent,
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

  Widget _buildTokenState() {
    final remainingTime = _parentLinkProvider.remainingTime;
    final isExpired = _parentLinkProvider.isTokenExpired;
    final isExpiringSoon = remainingTime.inMinutes < 5 && !isExpired;
    final statusColor = isExpired
        ? AppColors.telegramRed
        : (isExpiringSoon ? AppColors.telegramOrange : AppColors.telegramBlue);

    if (isExpired) {
      return _buildNotLinkedState();
    }

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
                            Colors.transparent,
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
                          ? AppColors.orangeGradient
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
                  child: const Icon(
                    Icons.timer_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              isExpiringSoon
                  ? AppStrings.tokenExpiringSoon
                  : AppStrings.tokenActive,
              style: AppTextStyles.headlineSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
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
                    Icon(
                      Icons.timer_rounded,
                      size: ResponsiveValues.iconSizeS(context),
                      color: statusColor,
                    ),
                    SizedBox(width: ResponsiveValues.spacingS(context)),
                    Text(
                      _parentLinkProvider.remainingTimeFormatted,
                      style: AppTextStyles.titleMedium(context).copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: AppStrings.showToken,
                icon: Icons.visibility_rounded,
                onPressed: () {
                  if (_parentLinkProvider.parentToken != null &&
                      _parentLinkProvider.tokenExpiresAt != null) {
                    _showTokenDialog(_parentLinkProvider.parentToken!);
                  }
                },
                expanded: true,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            AppButton.text(
              label: AppStrings.generateNewToken,
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
                    AppColors.telegramPurple.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 40,
                color: AppColors.telegramBlue,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              AppStrings.connectParent,
              style: AppTextStyles.headlineSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            Text(
              AppStrings.connectParentDescription,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge(context).copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.5,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: AppStrings.generateToken,
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
    final telegramBotUrl = _settingsProvider.getTelegramBotUrl();

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
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: AppColors.telegramBlue,
                    size: 20,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  AppStrings.whatParentsCanSee,
                  style: AppTextStyles.titleMedium(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildInstruction(
              AppStrings.parentSeeProgress,
              Icons.trending_up_rounded,
            ),
            _buildInstruction(
              AppStrings.parentSeeExams,
              Icons.quiz_rounded,
            ),
            _buildInstruction(
              AppStrings.parentSeeSubscriptions,
              Icons.subscriptions_rounded,
            ),
            _buildInstruction(
              AppStrings.parentSeeWeeklySummary,
              Icons.calendar_month_rounded,
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.telegram,
                          size: 20,
                          color: AppColors.telegramBlue,
                        ),
                        SizedBox(width: ResponsiveValues.spacingM(context)),
                        Expanded(
                          child: Text(
                            AppStrings.parentTelegramBot,
                            style: AppTextStyles.titleSmall(
                              context,
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    GestureDetector(
                      onTap: () => _openTelegramBot(telegramBotUrl),
                      child: Container(
                        padding: ResponsiveValues.cardPadding(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(
                                alpha: 0.1,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
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
                            const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: AppColors.telegramBlue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    Text(
                      AppStrings.parentTelegramDescription,
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
        .fadeIn(duration: AppThemes.animationMedium, delay: 100.ms)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Future<void> _openTelegramBot(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      SnackbarService().showError(context, AppStrings.cannotOpenTelegram);
    }
  }

  Widget _buildUserInfo() {
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
                  BoxShadow(color: AppColors.telegramBlue, blurRadius: 10),
                ],
              ),
              child: Center(
                child: Text(
                  _authProvider.currentUser!.username
                      .substring(0, 1)
                      .toUpperCase(),
                  style: AppTextStyles.titleMedium(
                    context,
                  ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingL(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _authProvider.currentUser!.username,
                    style: AppTextStyles.titleSmall(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXS(context)),
                  Text(
                    '${AppStrings.studentId}: ${_authProvider.currentUser!.id}',
                    style: AppTextStyles.bodySmall(
                      context,
                    ).copyWith(color: AppColors.getTextSecondary(context)),
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
  Widget buildContent(BuildContext context) {
    // ✅ Show a small loading indicator while loading (not full screen shimmer)
    if (_isLoadingData && !_parentLinkProvider.isLoaded) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.telegramBlue),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              'Loading...',
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    // ✅ Show content immediately once loaded
    return RefreshIndicator(
      onRefresh: onRefresh,
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
                  if (isOffline && pendingCount > 0)
                    Container(
                      margin: EdgeInsets.only(
                        bottom: ResponsiveValues.spacingL(context),
                      ),
                      padding: ResponsiveValues.cardPadding(context),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.info.withValues(alpha: 0.2),
                            AppColors.info.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                        border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: AppColors.info,
                            size: ResponsiveValues.iconSizeS(context),
                          ),
                          SizedBox(width: ResponsiveValues.spacingM(context)),
                          Expanded(
                            child: Text(
                              '$pendingCount pending action${pendingCount > 1 ? 's' : ''}',
                              style: AppTextStyles.bodySmall(
                                context,
                              ).copyWith(color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_parentLinkProvider.isLinked)
                    _buildLinkedState()
                  else if (_parentLinkProvider.parentToken != null &&
                      !_parentLinkProvider.isTokenExpired)
                    _buildTokenState()
                  else
                    _buildNotLinkedState(),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  _buildInfoSection(),
                  if (_authProvider.currentUser != null) ...[
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                    _buildUserInfo(),
                  ],
                  SizedBox(height: ResponsiveValues.spacingXXL(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showRefreshIndicator: false,
    );
  }
}
