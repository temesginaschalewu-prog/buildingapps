import 'dart:async';
import 'package:familyacademyclient/widgets/common/app_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:badges/badges.dart' as badges;
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:url_launcher/url_launcher.dart';
import '../../providers/settings_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/app_dialog.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';

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
  bool _isOffline = false;
  int _pendingCount = 0;
  StreamSubscription? _connectivitySubscription;

  late AnimationController _pulseAnimationController;

  @override
  void initState() {
    super.initState();

    _pulseAnimationController =
        AnimationController(vsync: this, duration: 1.seconds)
          ..repeat(reverse: true);

    _tabController = TabController(length: 3, vsync: this);

    _refreshControllers.addAll(
        [RefreshController(), RefreshController(), RefreshController()]);

    _checkConnectivity();
    _checkPendingCount();
    _loadContactSettings();
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

  Future<void> _checkPendingCount() async {
    final connectivity = ConnectivityService();
    setState(() => _pendingCount = connectivity.pendingActionsCount);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseAnimationController.dispose();
    for (var controller in _refreshControllers) {
      controller.dispose();
    }
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() {
      _isOffline = !connectivityService.isOnline;
      _pendingCount = connectivityService.pendingActionsCount;
    });
  }

  Future<void> _loadContactSettings() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.getAllSettings();
    if (!mounted) return;
      await settingsProvider.loadContactSettings(forceRefresh: true);
    if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _manualRefresh(int tabIndex) async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context);
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final settingsProvider = context.read<SettingsProvider>();
      await settingsProvider.getAllSettings();
    if (!mounted) return;
      await settingsProvider.loadContactSettings(forceRefresh: true);
    if (!mounted) return;

      _refreshControllers[tabIndex].refreshCompleted();
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _isOffline = false;
      });

      SnackbarService().showSuccess(context, 'Support information refreshed');
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
      _refreshControllers[tabIndex].refreshFailed();
      SnackbarService().showError(context, 'Refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleContactTap(
      ContactType type, String value, BuildContext context) async {
    final Uri uri;

    switch (type) {
      case ContactType.phone:
        final cleanNumber = value.replaceAll(RegExp(r'[^0-9+]'), '');
        uri = Uri.parse('tel:$cleanNumber');
        break;
      case ContactType.email:
        uri = Uri.parse('mailto:$value');
        break;
      case ContactType.whatsapp:
        final cleanNumber = value.replaceAll(RegExp(r'[^0-9+]'), '');
        if (cleanNumber.isNotEmpty) {
          uri = Uri.parse('https://wa.me/$cleanNumber');
        } else if (value.contains('wa.me')) {
          uri = Uri.parse(value);
        } else {
          uri = Uri.parse('https://wa.me/${value.replaceAll('+', '')}');
        }
        break;
      case ContactType.telegram:
        if (value.contains('t.me')) {
          uri = Uri.parse(value);
        } else {
          final username = value
              .replaceAll('@', '')
              .replaceAll('https://', '')
              .replaceAll('http://', '');
          uri = Uri.parse('https://t.me/$username');
        }
        break;
      case ContactType.website:
        final url = value.startsWith('http') ? value : 'https://$value';
        uri = Uri.parse(url);
        break;
      case ContactType.social:
        final url = value.startsWith('http') ? value : 'https://$value';
        uri = Uri.parse(url);
        break;
      case ContactType.address:
        final encodedAddress = Uri.encodeComponent(value);
        uri = Uri.parse('https://maps.google.com/?q=$encodedAddress');
        break;
      case ContactType.hours:
        return;
      case ContactType.other:
        if (value.startsWith('http') || value.contains('.')) {
          final url = value.startsWith('http') ? value : 'https://$value';
          uri = Uri.parse(url);
        } else {
          _showCopyDialog(context, value);
          return;
        }
        break;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
      } else {
        if (type == ContactType.other || type == ContactType.website) {
          _showCopyDialog(context, value);
        } else {
          SnackbarService().showError(context, 'Cannot open $value');
        }
      }
    } catch (e) {
      _showCopyDialog(context, value);
    }
  }

  void _showCopyDialog(BuildContext context, String value) {
    AppDialog.input(
      context: context,
      title: 'Copy to Clipboard',
      initialValue: value,
      hintText: value,
      confirmText: 'Copy',
    ).then((_) {
      Clipboard.setData(ClipboardData(text: value));
      SnackbarService().showSuccess(context, 'Copied to clipboard');
    });
  }

  Widget _buildContactCard(BuildContext context, String title, String value,
      IconData icon, ContactType type,
      {Color? iconColor, int index = 0}) {
    final canTap = type != ContactType.hours;
    final color = iconColor ?? _getIconColorForType(type, context);

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
      child: AppCard.contact(
        accentColor: color,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap && !_isOffline
                ? () => _handleContactTap(type, value, context)
                : null,
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            splashColor: color.withValues(alpha: 0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Row(
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeXL(context) * 1.5,
                    height: ResponsiveValues.iconSizeXL(context) * 1.5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.05)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context)),
                      border: Border.all(color: color, width: 1.5),
                    ),
                    child: Center(
                      child: Icon(icon,
                          size: ResponsiveValues.iconSizeL(context),
                          color: _isOffline ? AppColors.warning : color),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.labelMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: AppTextStyles.bodyMedium(context)
                              .copyWith(fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (canTap && !_isOffline) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                type == ContactType.address
                                    ? 'View on map'
                                    : type == ContactType.other
                                        ? 'Tap to copy'
                                        : 'Tap to contact',
                                style: AppTextStyles.caption(context)
                                    .copyWith(color: color),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                type == ContactType.other
                                    ? Icons.copy_rounded
                                    : Icons.open_in_new_rounded,
                                size: ResponsiveValues.iconSizeXXS(context),
                                color: color,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (canTap && !_isOffline)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: ResponsiveValues.iconSizeS(context),
                      color: AppColors.getTextSecondary(context),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium, delay: (index * 50).ms)
        .slideX(
            begin: 0.1,
            end: 0,
            duration: AppThemes.animationMedium,
            delay: (index * 50).ms);
  }

  Widget _buildQuickActionCard(BuildContext context, String title,
      String subtitle, IconData icon, VoidCallback onTap, Color color,
      {int index = 0}) {
    return AppCard.glass(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isOffline ? null : onTap,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Container(
            padding: ResponsiveValues.cardPadding(context),
            height: 140,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.05)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(icon,
                        size: ResponsiveValues.iconSizeS(context),
                        color: _isOffline ? AppColors.warning : color),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: AppTextStyles.titleSmall(context)
                      .copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium, delay: (index * 50).ms)
        .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1, 1),
            duration: AppThemes.animationMedium,
            delay: (index * 50).ms);
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer,
      {int index = 0}) {
    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
      child: AppCard.glass(
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
            tilePadding: ResponsiveValues.listItemPadding(context),
            leading: Container(
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
              child: const Icon(Icons.help_rounded,
                  size: 18, color: AppColors.telegramBlue),
            ),
            title: Text(
              question,
              style: AppTextStyles.titleSmall(context)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
            children: [
              Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Text(
                  answer,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context), height: 1.6),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppThemes.animationMedium, delay: (index * 50).ms)
        .slideY(
            begin: 0.1,
            end: 0,
            duration: AppThemes.animationMedium,
            delay: (index * 50).ms);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingM(context),
        top: ResponsiveValues.spacingXL(context),
      ),
      child: Text(
        title,
        style: AppTextStyles.titleLarge(context)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

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
      case ContactType.website:
        return AppColors.telegramBlue;
      case ContactType.social:
        return AppColors.telegramBlue;
      case ContactType.other:
        return AppColors.telegramBlue;
    }
  }

  Widget _buildContactTab(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final contactInfo = settingsProvider.getContactInfoList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingL(context),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
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
              _buildSectionHeader('Contact Information'),
              if (contactInfo.isEmpty)
                AppCard.glass(
                  child: Padding(
                    padding: ResponsiveValues.dialogPadding(context),
                    child: Column(
                      children: [
                        Icon(
                          Icons.contact_support_rounded,
                          size: ResponsiveValues.iconSizeXXL(context),
                          color: AppColors.getTextSecondary(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No contact information available',
                          style: AppTextStyles.bodyLarge(context).copyWith(
                              color: AppColors.getTextSecondary(context)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Contact methods will appear here when configured by admin',
                          style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.getTextSecondary(context)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...contactInfo.asMap().entries.map((entry) => _buildContactCard(
                      context,
                      entry.value.title,
                      entry.value.value,
                      entry.value.icon,
                      entry.value.type,
                      index: entry.key,
                    )),
              const SizedBox(height: 24),
              _buildSectionHeader('Response Time'),
              _buildResponseTimeCard(context),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQTab(BuildContext context) {
    const faqs = [
      {
        'question': 'How do I reset my password?',
        'answer':
            'Please contact support using the phone or email provided. We will verify your identity and reset your password for you.'
      },
      {
        'question': 'Why is my payment not verified?',
        'answer':
            'Payments are manually verified by our admin team. This usually takes 24-48 hours. Ensure your payment proof includes transaction ID and is clearly visible.'
      },
      {
        'question': 'Can I change my device?',
        'answer':
            'Yes, you can change your device but it requires a device change payment. Go to Profile → Device Settings to initiate the process.'
      },
      {
        'question': 'How do I access paid content?',
        'answer':
            'First, make a payment for the category you want to access. Once your payment is verified, all content in that category will be unlocked.'
      },
      {
        'question': 'What happens when my subscription expires?',
        'answer':
            'You will lose access to paid content in that category. You can renew your subscription before it expires to maintain continuous access.'
      },
      {
        'question': 'How do I link my parent account?',
        'answer':
            'Go to Profile → Parent Link to generate a unique code. Share this code with your parent through Telegram to complete the linking process.'
      },
    ];

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingL(context),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader('Frequently Asked Questions'),
              ...faqs.asMap().entries.map((entry) => _buildFAQItem(
                  context, entry.value['question']!, entry.value['answer']!,
                  index: entry.key)),
              const SizedBox(height: 24),
              _buildSectionHeader('Still Need Help?'),
              AppCard.glass(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: Column(
                    children: [
                      const Icon(Icons.support_agent_rounded,
                          size: 48, color: AppColors.telegramBlue),
                      const SizedBox(height: 16),
                      Text(
                        'Contact Us Directly',
                        style: AppTextStyles.titleMedium(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If your question isn\'t answered here, please reach out to our support team using the contact information provided.',
                        style: AppTextStyles.bodyMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsTab(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingL(context),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildSectionHeader('Quick Actions'),
              _buildQuickActionGrid(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Support Hours'),
              _buildSupportHoursCard(context),
              const SizedBox(height: 24),
              _buildSectionHeader('Response Time'),
              _buildResponseTimeCard(context),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: ResponsiveValues.gridSpacing(context),
      mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
      children: [
        _buildQuickActionCard(
          context,
          'Chat with Us',
          'Start a live chat',
          Icons.chat_rounded,
          () => SnackbarService().showInfo(context, 'Live chat coming soon'),
          AppColors.telegramGreen,
        ),
        _buildQuickActionCard(
          context,
          'FAQ',
          'Frequently asked questions',
          Icons.help_rounded,
          () => _tabController.animateTo(1),
          AppColors.telegramYellow,
          index: 1,
        ),
      ],
    );
  }

  Widget _buildResponseTimeCard(BuildContext context) {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1 + _pulseAnimationController.value * 0.05,
                  child: badges.Badge(
                    badgeContent: Text('24H',
                        style: AppTextStyles.caption(context).copyWith(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    badgeStyle: badges.BadgeStyle(
                      badgeColor: AppColors.telegramGreen,
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveValues.spacingM(context),
                        vertical: ResponsiveValues.spacingXS(context),
                      ),
                    ),
                    child: const Icon(Icons.timer_rounded,
                        size: 36, color: AppColors.telegramGreen),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Quick Response',
              style: AppTextStyles.titleMedium(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'We typically respond within 24 hours during business days',
              style: AppTextStyles.bodyMedium(context)
                  .copyWith(color: AppColors.getTextSecondary(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  Widget _buildSupportHoursCard(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final hours = settingsProvider.getOfficeHours();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time_rounded,
                    color: AppColors.telegramBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Support Hours',
                  style: AppTextStyles.titleSmall(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              hours,
              style: AppTextStyles.bodyMedium(context)
                  .copyWith(color: AppColors.getTextSecondary(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  Widget _buildHeroSection(BuildContext context) {
    return AppCard.glass(
      child: Container(
        padding: ResponsiveValues.dialogPadding(context),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.telegramGradient),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle),
              child: const Center(
                  child: Icon(Icons.support_agent_rounded,
                      color: Colors.white, size: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We\'re Here to Help',
                    style: AppTextStyles.titleLarge(context).copyWith(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Get help with your account, payments, subscriptions, or any other questions.',
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: CustomAppBar(
              title: 'Support',
              subtitle: 'Loading...',
              leading: AppButton.icon(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => GoRouter.of(context).pop()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingL(context),
                vertical: ResponsiveValues.spacingL(context),
              ),
              child: AppCard.glass(
                child: Container(
                  height: 120,
                  padding: ResponsiveValues.cardPadding(context),
                  child: const Row(
                    children: [
                      AppShimmer(
                          type: ShimmerType.circle,
                          customWidth: 44,
                          customHeight: 44),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AppShimmer(
                                type: ShimmerType.textLine, customWidth: 150),
                            SizedBox(height: 8),
                            AppShimmer(
                                type: ShimmerType.textLine, customWidth: 250),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingL(context)),
              child: const AppShimmer(
                  type: ShimmerType.rectangle, customHeight: 48),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
              vertical: ResponsiveValues.spacingL(context),
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: EdgeInsets.only(
                      bottom: ResponsiveValues.spacingL(context)),
                  child:
                      AppShimmer(type: ShimmerType.contactCard, index: index),
                ),
                childCount: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: 'Support',
        subtitle: _isRefreshing
            ? 'Refreshing...'
            : (_isOffline ? 'Offline mode' : 'Get help'),
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => GoRouter.of(context).pop()),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
              vertical: ResponsiveValues.spacingM(context),
            ),
            child: _buildHeroSection(context),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.telegramBlue,
            indicatorWeight: 3,
            labelColor: AppColors.telegramBlue,
            unselectedLabelColor: AppColors.getTextSecondary(context),
            labelStyle: AppTextStyles.labelMedium(context),
            unselectedLabelStyle: AppTextStyles.labelMedium(context),
            tabs: const [
              Tab(text: 'Contact'),
              Tab(text: 'FAQ'),
              Tab(text: 'Actions')
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _manualRefresh(_tabController.index),
              color: AppColors.telegramBlue,
              backgroundColor: AppColors.getSurface(context),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildContactTab(context),
                  _buildFAQTab(context),
                  _buildActionsTab(context)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: CustomAppBar(
        title: 'Support',
        subtitle: _isRefreshing
            ? 'Refreshing...'
            : (_isOffline ? 'Offline mode' : 'Get help'),
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => GoRouter.of(context).pop()),
      ),
      body: RefreshIndicator(
        onRefresh: () => _manualRefresh(_tabController.index),
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(ResponsiveValues.spacingXXL(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(context),
                const SizedBox(height: 32),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.telegramBlue,
                  indicatorWeight: 3,
                  labelColor: AppColors.telegramBlue,
                  unselectedLabelColor: AppColors.getTextSecondary(context),
                  labelStyle: AppTextStyles.labelMedium(context),
                  unselectedLabelStyle: AppTextStyles.labelMedium(context),
                  tabs: const [
                    Tab(text: 'Contact'),
                    Tab(text: 'FAQ'),
                    Tab(text: 'Actions')
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContactTab(context),
                      _buildFAQTab(context),
                      _buildActionsTab(context)
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isRefreshing && !_hasError) {
      return _buildSkeletonLoader();
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: 'Support',
          subtitle: 'Error loading',
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded,
              onPressed: () => GoRouter.of(context).pop()),
        ),
        body: Center(
          child: AppEmptyState.error(
            title: 'Failed to Load',
            message: _errorMessage ?? 'Unable to load support information.',
            onRetry: _loadContactSettings,
          ),
        ),
      );
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context),
      tablet: _buildDesktopLayout(context),
      desktop: _buildDesktopLayout(context),
    );
  }
}
