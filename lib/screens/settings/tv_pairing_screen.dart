import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../providers/device_provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../../widgets/common/loading_indicator.dart';
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

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

    _scanAnimationController = AnimationController(
      vsync: this,
      duration: 2.seconds,
    )..repeat();

    _checkDeviceStatus();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _pulseAnimationController.dispose();
    _scanAnimationController.dispose();
    super.dispose();
  }

  Future<void> _checkDeviceStatus() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      debugLog('TvPairingScreen', 'Error checking device status: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    await _checkDeviceStatus();
  }

  Future<void> _pairDevice() async {
    final deviceProvider = Provider.of<DeviceProvider>(context, listen: false);
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      showSnackBar(context, 'Please enter the pairing code', isError: true);
      return;
    }

    if (code.length != 6) {
      showSnackBar(context, 'Please enter a valid 6-digit code', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      await deviceProvider.verifyTvPairing(code);

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('TV device paired successfully'),
          backgroundColor: AppColors.telegramGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          margin: EdgeInsets.all(AppThemes.spacingL),
        ),
      );

      _codeController.clear();
      setState(() {});
    } catch (e) {
      showSnackBar(context, 'Pairing failed: ${formatErrorMessage(e)}',
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

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('TV device unpaired successfully'),
              backgroundColor: AppColors.telegramGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
              ),
              margin: EdgeInsets.all(AppThemes.spacingL),
            ),
          );

          setState(() {});
        } catch (e) {
          showSnackBar(context, 'Unpairing failed: ${formatErrorMessage(e)}',
              isError: true);
        }
      },
    );
  }

  // 📱 Mobile Layout
  Widget _buildMobileLayout() {
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final hasTvDevice = deviceProvider.tvDeviceId != null &&
        deviceProvider.tvDeviceId!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'TV Pairing',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.telegramBlue,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context),
                  ),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: LoadingIndicator(
                message: 'Checking device status...',
                type: LoadingType.circular,
                color: AppColors.telegramBlue,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppThemes.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),

                  SizedBox(height: AppThemes.spacingL),

                  // Main Card
                  if (hasTvDevice)
                    _buildPairedDeviceCard(context, deviceProvider.tvDeviceId!)
                  else
                    _buildPairingForm(context),

                  SizedBox(height: AppThemes.spacingXL),

                  // Instructions
                  _buildInstructionsCard(context),

                  SizedBox(height: AppThemes.spacingXXL),
                ],
              ),
            ),
    );
  }

  // 💻 Desktop/Tablet Layout
  Widget _buildDesktopLayout() {
    final deviceProvider = Provider.of<DeviceProvider>(context);
    final hasTvDevice = deviceProvider.tvDeviceId != null &&
        deviceProvider.tvDeviceId!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'TV Pairing',
          style: AppTextStyles.appBarTitle.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.telegramBlue,
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: AppColors.getTextSecondary(context),
                  ),
            onPressed: _isLoading ? null : _refreshData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: LoadingIndicator(
                message: 'Checking device status...',
                type: LoadingType.circular,
                color: AppColors.telegramBlue,
              ),
            )
          : Center(
              child: SingleChildScrollView(
                child: AdaptiveContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: AppThemes.spacingXL),

                      // Header
                      _buildHeader(),

                      SizedBox(height: AppThemes.spacingXL),

                      // Two Column Layout
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Card
                          Expanded(
                            flex: 2,
                            child: hasTvDevice
                                ? _buildPairedDeviceCard(
                                    context, deviceProvider.tvDeviceId!)
                                : _buildPairingForm(context),
                          ),

                          SizedBox(width: AppThemes.spacingXXL),

                          // Instructions
                          Expanded(
                            flex: 1,
                            child: _buildInstructionsCard(context),
                          ),
                        ],
                      ),

                      SizedBox(height: AppThemes.spacingXXXL),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // 🏷️ Header
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect Your TV',
          style: AppTextStyles.displaySmall.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: AppThemes.spacingXS),
        Text(
          'Stream Family Academy content directly to your Android TV',
          style: AppTextStyles.bodyLarge.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
      ],
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  // 📺 Paired Device Card
  Widget _buildPairedDeviceCard(BuildContext context, String deviceId) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingXL,
        tablet: AppThemes.spacingXXL,
        desktop: AppThemes.spacingXXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // Animated TV icon
          Stack(
            alignment: Alignment.center,
            children: [
              // Scanning animation
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
                        gradient: RadialGradient(
                          colors: [
                            AppColors.telegramBlue.withOpacity(0.3),
                            AppColors.telegramBlue.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          stops: const [0.2, 0.5, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Main icon
              AnimatedBuilder(
                animation: _pulseAnimationController,
                builder: (context, child) {
                  return Container(
                    width: 80 * (1 + _pulseAnimationController.value * 0.05),
                    height: 80 * (1 + _pulseAnimationController.value * 0.05),
                    decoration: BoxDecoration(
                      color: AppColors.telegramBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.telegramBlue,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      Icons.tv_rounded,
                      size: 40,
                      color: AppColors.telegramBlue,
                    ),
                  );
                },
              ),
            ],
          ),

          SizedBox(height: AppThemes.spacingXL),

          Text(
            'TV Device Paired',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.telegramBlue,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: AppThemes.spacingM),

          // Device ID
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppThemes.spacingL,
              vertical: AppThemes.spacingM,
            ),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.devices_rounded,
                  size: 16,
                  color: AppColors.getTextSecondary(context),
                ),
                SizedBox(width: AppThemes.spacingS),
                Text(
                  _formatDeviceId(deviceId),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppThemes.spacingXL),

          // Unpair button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _unpairDevice,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.telegramRed,
                side: BorderSide(color: AppColors.telegramRed),
                padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link_off_rounded, size: 20),
                  SizedBox(width: AppThemes.spacingS),
                  Text(
                    'Unpair Device',
                    style: AppTextStyles.buttonMedium.copyWith(
                      color: AppColors.telegramRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
        )
        .scale(
          begin: Offset(0.95, 0.95),
          end: Offset(1, 1),
          duration: AppThemes.animationDurationMedium,
        );
  }

  // 🔢 Pairing Form
  Widget _buildPairingForm(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingXL,
        tablet: AppThemes.spacingXXL,
        desktop: AppThemes.spacingXXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.tv_rounded,
                  color: AppColors.telegramBlue,
                  size: 20,
                ),
              ),
              SizedBox(width: AppThemes.spacingM),
              Text(
                'Enter Pairing Code',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          SizedBox(height: AppThemes.spacingXL),

          // Code input
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: '6-digit Code',
              labelStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              hintText: 'Enter code from your TV',
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context).withOpacity(0.5),
              ),
              prefixIcon: Icon(
                Icons.confirmation_number_rounded,
                color: AppColors.getTextSecondary(context),
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.getSurface(context),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
                borderSide: BorderSide(
                  color: AppColors.telegramBlue,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusMedium),
                borderSide: BorderSide(
                  color: AppColors.telegramRed,
                  width: 1,
                ),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppThemes.spacingL,
                vertical: AppThemes.spacingM,
              ),
            ),
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.getTextPrimary(context),
              fontSize: 18,
              letterSpacing: 2,
            ),
            keyboardType: TextInputType.number,
            maxLength: 6,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _pairDevice(),
          ),

          SizedBox(height: AppThemes.spacingXL),

          // Pair button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _pairDevice,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.telegramBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.getTextSecondary(context).withOpacity(0.3),
                padding: EdgeInsets.symmetric(vertical: AppThemes.spacingL),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                elevation: 0,
              ),
              child: _isVerifying
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: AppThemes.spacingS),
                        Text(
                          'Verifying...',
                          style: AppTextStyles.buttonMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.link_rounded, size: 20),
                        SizedBox(width: AppThemes.spacingS),
                        Text(
                          'Pair Device',
                          style: AppTextStyles.buttonMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  // 📋 Instructions Card
  Widget _buildInstructionsCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
        context: context,
        mobile: AppThemes.spacingL,
        tablet: AppThemes.spacingXL,
        desktop: AppThemes.spacingXXL,
      )),
      decoration: BoxDecoration(
        color: AppColors.getCard(context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_rounded,
                  color: AppColors.telegramBlue,
                  size: 18,
                ),
              ),
              SizedBox(width: AppThemes.spacingM),
              Text(
                'How to Pair',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          SizedBox(height: AppThemes.spacingL),

          // Steps
          _buildInstructionStep(
            context,
            1,
            'Open Family Academy on your Android TV device.',
          ),
          _buildInstructionStep(
            context,
            2,
            'Go to Settings > Device Pairing.',
          ),
          _buildInstructionStep(
            context,
            3,
            'Note down the 6-digit pairing code displayed on your TV.',
          ),
          _buildInstructionStep(
            context,
            4,
            'Enter the code above and tap "Pair Device".',
          ),

          SizedBox(height: AppThemes.spacingL),

          // Tip
          Container(
            padding: EdgeInsets.all(AppThemes.spacingL),
            decoration: BoxDecoration(
              color: AppColors.telegramYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              border: Border.all(
                color: AppColors.telegramYellow,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  color: AppColors.telegramYellow,
                  size: 20,
                ),
                SizedBox(width: AppThemes.spacingM),
                Expanded(
                  child: Text(
                    'You can only pair one TV device at a time. Unpairing will disconnect the current device.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: 100.ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  Widget _buildInstructionStep(BuildContext context, int number, String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.telegramBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDeviceId(String deviceId) {
    if (deviceId.length <= 12) {
      return deviceId;
    }
    return '${deviceId.substring(0, 8)}...';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildDesktopLayout(),
      desktop: _buildDesktopLayout(),
      animateTransition: true,
    );
  }
}
