// lib/screens/settings/tv_pairing_screen.dart
// ADDED SHIMMER TYPE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../providers/device_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_dialog.dart';
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
    with BaseScreenMixin<TvPairingScreen>, TickerProviderStateMixin {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isLoading = false;
  String? _errorMessage;

  late AnimationController _pulseAnimationController;
  late AnimationController _scanAnimationController;
  late DeviceProvider _deviceProvider;

  @override
  String get screenTitle => 'TV Pairing';

  @override
  String? get screenSubtitle => isRefreshing
      ? 'Refreshing...'
      : (isOffline ? 'Offline mode' : 'Connect your TV');

  @override
  bool get isLoading => _isLoading && !_deviceProvider.isInitialized;

  @override
  bool get hasCachedData => _deviceProvider.isInitialized;

  @override
  dynamic get errorMessage => _errorMessage;

  // ✅ Shimmer type for TV pairing
  @override
  ShimmerType get shimmerType => ShimmerType.pairingCard;

  @override
  int get shimmerItemCount => 1;

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
    _scanAnimationController = AnimationController(
      vsync: this,
      duration: 2.seconds,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deviceProvider = Provider.of<DeviceProvider>(context);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pulseAnimationController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    if (isOffline) {
      SnackbarService().showOffline(context, action: 'refresh');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = getUserFriendlyErrorMessage(e);
      });
      SnackbarService().showError(context, 'Failed to refresh');
      rethrow;
    }
  }

  Future<void> _pairDevice() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      SnackbarService().showError(context, 'Please enter the pairing code');
      return;
    }

    if (code.length != 6) {
      SnackbarService().showError(context, 'Please enter a valid 6-digit code');
      return;
    }

    if (isOffline) {
      SnackbarService().showOffline(context, action: 'pair device');
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await _deviceProvider.verifyTvPairing(code);
      SnackbarService().showSuccess(context, 'TV device paired successfully');
      _codeController.clear();
      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() => _errorMessage = getUserFriendlyErrorMessage(e));
      SnackbarService().showError(
        context,
        'Pairing failed: ${getUserFriendlyErrorMessage(e)}',
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _unpairDevice() async {
    if (isOffline) {
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
        await _deviceProvider.unpairTvDevice();
        SnackbarService().showSuccess(
          context,
          'TV device unpaired successfully',
        );
        setState(() => _errorMessage = null);
      } catch (e) {
        setState(() => _errorMessage = getUserFriendlyErrorMessage(e));
        SnackbarService().showError(
          context,
          'Unpairing failed: ${getUserFriendlyErrorMessage(e)}',
        );
      }
    }
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Your TV',
          style: AppTextStyles.displaySmall(
            context,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: ResponsiveValues.spacingS(context)),
        Text(
          'Stream Family Academy content directly to your Android TV',
          style: AppTextStyles.bodyLarge(
            context,
          ).copyWith(color: AppColors.getTextSecondary(context)),
        ),
      ],
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium)
        .slideY(begin: 0.1, end: 0, duration: AppThemes.animationMedium);
  }

  Widget _buildPairedDeviceCard(String deviceId) {
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
                              Colors.transparent,
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
                            AppColors.telegramPurple.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.telegramBlue,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        Icons.tv_rounded,
                        size: ResponsiveValues.iconSizeXXXL(context),
                        color: AppColors.telegramBlue,
                      ),
                    );
                  },
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            Text(
              'TV Device Paired',
              style: AppTextStyles.titleLarge(context).copyWith(
                color: AppColors.telegramBlue,
                fontWeight: FontWeight.w600,
              ),
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
                      Icons.devices_rounded,
                      size: ResponsiveValues.iconSizeXS(context),
                      color: AppColors.getTextSecondary(context),
                    ),
                    SizedBox(width: ResponsiveValues.spacingS(context)),
                    Text(
                      _formatDeviceId(deviceId),
                      style: AppTextStyles.bodyMedium(
                        context,
                      ).copyWith(fontFamily: 'monospace'),
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
          duration: AppThemes.animationMedium,
        );
  }

  Widget _buildPairingForm() {
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
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.tv_rounded,
                    color: AppColors.telegramBlue,
                    size: ResponsiveValues.iconSizeS(context),
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'Enter Pairing Code',
                  style: AppTextStyles.titleMedium(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
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
              enabled: !isOffline,
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

  Widget _buildInstructionsCard() {
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
                  child: Icon(
                    Icons.info_rounded,
                    color: AppColors.telegramBlue,
                    size: ResponsiveValues.iconSizeXS(context),
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Text(
                  'How to Pair',
                  style: AppTextStyles.titleSmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            _buildInstructionStep(
              1,
              'Open Family Academy on your Android TV device.',
            ),
            _buildInstructionStep(2, 'Go to Settings > Device Pairing.'),
            _buildInstructionStep(
              3,
              'Note down the 6-digit pairing code displayed on your TV.',
            ),
            _buildInstructionStep(
              4,
              'Enter the code above and tap "Pair Device".',
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            AppCard.glass(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      color: AppColors.telegramYellow,
                      size: ResponsiveValues.iconSizeS(context),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Text(
                        'You can only pair one TV device at a time. Unpairing will disconnect the current device.',
                        style: AppTextStyles.bodySmall(context).copyWith(
                          color: AppColors.getTextPrimary(context),
                        ),
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

  Widget _buildInstructionStep(int number, String text) {
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
                style: AppTextStyles.labelMedium(
                  context,
                ).copyWith(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(width: ResponsiveValues.spacingM(context)),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium(context))),
        ],
      ),
    );
  }

  String _formatDeviceId(String deviceId) {
    if (deviceId.length <= 12) return deviceId;
    return '${deviceId.substring(0, 8)}...';
  }

  @override
  Widget buildContent(BuildContext context) {
    final hasTvDevice = _deviceProvider.tvDeviceId != null &&
        _deviceProvider.tvDeviceId!.isNotEmpty;
    final tvDeviceId = _deviceProvider.tvDeviceId;

    if (_errorMessage != null && !hasTvDevice) {
      return Center(
        child: buildErrorWidget(_errorMessage!, onRetry: onRefresh),
      );
    }

    if (isLoading && !hasCachedData) {
      return Center(
        child: buildLoadingShimmer(),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.telegramBlue,
      backgroundColor: AppColors.getSurface(context),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveValues.screenPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pendingCount > 0)
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
                        '$pendingCount pending change${pendingCount > 1 ? 's' : ''}',
                        style: AppTextStyles.bodySmall(
                          context,
                        ).copyWith(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            _buildHeader(),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            if (isOffline && !hasTvDevice)
              buildOfflineWidget(
                message: 'You are offline. Please connect to pair a TV device.',
              )
            else if (hasTvDevice && tvDeviceId != null)
              _buildPairedDeviceCard(tvDeviceId)
            else
              _buildPairingForm(),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            _buildInstructionsCard(),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(
      content: buildContent(context),
      showAppBar: true,
      showRefreshIndicator: false,
    );
  }
}
