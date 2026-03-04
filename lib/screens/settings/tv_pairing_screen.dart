import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/device_provider.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/responsive_widgets.dart';
import '../../widgets/common/empty_state.dart';

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
  String _refreshSubtitle = '';

  late AnimationController _pulseAnimationController;
  late AnimationController _scanAnimationController;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);
    _scanAnimationController =
        AnimationController(vsync: this, duration: 2.seconds)..repeat();

    _checkDeviceStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pulseAnimationController.dispose();
    _scanAnimationController.dispose();
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

  Widget _buildGradientButton({
    required String label,
    required VoidCallback? onPressed,
    required List<Color> gradient,
    IconData? icon,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed != null ? LinearGradient(colors: gradient) : null,
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

  Future<void> _checkDeviceStatus() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'You are offline. Using cached data.',
          isError: true);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

    try {
      await _checkDeviceStatus();
      setState(() => _isOffline = false);
      showTopSnackBar(context, 'Device status updated');
    } catch (e) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'Refresh failed, using cached data',
          isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
      });
    }
  }

  Future<void> _pairDevice() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      showTopSnackBar(context, 'Please enter the pairing code', isError: true);
      return;
    }

    if (code.length != 6) {
      showTopSnackBar(context, 'Please enter a valid 6-digit code',
          isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await deviceProvider.verifyTvPairing(code);
      showTopSnackBar(context, 'TV device paired successfully');
      _codeController.clear();
      setState(() {});
    } catch (e) {
      showTopSnackBar(context, 'Pairing failed: ${formatErrorMessage(e)}',
          isError: true);
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  Future<void> _unpairDevice() async {
    final confirmed = await showConfirmDialog(
      context,
      'Unpair TV Device',
      'Are you sure you want to unpair your TV device? You will need to pair it again to stream content.',
      () async {
        try {
          final deviceProvider =
              Provider.of<DeviceProvider>(context, listen: false);
          await deviceProvider.unpairTvDevice();
          showTopSnackBar(context, 'TV device unpaired successfully');
          setState(() {});
        } catch (e) {
          showTopSnackBar(context, 'Unpairing failed: ${formatErrorMessage(e)}',
              isError: true);
        }
      },
    );
  }

  Widget _buildHeader() {
    return ResponsiveColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveText(
          'Connect Your TV',
          style: AppTextStyles.displaySmall(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        ResponsiveSizedBox(height: AppSpacing.s),
        ResponsiveText(
          'Stream Family Academy content directly to your Android TV',
          style: AppTextStyles.bodyLarge(context).copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildPairedDeviceCard(BuildContext context, String deviceId) {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: ResponsiveColumn(
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
                          gradient: RadialGradient(colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.3),
                            AppColors.telegramBlue.withValues(alpha: 0.1),
                            Colors.transparent,
                          ], stops: const [
                            0.2,
                            0.5,
                            1.0
                          ]),
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
                      child: const Icon(Icons.tv_rounded,
                          size: 40, color: AppColors.telegramBlue),
                    );
                  },
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.xl),
            ResponsiveText(
              'TV Device Paired',
              style: AppTextStyles.titleLarge(context).copyWith(
                color: AppColors.telegramBlue,
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
                    Icon(Icons.devices_rounded,
                        size: ResponsiveValues.iconSizeXS(context),
                        color: AppColors.getTextSecondary(context)),
                    ResponsiveSizedBox(width: AppSpacing.s),
                    ResponsiveText(
                      _formatDeviceId(deviceId),
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ResponsiveSizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: _buildGradientButton(
                label: 'Unpair Device',
                onPressed: _unpairDevice,
                gradient: AppColors.pinkGradient,
                icon: Icons.link_off_rounded,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).scale(
        begin: const Offset(0.95, 0.95),
        end: const Offset(1, 1),
        duration: AppThemes.animationDurationMedium);
  }

  Widget _buildPairingForm(BuildContext context) {
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.dialogPadding(context),
        child: ResponsiveColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ResponsiveRow(
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
                  child: const Icon(Icons.tv_rounded,
                      color: AppColors.telegramBlue, size: 20),
                ),
                ResponsiveSizedBox(width: AppSpacing.m),
                ResponsiveText(
                  'Enter Pairing Code',
                  style: AppTextStyles.titleMedium(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.xl),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: '6-digit Code',
                labelStyle: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                hintText: 'Enter code from your TV',
                hintStyle: AppTextStyles.bodyMedium(context).copyWith(
                  color: AppColors.getTextSecondary(context)
                      .withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(Icons.confirmation_number_rounded,
                    color: AppColors.getTextSecondary(context),
                    size: ResponsiveValues.iconSizeS(context)),
                filled: true,
                fillColor: AppColors.getSurface(context).withValues(alpha: 0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                  borderSide: const BorderSide(
                    color: AppColors.telegramBlue,
                    width: 2,
                  ),
                ),
                contentPadding: ResponsiveValues.listItemPadding(context),
              ),
              style: AppTextStyles.bodyLarge(context).copyWith(
                fontSize: ResponsiveValues.fontTitleLarge(context),
                letterSpacing: 2,
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _pairDevice(),
            ),
            ResponsiveSizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: _buildGradientButton(
                label: _isVerifying ? 'Verifying...' : 'Pair Device',
                onPressed: _isVerifying ? null : _pairDevice,
                gradient: AppColors.blueGradient,
                icon: _isVerifying ? null : Icons.link_rounded,
                isLoading: _isVerifying,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildInstructionsCard(BuildContext context) {
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
                      color: AppColors.telegramBlue, size: 18),
                ),
                ResponsiveSizedBox(width: AppSpacing.m),
                ResponsiveText(
                  'How to Pair',
                  style: AppTextStyles.titleSmall(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            ResponsiveSizedBox(height: AppSpacing.l),
            _buildInstructionStep(
                context, 1, 'Open Family Academy on your Android TV device.'),
            _buildInstructionStep(
                context, 2, 'Go to Settings > Device Pairing.'),
            _buildInstructionStep(context, 3,
                'Note down the 6-digit pairing code displayed on your TV.'),
            _buildInstructionStep(
                context, 4, 'Enter the code above and tap "Pair Device".'),
            ResponsiveSizedBox(height: AppSpacing.l),
            _buildGlassContainer(
              child: Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: ResponsiveRow(
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        color: AppColors.telegramYellow, size: 20),
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: ResponsiveText(
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
        .fadeIn(duration: AppThemes.animationDurationMedium, delay: 100.ms)
        .slideY(
            begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildInstructionStep(BuildContext context, int number, String text) {
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
              gradient: const LinearGradient(
                colors: AppColors.blueGradient,
              ),
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
              child: ResponsiveText(
                number.toString(),
                style: AppTextStyles.labelMedium(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
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

  String _formatDeviceId(String deviceId) {
    if (deviceId.length <= 12) return deviceId;
    return '${deviceId.substring(0, 8)}...';
  }

  Widget _buildMobileLayout() {
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final hasTvDevice = deviceProvider.tvDeviceId != null &&
        deviceProvider.tvDeviceId!.isNotEmpty;

    if (_isLoading) {
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
                            'TV Pairing',
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
                                    : 'Connect your TV'),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        _buildHeader(),
                        ResponsiveSizedBox(height: AppSpacing.l),
                        if (hasTvDevice)
                          _buildPairedDeviceCard(
                              context, deviceProvider.tvDeviceId!)
                        else
                          _buildPairingForm(context),
                        ResponsiveSizedBox(height: AppSpacing.xl),
                        _buildInstructionsCard(context),
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
