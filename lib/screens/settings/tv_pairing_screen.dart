import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/device_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_dialog.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

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

  late DeviceProvider _deviceProvider;
  late SettingsProvider _settingsProvider;

  @override
  String get screenTitle => AppStrings.tvPairing;

  @override
  String? get screenSubtitle => isRefreshing
      ? AppStrings.refreshing
      : (isOffline ? AppStrings.offlineMode : AppStrings.connectYourTv);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _deviceProvider = Provider.of<DeviceProvider>(context);
    _settingsProvider = Provider.of<SettingsProvider>(context);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Future<void> onRefresh() async {
    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.refresh);
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
      SnackbarService().showError(context, AppStrings.refreshFailed);
    }
  }

  Future<void> _pairDevice() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      SnackbarService().showError(context, AppStrings.enterPairingCode);
      return;
    }

    if (code.length != 6) {
      SnackbarService().showError(context, AppStrings.validSixDigitCode);
      return;
    }

    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.pairDevice);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await _deviceProvider.verifyTvPairing(code);
      SnackbarService().showSuccess(
        context,
        AppStrings.tvDevicePairedSuccessfully,
      );
      _codeController.clear();
      setState(() => _errorMessage = null);
    } catch (e) {
      setState(() => _errorMessage = getUserFriendlyErrorMessage(e));
      SnackbarService().showError(
        context,
        'Could not pair this TV: ${getUserFriendlyErrorMessage(e)}',
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _unpairDevice() async {
    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.unpairDevice);
      return;
    }

    final confirmed = await AppDialog.confirm(
      context: context,
      title: AppStrings.unpairTvDeviceTitle,
      message: AppStrings.unpairTvDeviceConfirm,
      confirmText: AppStrings.unlink,
    );

    if (confirmed == true) {
      try {
        await _deviceProvider.unpairTvDevice();
        SnackbarService().showSuccess(
          context,
          AppStrings.tvDeviceUnpairedSuccessfully,
        );
        setState(() => _errorMessage = null);
      } catch (e) {
        setState(() => _errorMessage = getUserFriendlyErrorMessage(e));
        SnackbarService().showError(
          context,
          '${AppStrings.unpairingFailed}: ${getUserFriendlyErrorMessage(e)}',
        );
      }
    }
  }

  Widget _buildHeader() {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.connectYourTv,
              style: AppTextStyles.headlineSmall(context).copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingXS(context)),
            Text(
              'Pair one Android TV device to watch your courses on a larger screen.',
              style: AppTextStyles.bodyMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.45,
              ),
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingM(context),
                vertical: ResponsiveValues.spacingM(context),
              ),
              decoration: BoxDecoration(
                color: (isOffline
                        ? AppColors.telegramYellow
                        : AppColors.telegramBlue)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusMedium(context),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.tv_rounded,
                    size: ResponsiveValues.iconSizeS(context),
                    color: isOffline
                        ? AppColors.telegramYellow
                        : AppColors.telegramBlue,
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: Text(
                      isOffline
                          ? 'TV pairing needs an internet connection, but your saved device status is still shown here.'
                          : 'Only one TV stays paired at a time for a cleaner viewing setup.',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPairedDeviceCard(String deviceId) {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: Column(
          children: [
            Container(
              width: ResponsiveValues.avatarSizeLarge(context),
              height: ResponsiveValues.avatarSizeLarge(context),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.telegramBlue.withValues(alpha: 0.12),
              ),
              child: Icon(
                Icons.tv_rounded,
                size: ResponsiveValues.iconSizeXXXL(context),
                color: AppColors.telegramBlue,
              ),
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
            SizedBox(height: ResponsiveValues.spacingS(context)),
            Text(
              'Ready to stream on your paired device.',
              style: AppTextStyles.bodySmall(context).copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveValues.spacingXL(context)),
            SizedBox(
              width: double.infinity,
              child: AppButton.danger(
                label: 'Unlink TV',
                icon: Icons.link_off_rounded,
                onPressed: _unpairDevice,
                expanded: true,
              ),
            ),
          ],
        ),
      ),
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
                    color: AppColors.telegramBlue.withValues(alpha: 0.1),
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
    );
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
                    color: AppColors.telegramBlue.withValues(alpha: 0.1),
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
            Container(
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                color: AppColors.telegramYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusMedium(context),
                ),
                border: Border.all(
                  color: AppColors.telegramYellow.withValues(alpha: 0.2),
                ),
              ),
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
                      'Your pairing code stays active for ${_settingsProvider.getDevicePairingWindowText()}. Only one TV can stay paired at a time.',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              color: AppColors.telegramBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: AppTextStyles.labelMedium(
                  context,
                ).copyWith(
                  color: AppColors.telegramBlue,
                  fontWeight: FontWeight.w700,
                ),
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
            _buildHeader(),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            if (hasTvDevice && tvDeviceId != null)
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
    );
  }
}
