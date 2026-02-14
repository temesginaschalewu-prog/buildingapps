import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:badges/badges.dart' as badges;
import 'package:pull_to_refresh/pull_to_refresh.dart';

import 'package:familyacademyclient/providers/settings_provider.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:familyacademyclient/widgets/common/error_widget.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:familyacademyclient/utils/constants.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;
  final List<RefreshController> _refreshControllers = [];
  bool _isRefreshing = false;

  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: 1.seconds,
    )..repeat(reverse: true);

    _tabController = TabController(length: 3, vsync: this);
    _refreshControllers.addAll([
      RefreshController(), // Contact tab
      RefreshController(), // FAQ tab
      RefreshController(), // Actions tab
    ]);
    _loadContactSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseAnimationController.dispose();
    for (var controller in _refreshControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // UPDATED: _loadContactSettings with better logging and error handling
  Future<void> _loadContactSettings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      debugLog('SupportScreen', '🔄 Loading contact settings...');

      // First try to load ALL settings (this will now fetch everything)
      await settingsProvider.getAllSettings();
      debugLog('SupportScreen', '✅ getAllSettings completed');

      // Then specifically ensure contact settings are loaded
      await settingsProvider.loadContactSettings(forceRefresh: true);
      debugLog('SupportScreen', '✅ loadContactSettings completed');

      final contactInfo = settingsProvider.getContactInfoList();
      debugLog('SupportScreen', '📞 Contact info items: ${contactInfo.length}');

      // Log each contact item
      for (final info in contactInfo) {
        debugLog('SupportScreen', '   - ${info.title}: "${info.value}"');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugLog('SupportScreen', '❌ Error loading settings: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _refreshData(int tabIndex) async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      // Force refresh all settings
      await settingsProvider.getAllSettings();
      await settingsProvider.loadContactSettings(forceRefresh: true);

      _refreshControllers[tabIndex].refreshCompleted();
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });

      // Show success feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Support information refreshed'),
          backgroundColor: AppColors.telegramGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          margin: EdgeInsets.all(AppThemes.spacingL),
        ),
      );
    } catch (e) {
      debugLog('SupportScreen', 'Refresh error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
      _refreshControllers[tabIndex].refreshFailed();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refresh failed: $e'),
          backgroundColor: AppColors.telegramRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
          ),
          margin: EdgeInsets.all(AppThemes.spacingL),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _handleContactTap(
      ContactType type, String value, BuildContext context) async {
    final Uri uri;

    switch (type) {
      case ContactType.phone:
        uri = Uri.parse('tel:$value');
        break;
      case ContactType.email:
        uri = Uri.parse('mailto:$value');
        break;
      case ContactType.whatsapp:
        final cleanNumber = value.replaceAll(RegExp(r'[^0-9+]'), '');
        uri = Uri.parse('https://wa.me/$cleanNumber');
        break;
      case ContactType.telegram:
        final username = value.replaceAll('@', '');
        uri = Uri.parse('https://t.me/$username');
        break;
      case ContactType.address:
        final encodedAddress = Uri.encodeComponent(value);
        uri = Uri.parse('https://maps.google.com/?q=$encodedAddress');
        break;
      case ContactType.hours:
        return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      showSnackBar(context, 'Cannot open $value', isError: true);
    }
  }

  // 🎨 Contact Card - Redesigned with Telegram style
  Widget _buildContactCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    ContactType type, {
    Color? iconColor,
    Color? backgroundColor,
    int index = 0,
  }) {
    final canTap = type != ContactType.hours;
    final color = iconColor ?? _getIconColorForType(type, context);
    final bgColor = backgroundColor ?? _getBgColorForType(type, context);

    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? () => _handleContactTap(type, value, context) : null,
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
          splashColor: color.withOpacity(0.1),
          highlightColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(
              ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
            ),
            decoration: BoxDecoration(
              color: AppColors.getCard(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
              border: Border.all(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Icon with colored background
                Container(
                  width: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 48,
                    tablet: 52,
                    desktop: 56,
                  ),
                  height: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 48,
                    tablet: 52,
                    desktop: 56,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                    border: Border.all(
                      color: color,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 24,
                      tablet: 26,
                      desktop: 28,
                    ),
                    color: color,
                  ),
                ),

                SizedBox(width: AppThemes.spacingL),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.getTextSecondary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        value,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (canTap) ...[
                        SizedBox(height: AppThemes.spacingS),
                        Row(
                          children: [
                            Text(
                              type == ContactType.address
                                  ? 'View on map'
                                  : 'Tap to contact',
                              style: AppTextStyles.caption.copyWith(
                                color: color,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.open_in_new_rounded,
                              size: 12,
                              color: color,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Right arrow for tappable items
                if (canTap)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.getTextSecondary(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  // ❓ FAQ Item - Redesigned with Telegram style
  Widget _buildFAQItem(BuildContext context, String question, String answer,
      {int index = 0}) {
    return Container(
      margin: EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getCard(context),
            borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              expansionTileTheme: ExpansionTileThemeData(
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                iconColor: AppColors.telegramBlue,
                collapsedIconColor: AppColors.telegramBlue,
                textColor: AppColors.getTextPrimary(context),
                collapsedTextColor: AppColors.getTextPrimary(context),
              ),
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.symmetric(
                horizontal: ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
                vertical: 4,
              ),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_rounded,
                  size: 18,
                  color: AppColors.telegramBlue,
                ),
              ),
              title: Text(
                question,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w500,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(
                    ScreenSize.responsiveValue(
                      context: context,
                      mobile: AppThemes.spacingL,
                      tablet: AppThemes.spacingXL,
                      desktop: AppThemes.spacingXXL,
                    ),
                  ),
                  child: Text(
                    answer,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.6,
                    ),
                  ),
                ),
                SizedBox(height: AppThemes.spacingM),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  // ⚡ Quick Action Card - Redesigned with Telegram style
  Widget _buildQuickActionCard(BuildContext context, String title,
      String subtitle, IconData icon, VoidCallback onTap, Color? color,
      {int index = 0}) {
    final actionColor = color ?? AppColors.telegramBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        splashColor: actionColor.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(
            ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL,
            ),
          ),
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
              // Icon with colored background
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                  border: Border.all(
                    color: actionColor,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: actionColor,
                ),
              ),

              SizedBox(height: AppThemes.spacingL),

              // Title
              Text(
                title,
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),

              SizedBox(height: 4),

              // Subtitle
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        )
        .scale(
          begin: Offset(0.95, 0.95),
          end: Offset(1, 1),
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  // 📞 Response Time Card
  Widget _buildResponseTimeCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppThemes.spacingL),
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
          // Animated 24h badge
          AnimatedBuilder(
            animation: _pulseAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1 + _pulseAnimationController.value * 0.05,
                child: badges.Badge(
                  badgeContent: Text(
                    '24H',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.telegramGreen,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppThemes.spacingM,
                      vertical: AppThemes.spacingXS,
                    ),
                  ),
                  child: Icon(
                    Icons.timer_rounded,
                    size: 36,
                    color: AppColors.telegramGreen,
                  ),
                ),
              );
            },
          ),

          SizedBox(height: AppThemes.spacingL),

          Text(
            'Quick Response',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.getTextPrimary(context),
            ),
          ),

          SizedBox(height: AppThemes.spacingS),

          Text(
            'We typically respond within 24 hours during business days',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  // 🕒 Support Hours Card
  Widget _buildSupportHoursCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppThemes.spacingL),
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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.access_time_rounded,
                color: AppColors.telegramBlue,
                size: 20,
              ),
              SizedBox(width: AppThemes.spacingS),
              Text(
                'Support Hours',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ],
          ),

          SizedBox(height: AppThemes.spacingL),

          // Weekdays
          _buildHoursRow(
            day: 'Monday - Friday',
            hours: '9:00 AM - 6:00 PM',
          ),

          SizedBox(height: AppThemes.spacingM),

          // Saturday
          _buildHoursRow(
            day: 'Saturday',
            hours: '10:00 AM - 4:00 PM',
          ),

          SizedBox(height: AppThemes.spacingM),

          // Sunday
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppThemes.spacingM,
                  vertical: AppThemes.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusFull),
                  border: Border.all(
                    color: AppColors.telegramRed,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Sunday - Closed',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.telegramRed,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium);
  }

  Widget _buildHoursRow({required String day, required String hours}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        Text(
          hours,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // 📌 Section Header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: AppThemes.spacingL,
        top: AppThemes.spacingXL,
      ),
      child: Text(
        title,
        style: AppTextStyles.titleLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.getTextPrimary(context),
        ),
      ),
    );
  }

  // 🎨 Color helpers
  Color _getIconColorForType(ContactType type, BuildContext context) {
    switch (type) {
      case ContactType.phone:
        return AppColors.telegramGreen;
      case ContactType.email:
        return AppColors.telegramBlue;
      case ContactType.whatsapp:
        return AppColors.telegramGreen;
      case ContactType.telegram:
        return AppColors.telegramBlue;
      case ContactType.address:
        return AppColors.telegramYellow;
      case ContactType.hours:
        return AppColors.telegramYellow;
      default:
        return AppColors.telegramBlue;
    }
  }

  Color _getBgColorForType(ContactType type, BuildContext context) {
    switch (type) {
      case ContactType.phone:
        return AppColors.telegramGreen.withOpacity(0.1);
      case ContactType.email:
        return AppColors.telegramBlue.withOpacity(0.1);
      case ContactType.whatsapp:
        return AppColors.telegramGreen.withOpacity(0.1);
      case ContactType.telegram:
        return AppColors.telegramBlue.withOpacity(0.1);
      case ContactType.address:
        return AppColors.telegramYellow.withOpacity(0.1);
      case ContactType.hours:
        return AppColors.telegramYellow.withOpacity(0.1);
      default:
        return AppColors.telegramBlue.withOpacity(0.1);
    }
  }

  // 📱 Mobile Layout
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Support',
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
          onPressed: () => GoRouter.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
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
            onPressed:
                _isRefreshing ? null : () => _refreshData(_tabController.index),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.telegramBlue,
          indicatorWeight: 3,
          labelColor: AppColors.telegramBlue,
          unselectedLabelColor: AppColors.getTextSecondary(context),
          labelStyle: AppTextStyles.labelMedium,
          unselectedLabelStyle: AppTextStyles.labelMedium,
          tabs: const [
            Tab(text: 'Contact'),
            Tab(text: 'FAQ'),
            Tab(text: 'Actions'),
          ],
        ),
      ),
      body: _buildBody(context),
    );
  }

  // 💻 Desktop/Tablet Layout
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Support',
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
          onPressed: () => GoRouter.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: _isRefreshing
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
            onPressed:
                _isRefreshing ? null : () => _refreshData(_tabController.index),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildDesktopBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading && !_isRefreshing) {
      return Center(
        child: LoadingIndicator(
          message: 'Loading support information...',
          type: LoadingType.circular,
          color: AppColors.telegramBlue,
        ),
      );
    }

    if (_hasError) {
      return ErrorState(
        title: 'Failed to Load',
        message: _errorMessage ?? 'Unable to load support information.',
        actionText: 'Retry',
        onAction: _loadContactSettings,
      );
    }

    final settingsProvider = Provider.of<SettingsProvider>(context);

    if (ScreenSize.isMobile(context)) {
      return TabBarView(
        controller: _tabController,
        children: [
          _buildContactTab(context, settingsProvider),
          _buildFAQTab(context),
          _buildActionsTab(context),
        ],
      );
    } else {
      return _buildDesktopBody(context);
    }
  }

  Widget _buildContactTab(BuildContext context, SettingsProvider settings) {
    final contactInfo = settings.getContactInfoList();

    return SmartRefresher(
      controller: _refreshControllers[0],
      onRefresh: () => _refreshData(0),
      enablePullDown: true,
      enablePullUp: false,
      header: WaterDropHeader(
        waterDropColor: AppColors.telegramBlue,
        refresh: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
          ),
        ),
      ),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppThemes.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Contact Information'),
                  ...contactInfo
                      .asMap()
                      .entries
                      .map((entry) => _buildContactCard(
                            context,
                            entry.value.title,
                            entry.value.value,
                            entry.value.icon,
                            entry.value.type,
                            index: entry.key,
                          )),
                  SizedBox(height: AppThemes.spacingXXL),
                  _buildSectionHeader('Response Time'),
                  _buildResponseTimeCard(context),
                  SizedBox(height: AppThemes.spacingXXXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab(BuildContext context) {
    const faqs = [
      {
        'question': 'How do I reset my password?',
        'answer':
            'Please contact support using the phone or email provided. We will verify your identity and reset your password for you.',
      },
      {
        'question': 'Why is my payment not verified?',
        'answer':
            'Payments are manually verified by our admin team. This usually takes 24-48 hours. Ensure your payment proof includes transaction ID and is clearly visible.',
      },
      {
        'question': 'Can I change my device?',
        'answer':
            'Yes, you can change your device but it requires a device change payment. Go to Profile → Device Settings to initiate the process.',
      },
      {
        'question': 'How do I access paid content?',
        'answer':
            'First, make a payment for the category you want to access. Once your payment is verified, all content in that category will be unlocked.',
      },
      {
        'question': 'What happens when my subscription expires?',
        'answer':
            'You will lose access to paid content in that category. You can renew your subscription before it expires to maintain continuous access.',
      },
      {
        'question': 'How do I link my parent account?',
        'answer':
            'Go to Profile → Parent Link to generate a unique code. Share this code with your parent through Telegram to complete the linking process.',
      },
    ];

    return SmartRefresher(
      controller: _refreshControllers[1],
      onRefresh: () => _refreshData(1),
      enablePullDown: true,
      enablePullUp: false,
      header: WaterDropHeader(
        waterDropColor: AppColors.telegramBlue,
        refresh: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
          ),
        ),
      ),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppThemes.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Frequently Asked Questions'),
                  ...faqs.asMap().entries.map((entry) => _buildFAQItem(
                        context,
                        entry.value['question']!,
                        entry.value['answer']!,
                        index: entry.key,
                      )),
                  SizedBox(height: AppThemes.spacingXXL),
                  _buildSectionHeader('Still Need Help?'),
                  Container(
                    padding: EdgeInsets.all(AppThemes.spacingL),
                    decoration: BoxDecoration(
                      color: AppColors.getCard(context),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusLarge),
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.support_agent_rounded,
                          size: 48,
                          color: AppColors.telegramBlue,
                        ),
                        SizedBox(height: AppThemes.spacingL),
                        Text(
                          'Contact Us Directly',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        SizedBox(height: AppThemes.spacingS),
                        Text(
                          'If your question isn\'t answered here, please reach out to our support team using the contact information provided.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppThemes.spacingXXXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsTab(BuildContext context) {
    return SmartRefresher(
      controller: _refreshControllers[2],
      onRefresh: () => _refreshData(2),
      enablePullDown: true,
      enablePullUp: false,
      header: WaterDropHeader(
        waterDropColor: AppColors.telegramBlue,
        refresh: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
          ),
        ),
      ),
      child: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppThemes.spacingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Quick Actions'),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: ScreenSize.isMobile(context) ? 2 : 3,
                    crossAxisSpacing: AppThemes.spacingL,
                    mainAxisSpacing: AppThemes.spacingL,
                    childAspectRatio: 1.0,
                    children: [
                      _buildQuickActionCard(
                        context,
                        'Feedback',
                        'Share your suggestions',
                        Icons.feedback_rounded,
                        () => _handleContactTap(ContactType.email,
                            'feedback@familyacademy.com', context),
                        AppColors.telegramGreen,
                        index: 1,
                      ),
                      _buildQuickActionCard(
                        context,
                        'Business',
                        'Business inquiries',
                        Icons.business_center_rounded,
                        () => _handleContactTap(ContactType.email,
                            'business@familyacademy.com', context),
                        AppColors.telegramBlue,
                        index: 2,
                      ),
                      if (!ScreenSize.isMobile(context)) ...[
                        _buildQuickActionCard(
                          context,
                          'Call Now',
                          'Speak with support',
                          Icons.call_rounded,
                          () => _handleContactTap(
                              ContactType.phone, '+251911223355', context),
                          AppColors.telegramGreen,
                          index: 3,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: AppThemes.spacingXXL),
                  _buildSectionHeader('Support Hours'),
                  _buildSupportHoursCard(context),
                  SizedBox(height: AppThemes.spacingXXXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final contactInfo = settingsProvider.getContactInfoList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: AdaptiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppThemes.spacingXL),

            // Hero Banner
            Container(
              padding: EdgeInsets.all(
                ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.blueGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(AppThemes.borderRadiusLarge),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 36,
                      tablet: 40,
                      desktop: 44,
                    ),
                    color: Colors.white,
                  ),
                  SizedBox(width: AppThemes.spacingL),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'We\'re Here to Help',
                          style: AppTextStyles.headlineMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Get help with your account, payments, subscriptions, or any other questions.',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppThemes.spacingXXL),

            // Two Column Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column - Contact Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Contact Information'),
                      ...contactInfo
                          .asMap()
                          .entries
                          .map((entry) => _buildContactCard(
                                context,
                                entry.value.title,
                                entry.value.value,
                                entry.value.icon,
                                entry.value.type,
                                index: entry.key,
                              )),
                      SizedBox(height: AppThemes.spacingXXL),
                      _buildSectionHeader('Response Time'),
                      _buildResponseTimeCard(context),
                    ],
                  ),
                ),

                SizedBox(width: AppThemes.spacingXXL),

                // Right Column - Quick Actions & Hours
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Quick Actions'),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: AppThemes.spacingL,
                        mainAxisSpacing: AppThemes.spacingL,
                        childAspectRatio: 1.0,
                        children: [
                          _buildQuickActionCard(
                            context,
                            'Feedback',
                            'Share your suggestions',
                            Icons.feedback_rounded,
                            () => _handleContactTap(ContactType.email,
                                'feedback@familyacademy.com', context),
                            AppColors.telegramGreen,
                            index: 1,
                          ),
                          _buildQuickActionCard(
                            context,
                            'Business',
                            'Business inquiries',
                            Icons.business_center_rounded,
                            () => _handleContactTap(ContactType.email,
                                'business@familyacademy.com', context),
                            AppColors.telegramBlue,
                            index: 2,
                          ),
                          _buildQuickActionCard(
                            context,
                            'Call Now',
                            'Speak with support',
                            Icons.call_rounded,
                            () => _handleContactTap(
                                ContactType.phone, '+251911223355', context),
                            AppColors.telegramGreen,
                            index: 3,
                          ),
                        ],
                      ),
                      SizedBox(height: AppThemes.spacingXXL),
                      _buildSectionHeader('Support Hours'),
                      _buildSupportHoursCard(context),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: AppThemes.spacingXXL),

            // FAQ Section (Full Width)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Frequently Asked Questions'),
                ...const [
                  {
                    'question': 'How do I reset my password?',
                    'answer':
                        'Please contact support using the phone or email provided. We will verify your identity and reset your password for you.',
                  },
                  {
                    'question': 'Why is my payment not verified?',
                    'answer':
                        'Payments are manually verified by our admin team. This usually takes 24-48 hours. Ensure your payment proof includes transaction ID and is clearly visible.',
                  },
                  {
                    'question': 'Can I change my device?',
                    'answer':
                        'Yes, you can change your device but it requires a device change payment. Go to Profile → Device Settings to initiate the process.',
                  },
                  {
                    'question': 'How do I access paid content?',
                    'answer':
                        'First, make a payment for the category you want to access. Once your payment is verified, all content in that category will be unlocked.',
                  },
                  {
                    'question': 'What happens when my subscription expires?',
                    'answer':
                        'You will lose access to paid content in that category. You can renew your subscription before it expires to maintain continuous access.',
                  },
                  {
                    'question': 'How do I link my parent account?',
                    'answer':
                        'Go to Profile → Parent Link to generate a unique code. Share this code with your parent through Telegram to complete the linking process.',
                  },
                ].asMap().entries.map((entry) => _buildFAQItem(
                      context,
                      entry.value['question']!,
                      entry.value['answer']!,
                      index: entry.key,
                    )),
              ],
            ),

            SizedBox(height: AppThemes.spacingXXXL),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isRefreshing) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            'Support',
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: Text(
            'Support',
            style: AppTextStyles.appBarTitle.copyWith(
              color: AppColors.getTextPrimary(context),
            ),
          ),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: AppColors.getTextPrimary(context),
            ),
            onPressed: () => GoRouter.of(context).pop(),
          ),
        ),
        body: ErrorState(
          title: 'Failed to Load',
          message: _errorMessage ?? 'Unable to load support information.',
          actionText: 'Retry',
          onAction: _loadContactSettings,
        ),
      );
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
      animateTransition: true,
    );
  }
}
