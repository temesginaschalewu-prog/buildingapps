import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/device_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/refresh_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_dialog.dart';
import '../../widgets/common/app_bar.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';

class TvPairingScreen extends StatefulWidget {
  const TvPairingScreen({super.key});

  @override
  State<TvPairingScreen> createState() => _TvPairingScreenState();
}

class _TvPairingScreenState extends State<TvPairingScreen>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isOffline = false;
  int _pendingCount = 0;
  StreamSubscription? _connectivitySubscription;

  late AnimationController _pulseAnimationController;
  late AnimationController _scanAnimationController;

  bool _hasCachedData = false;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);
    _scanAnimationController =
        AnimationController(vsync: this, duration: 2.seconds)..repeat();

    _checkDeviceStatus();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          _pendingCount = connectivityService.pendingActionsCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pulseAnimationController.dispose();
    _scanAnimationController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkDeviceStatus() async {
    if (_isLoading) return;

    final deviceProvider = context.read<DeviceProvider>();
    _hasCachedData = deviceProvider.isInitialized;

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    final success = await RefreshService().executeRefresh(
      context: context,
      refreshFunction: () async {
        await _checkDeviceStatus();
        if (mounted) setState(() => _isOffline = false);
      },
      successMessage: 'Device status updated',
    );

    if (!success && mounted) setState(() => _isOffline = true);

    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _pairDevice() async {
    final deviceProvider = context.read<DeviceProvider>();
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      SnackbarService().showError(context, 'Please enter the pairing code');
      return;
    }

    if (code.length != 6) {
      SnackbarService().showError(context, 'Please enter a valid 6-digit code');
      return;
    }

    final connectivity = ConnectivityService();
    if (!connectivity.isOnline) {
      SnackbarService().showOffline(context, action: 'pair device');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await deviceProvider.verifyTvPairing(code);
      SnackbarService().showSuccess(context, 'TV device paired successfully');
      _codeController.clear();
      setState(() {});
    } catch (e) {
      SnackbarService()
          .showError(context, 'Pairing failed: ${formatErrorMessage(e)}');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _unpairDevice() async {
    final connectivity = ConnectivityService();
    if (!connectivity.isOnline) {
      SnackbarService().showOffline(context, action: 'unpair device');
      return;
    }

    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Unpair TV Device',
      message:
          'Are you sure you want to unpair your TV device? You will need to pair it again to stream content.',
      confirmText: 'Unpair',
    );

    if (confirmed == true) {
      try {
        final deviceProvider = context.read<DeviceProvider>();
        await deviceProvider.unpairTvDevice();
        SnackbarService()
            .showSuccess(context, 'TV device unpaired successfully');
        setState(() {});
      } catch (e) {
        SnackbarService()
            .showError(context, 'Unpairing failed: ${formatErrorMessage(e)}');
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Your TV',
          style: AppTextStyles.displaySmall(context)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        Text(
          'Stream Family Academy content directly to your Android TV',
          style: AppTextStyles.bodyLarge(context)
              .copyWith(color: AppColors.getTextSecondary(context)),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildPairedDeviceCard(BuildContext context, String deviceId) {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _scanAnimationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _scanAnimationController.value * 2 * 3.14159,
                      child: Container(
                        width: ResponsiveValues.avatarSizeLarge(context) * 1.5,
                        height: ResponsiveValues.avatarSizeLarge(context) * 1.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.3),
                              AppColors.telegramBlue.withValues(alpha: 0.1),
                              Colors.transparent
                            ],
                            stops: const [0.2, 0.5, 1.0],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                AnimatedBuilder(
                  animation: _pulseAnimationController,
                  builder: (context, child) {
                    return Container(
                      width: ResponsiveValues.avatarSizeLarge(context) *
                          (1 + _pulseAnimationController.value * 0.05),
                      height: ResponsiveValues.avatarSizeLarge(context) *
                          (1 + _pulseAnimationController.value * 0.05),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.2),
                            AppColors.telegramPurple.withValues(alpha: 0.1)
                          ],
                        ),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: AppColors.telegramBlue, width: 3),
                      ),
                      child: const Icon(Icons.tv_rounded,
                          size: 40, color: AppColors.telegramBlue),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            Text(
              'TV Device Paired',
              style: AppTextStyles.titleLarge(context).copyWith(
                  color: AppColors.telegramBlue, fontWeight: FontWeight.w600),
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
                    Icon(Icons.devices_rounded,
                        size: ResponsiveValues.iconSizeXS(context),
                        color: AppColors.getTextSecondary(context)),
                    SizedBox(width: ResponsiveValues.spacingS(context)),
                    Text(
                      _formatDeviceId(deviceId),
                      style: AppTextStyles.bodyMedium(context)
                          .copyWith(fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.danger(
                label: 'Unpair Device',
                icon: Icons.link_off_rounded,
                onPressed: _unpairDevice,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium).scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1, 1),
        duration: AppThemes.animationMedium);
  }

  Widget _buildPairingForm(BuildContext context) {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context),
                  height: ResponsiveValues.iconSizeXL(context),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tv_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'Enter Pairing Code',
                  style: AppTextStyles.titleMedium(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            AppTextField(
              controller: _codeController,
              label: '6-digit Code',
              hint: 'Enter code from your TV',
              prefixIcon: Icons.confirmation_number_rounded,
              maxLength: 6,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              enabled: !_isOffline,
              requiresOnline: true,
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                label: _isVerifying ? 'Verifying...' : 'Pair Device',
                icon: _isVerifying ? null : Icons.link_rounded,
                onPressed: _isVerifying ? null : _pairDevice,
                isLoading: _isVerifying,
                expanded: true,
                requiresOnline: true,
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

  Widget _buildInstructionsCard(BuildContext context) {
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
                      color: AppColors.telegramBlue, size: 18),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'How to Pair',
                  style: AppTextStyles.titleSmall(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildInstructionStep(
                context, 1, 'Open Family Academy on your Android TV device.'),
            _buildInstructionStep(
                context, 2, 'Go to Settings > Device Pairing.'),
            _buildInstructionStep(context, 3,
                'Note down the 6-digit pairing code displayed on your TV.'),
            _buildInstructionStep(
                context, 4, 'Enter the code above and tap "Pair Device".'),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        color: AppColors.telegramYellow, size: 20),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Text(
                        'You can only pair one TV device at a time. Unpairing will disconnect the current device.',
                        style: AppTextStyles.bodySmall(context)
                            .copyWith(color: AppColors.getTextPrimary(context)),
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

  Widget _buildInstructionStep(BuildContext context, int number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: ResponsiveValues.spacingM(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: ResponsiveValues.iconSizeL(context),
            height: ResponsiveValues.iconSizeL(context),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: AppColors.blueGradient),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.telegramBlue.withValues(alpha: 0.3),
                  blurRadius: ResponsiveValues.spacingXS(context),
                  offset: Offset(0, ResponsiveValues.spacingXXS(context)),
                ),
              ],
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: AppTextStyles.labelMedium(context)
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium(context)),
          ),
        ],
      ),
    );
  }

  String _formatDeviceId(String deviceId) {
    if (deviceId.length <= 12) return deviceId;
    return '${deviceId.substring(0, 8)}...';
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();

    final bool hasTvDevice = deviceProvider.tvDeviceId != null &&
        deviceProvider.tvDeviceId!.isNotEmpty;
    final String? tvDeviceId = deviceProvider.tvDeviceId;

    if (_isLoading && !_hasCachedData) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: 'TV Pairing',
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
        title: 'TV Pairing',
        subtitle: _isRefreshing
            ? 'Refreshing...'
            : (_isOffline ? 'Offline mode' : 'Connect your TV'),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pendingCount > 0)
                      Container(
                        margin: EdgeInsets.only(
                            bottom: ResponsiveValues.spacingL(context)),
                        padding: ResponsiveValues.cardPadding(context),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.info.withValues(alpha: 0.2),
                              AppColors.info.withValues(alpha: 0.1)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context)),
                          border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule_rounded,
                                color: AppColors.info, size: 20),
                            SizedBox(width: ResponsiveValues.spacingM(context)),
                            Expanded(
                              child: Text(
                                '$_pendingCount pending change${_pendingCount > 1 ? 's' : ''}',
                                style: AppTextStyles.bodySmall(context)
                                    .copyWith(color: AppColors.info),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildHeader(),
                    SizedBox(height: ResponsiveValues.spacingL(context)),
                    if (hasTvDevice && tvDeviceId != null)
                      _buildPairedDeviceCard(context, tvDeviceId)
                    else
                      _buildPairingForm(context),
                    SizedBox(height: ResponsiveValues.spacingXL(context)),
                    _buildInstructionsCard(context),
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
