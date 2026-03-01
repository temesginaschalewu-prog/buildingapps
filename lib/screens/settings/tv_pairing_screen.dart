import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/device_provider.dart';
import '../../themes/app_themes.dart';
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
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => Navigator.pop(context)),
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

  Future<void> _checkDeviceStatus() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    await _checkDeviceStatus();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect Your TV',
            style: AppTextStyles.displaySmall.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Stream Family Academy content directly to your Android TV',
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.getTextSecondary(context))),
      ],
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: 0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  Widget _buildPairedDeviceCard(BuildContext context, String deviceId) {
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
                  animation: _scanAnimationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _scanAnimationController.value * 2 * 3.14159,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.3),
                            AppColors.telegramBlue.withValues(alpha: 0.1),
                            Colors.transparent
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
                      width: 80 * (1 + _pulseAnimationController.value * 0.05),
                      height: 80 * (1 + _pulseAnimationController.value * 0.05),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.2),
                            AppColors.telegramPurple.withValues(alpha: 0.1),
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
            const SizedBox(height: 24),
            Text('TV Device Paired',
                style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.telegramBlue,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildGlassContainer(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.devices_rounded,
                        size: 16, color: AppColors.getTextSecondary(context)),
                    const SizedBox(width: 8),
                    Text(_formatDeviceId(deviceId),
                        style: AppTextStyles.bodyMedium.copyWith(
                            fontFamily: 'monospace',
                            color: AppColors.getTextPrimary(context))),
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
                  onPressed: _unpairDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.link_off_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text('Unpair Device',
                          style: AppTextStyles.buttonMedium
                              .copyWith(color: Colors.white)),
                    ],
                  ),
                ),
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
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context, mobile: 24, tablet: 32, desktop: 40)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramBlue.withValues(alpha: 0.2),
                            AppColors.telegramPurple.withValues(alpha: 0.1),
                          ],
                        ),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.tv_rounded,
                        color: AppColors.telegramBlue, size: 20)),
                const SizedBox(width: 12),
                Text('Enter Pairing Code',
                    style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: '6-digit Code',
                labelStyle: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextSecondary(context)),
                hintText: 'Enter code from your TV',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color:
                        AppColors.getTextSecondary(context).withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.confirmation_number_rounded,
                    color: AppColors.getTextSecondary(context), size: 20),
                filled: true,
                fillColor: AppColors.getSurface(context).withValues(alpha: 0.3),
                border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  borderSide:
                      const BorderSide(color: AppColors.telegramBlue, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontSize: 18,
                  letterSpacing: 2),
              keyboardType: TextInputType.number,
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _pairDevice(),
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
                  onPressed: _isVerifying ? null : _pairDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                            AppThemes.borderRadiusMedium)),
                  ),
                  child: _isVerifying
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white))),
                            const SizedBox(width: 8),
                            Text('Verifying...',
                                style: AppTextStyles.buttonMedium
                                    .copyWith(color: Colors.white)),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.link_rounded, size: 20),
                            const SizedBox(width: 8),
                            Text('Pair Device',
                                style: AppTextStyles.buttonMedium
                                    .copyWith(color: Colors.white)),
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

  Widget _buildInstructionsCard(BuildContext context) {
    return _buildGlassContainer(
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context, mobile: 16, tablet: 20, desktop: 24)),
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
                        color: AppColors.telegramBlue, size: 18)),
                const SizedBox(width: 12),
                Text('How to Pair',
                    style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(
                context, 1, 'Open Family Academy on your Android TV device.'),
            _buildInstructionStep(
                context, 2, 'Go to Settings > Device Pairing.'),
            _buildInstructionStep(context, 3,
                'Note down the 6-digit pairing code displayed on your TV.'),
            _buildInstructionStep(
                context, 4, 'Enter the code above and tap "Pair Device".'),
            const SizedBox(height: 16),
            _buildGlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        color: AppColors.telegramYellow, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                          'You can only pair one TV device at a time. Unpairing will disconnect the current device.',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextPrimary(context))),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]),
            child: Center(
                child: Text(number.toString(),
                    style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w600))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.getTextPrimary(context)))),
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

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('TV Pairing',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.telegramBlue))
                : Icon(Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context)),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoader()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  if (hasTvDevice)
                    _buildPairedDeviceCard(context, deviceProvider.tvDeviceId!)
                  else
                    _buildPairingForm(context),
                  const SizedBox(height: 24),
                  _buildInstructionsCard(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildDesktopLayout() {
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final hasTvDevice = deviceProvider.tvDeviceId != null &&
        deviceProvider.tvDeviceId!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('TV Pairing',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.telegramBlue))
                : Icon(Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context)),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? _buildSkeletonLoader()
          : Center(
              child: SingleChildScrollView(
                child: AdaptiveContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildHeader(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 2,
                              child: hasTvDevice
                                  ? _buildPairedDeviceCard(
                                      context, deviceProvider.tvDeviceId!)
                                  : _buildPairingForm(context)),
                          const SizedBox(width: 32),
                          Expanded(
                              child: _buildInstructionsCard(context)),
                        ],
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildSkeletonLoader();
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildDesktopLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}
