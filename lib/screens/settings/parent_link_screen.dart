import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _isPollingLinkStatus = false;
  int _pollTick = 0;

  late AnimationController _pulseAnimationController;
  late ParentLinkProvider _parentLinkProvider;
  late AuthProvider _authProvider;
  late SettingsProvider _settingsProvider;

  @override
  String get screenTitle => AppStrings.parentLink;

  @override
  String? get screenSubtitle => isRefreshing
      ? AppStrings.refreshing
      : (isOffline
          ? AppStrings.offlineMode
          : (_didInitializeProviders
              ? _settingsProvider.getParentLinkScreenSubtitle()
              : AppStrings.connectWithParents));

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
        unawaited(_settingsProvider.getAllSettings());
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

      if (_shouldPollParentLinkStatus()) {
        _pollTick++;
        if (_pollTick % 3 == 0) {
          unawaited(_pollActiveParentLinkStatus());
        }
      } else {
        _pollTick = 0;
      }
    });
  }

  bool _shouldPollParentLinkStatus() {
    return mounted &&
        !isOffline &&
        !_isLoadingData &&
        !_parentLinkProvider.isLinked &&
        _parentLinkProvider.parentToken != null &&
        !_parentLinkProvider.isTokenExpired;
  }

  Future<void> _pollActiveParentLinkStatus() async {
    if (_isPollingLinkStatus || !_shouldPollParentLinkStatus()) return;

    _isPollingLinkStatus = true;
    try {
      await _refreshData(showLoading: false);

      if (!mounted) return;

      if (_parentLinkProvider.isLinked) {
        if (_dialogOpen && Navigator.of(context, rootNavigator: true).canPop()) {
          _dialogOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
        SnackbarService().showSuccess(context, 'Parent linked successfully');
      } else if (_dialogOpen && _parentLinkProvider.isTokenExpired) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          _dialogOpen = false;
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } catch (_) {
      // Keep the current state visible and retry on the next polling interval.
    } finally {
      _isPollingLinkStatus = false;
    }
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
      if (isMounted) {
        SnackbarService().showInfo(
          context,
          'We could not refresh parent link details just now. Your current status is still shown.',
        );
      }
    }
  }

  Future<void> _refreshData({bool showLoading = true}) async {
    if (isRefreshing) return;

    if (showLoading && mounted && !_isLoadingData) {
      setState(() => _isLoadingData = true);
    }

    try {
      await _parentLinkProvider.clearCache();
      await _parentLinkProvider.getParentLinkStatus(forceRefresh: true);
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
    } finally {
      if (showLoading && mounted) {
        setState(() => _isLoadingData = false);
      }
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
                Text(
                  _settingsProvider.getParentLinkTokenMessageWithWindow(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall(context).copyWith(
                    color: AppColors.getTextSecondary(context),
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

  Widget _buildCapabilityPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(
          ResponsiveValues.radiusFull(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: ResponsiveValues.iconSizeXS(context),
            color: color,
          ),
          SizedBox(width: ResponsiveValues.spacingXS(context)),
          Flexible(
            child: Text(
              label,
              style: AppTextStyles.labelSmall(context).copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentAvatar() {
    final user = _authProvider.currentUser;
    final profileImageUrl = user?.fullProfileImageUrl ?? user?.profileImage;

    if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
      return Container(
        width: ResponsiveValues.avatarSizeLarge(context),
        height: ResponsiveValues.avatarSizeLarge(context),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.65),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: profileImageUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: AppColors.getSurface(context),
            ),
            errorWidget: (_, __, ___) => _buildStudentInitialsAvatar(),
          ),
        ),
      );
    }

    return _buildStudentInitialsAvatar();
  }

  Widget _buildStudentInitialsAvatar() {
    final username = _authProvider.currentUser?.username ?? 'S';
    return Container(
      width: ResponsiveValues.avatarSizeLarge(context),
      height: ResponsiveValues.avatarSizeLarge(context),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.blueGradient),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.substring(0, 1).toUpperCase(),
          style: AppTextStyles.headlineSmall(context).copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildLinkedState() {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStudentAvatar(),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _settingsProvider.getParentLinkConnectedTitle(),
                        style: AppTextStyles.headlineSmall(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        _settingsProvider.getParentLinkConnectedMessage(),
                        style: AppTextStyles.bodyMedium(context).copyWith(
                          color: AppColors.getTextSecondary(context),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            if (_parentLinkProvider.parentTelegramUsername != null)
              Container(
                width: double.infinity,
                padding: ResponsiveValues.cardPadding(context),
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.telegram,
                      size: ResponsiveValues.iconSizeS(context),
                      color: AppColors.telegramBlue,
                    ),
                    SizedBox(width: ResponsiveValues.spacingS(context)),
                    Expanded(
                      child: Text(
                        '@${_parentLinkProvider.parentTelegramUsername}',
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    _buildCapabilityPill(
                      icon: Icons.check_circle_rounded,
                      label: _settingsProvider.getParentLinkLiveBadge(),
                      color: AppColors.telegramGreen,
                    ),
                  ],
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: ResponsiveValues.avatarSizeLarge(context),
                  height: ResponsiveValues.avatarSizeLarge(context),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_rounded,
                    size: ResponsiveValues.iconSizeXXXL(context),
                    color: statusColor,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExpiringSoon
                            ? AppStrings.tokenExpiringSoon
                            : AppStrings.tokenActive,
                        style: AppTextStyles.headlineSmall(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        _settingsProvider.getParentLinkTokenMessageWithWindow(),
                        style: AppTextStyles.bodyMedium(context).copyWith(
                          color: AppColors.getTextSecondary(context),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingL(context),
                vertical: ResponsiveValues.spacingM(context),
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusMedium(context),
                ),
              ),
              child: Row(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStudentAvatar(),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _settingsProvider.getParentLinkTitle(),
                        style: AppTextStyles.headlineSmall(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        _settingsProvider.getParentLinkDescription(),
                        style: AppTextStyles.bodyMedium(context).copyWith(
                          color: AppColors.getTextSecondary(context),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusMedium(context),
                ),
              ),
              child: Text(
                _settingsProvider.getParentLinkActiveWindowMessage(),
                style: AppTextStyles.bodySmall(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.45,
                ),
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
                  _settingsProvider.getParentLinkBenefitsTitle(),
                  style: AppTextStyles.titleMedium(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildInstruction(
              _settingsProvider.getParentLinkBenefitsSummary(),
              Icons.insights_rounded,
            ),
            _buildInstruction(
              _settingsProvider.getParentLinkBenefitsUpdates(),
              Icons.notifications_active_rounded,
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
                            _settingsProvider.getParentLinkBotTitle(),
                            style: AppTextStyles.titleSmall(
                              context,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveValues.spacingS(context)),
                    GestureDetector(
                      onTap: telegramBotUrl != null
                          ? () => _openTelegramBot(telegramBotUrl)
                          : null,
                      child: Container(
                        padding: ResponsiveValues.cardPadding(context),
                        decoration: BoxDecoration(
                          color: AppColors.telegramBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                telegramBotUrl ??
                                    _settingsProvider
                                        .getParentLinkBotFallbackMessage(),
                                style:
                                    AppTextStyles.bodySmall(context).copyWith(
                                  color: telegramBotUrl != null
                                      ? AppColors.telegramBlue
                                      : AppColors.getTextSecondary(context),
                                  decoration: telegramBotUrl != null
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (telegramBotUrl != null)
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
                      _settingsProvider.getParentLinkBotDescription(),
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                        height: 1.45,
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

  @override
  Widget buildContent(BuildContext context) {
    if (_isLoadingData && !_parentLinkProvider.isLoaded) {
      return buildBrandedLoadingState(
        title: _settingsProvider.getParentLinkLoadingTitle(),
        message: _settingsProvider.getParentLinkLoadingMessage(),
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
                  if (_parentLinkProvider.isLinked)
                    _buildLinkedState()
                  else if (_parentLinkProvider.parentToken != null &&
                      !_parentLinkProvider.isTokenExpired)
                    _buildTokenState()
                  else
                    _buildNotLinkedState(),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  _buildInfoSection(),
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
