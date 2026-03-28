import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import 'package:url_launcher/url_launcher.dart';

import '../../providers/settings_provider.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dialog.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with BaseScreenMixin<SupportScreen>, TickerProviderStateMixin {
  late TabController _tabController;
  bool _hasError = false;
  String? _errorMessage;
  final List<RefreshController> _refreshControllers = [];

  late AnimationController _pulseAnimationController;
  late SettingsProvider _settingsProvider;
  bool _didInitialize = false;

  @override
  String get screenTitle =>
      _didInitialize ? _settingsProvider.getSupportScreenTitle() : AppStrings.support;

  @override
  String? get screenSubtitle => isRefreshing
      ? AppStrings.refreshing
      : (isOffline
          ? AppStrings.offlineMode
          : (_didInitialize
              ? _settingsProvider.getSupportScreenSubtitle()
              : AppStrings.getHelp));

  @override
  bool get isLoading => false;

  @override
  bool get hasCachedData => true;

  @override
  dynamic get errorMessage => _hasError ? _errorMessage : null;

  // ✅ Shimmer type for support screen
  @override
  ShimmerType get shimmerType => ShimmerType.contactCard;

  @override
  int get shimmerItemCount => 3;

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

    _tabController = TabController(length: 3, vsync: this);
    _refreshControllers.addAll([
      RefreshController(),
      RefreshController(),
      RefreshController(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitialize) return;

    _settingsProvider = context.read<SettingsProvider>();
    _didInitialize = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await _settingsProvider.loadContactSettings();
      } catch (e) {
        if (!mounted) return;
        final hasVisibleSupportData =
            _settingsProvider.getContactInfoList().isNotEmpty;
        setState(() {
          _hasError = !hasVisibleSupportData;
          _errorMessage =
              hasVisibleSupportData ? null : getUserFriendlyErrorMessage(e);
        });
      }
    });
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

  @override
  Future<void> onRefresh() async {
    await _refreshTab(_tabController.index);
  }

  Future<void> _refreshTab(int tabIndex) async {
    if (isOffline) {
      SnackbarService().showOffline(context);
      _refreshControllers[tabIndex].refreshFailed();
      return;
    }

    try {
      await _settingsProvider.getAllSettings();
      await _settingsProvider.loadContactSettings(forceRefresh: true);

      _refreshControllers[tabIndex].refreshCompleted();
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    } catch (e) {
      final hasVisibleSupportData =
          _settingsProvider.getContactInfoList().isNotEmpty;

      setState(() {
        _hasError = !hasVisibleSupportData;
        _errorMessage =
            hasVisibleSupportData ? null : getUserFriendlyErrorMessage(e);
      });
      _refreshControllers[tabIndex].refreshFailed();
      if (hasVisibleSupportData) {
        SnackbarService().showInfo(
          context,
          'We could not refresh support details just now. Your saved contact information is still available.',
        );
      } else {
        SnackbarService().showError(context, '${AppStrings.refreshFailed}: $e');
      }
    }
  }

  Future<void> _handleContactTap(ContactType type, String value) async {
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
          _showCopyDialog(value);
          return;
        }
        break;
    }

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (type == ContactType.other || type == ContactType.website) {
          _showCopyDialog(value);
        } else {
          SnackbarService().showError(
            context,
            '${AppStrings.cannotOpen} $value',
          );
        }
      }
    } catch (e) {
      _showCopyDialog(value);
    }
  }

  ContactInfo? _getPrimaryInstantSupportContact() {
    final contacts = _settingsProvider.getContactInfoList();
    for (final preferredType in const [
      ContactType.whatsapp,
      ContactType.telegram,
      ContactType.email,
      ContactType.phone,
    ]) {
      try {
        return contacts.firstWhere((contact) => contact.type == preferredType);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> _handleQuickSupportAction() async {
    final contact = _getPrimaryInstantSupportContact();
    if (contact == null) {
      SnackbarService().showInfo(
        context,
        'Your administrator has not configured a direct support contact yet.',
      );
      return;
    }

    await _handleContactTap(contact.type, contact.value);
  }

  void _showCopyDialog(String value) {
    AppDialog.input(
      context: context,
      title: AppStrings.copyToClipboard,
      initialValue: value,
      hintText: value,
      confirmText: AppStrings.copy,
    ).then((_) {
      Clipboard.setData(ClipboardData(text: value));
      SnackbarService().showSuccess(context, AppStrings.copiedToClipboard);
    });
  }

  Widget _buildContactCard(
    String title,
    String value,
    IconData icon,
    ContactType type, {
    Color? iconColor,
    int index = 0,
  }) {
    final canTap = type != ContactType.hours;
    final color = iconColor ?? _getIconColorForType(type);

    return Container(
      margin: EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
      child: AppCard.contact(
        accentColor: color,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canTap && !isOffline
                ? () => _handleContactTap(type, value)
                : null,
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusXLarge(context),
            ),
            splashColor: color.withValues(alpha: 0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: Row(
                children: [
                  Container(
                    width: ResponsiveValues.supportActionIconContainerSize(
                      context,
                    ),
                    height: ResponsiveValues.supportActionIconContainerSize(
                      context,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                      border: Border.all(
                        color: color.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: ResponsiveValues.iconSizeL(context),
                        color: isOffline ? AppColors.warning : color,
                      ),
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingL(context)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: AppTextStyles.labelMedium(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingXXS(context)),
                        Text(
                          value,
                          style: AppTextStyles.bodyMedium(
                            context,
                          ).copyWith(fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (canTap && !isOffline) ...[
                          SizedBox(height: ResponsiveValues.spacingS(context)),
                          Row(
                            children: [
                              Text(
                                type == ContactType.address
                                    ? AppStrings.viewOnMap
                                    : type == ContactType.other
                                        ? AppStrings.tapToCopy
                                        : AppStrings.tapToContact,
                                style: AppTextStyles.caption(
                                  context,
                                ).copyWith(color: color),
                              ),
                              SizedBox(
                                width: ResponsiveValues.spacingXXS(context),
                              ),
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
                  if (canTap && !isOffline)
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
          delay: (index * 50).ms,
        );
  }

  Widget _buildQuickActionCard(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    Color color, {
    int index = 0,
  }) {
    return AppCard.glass(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isOffline ? null : onTap,
          borderRadius: BorderRadius.circular(
            ResponsiveValues.radiusXLarge(context),
          ),
          splashColor: color.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Container(
            padding: ResponsiveValues.cardPadding(context),
            height: 140,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: ResponsiveValues.supportActionIconContainerSize(
                    context,
                  ),
                  height: ResponsiveValues.supportActionIconContainerSize(
                    context,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    border: Border.all(color: color, width: 1.5),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: ResponsiveValues.iconSizeS(context),
                      color: isOffline ? AppColors.warning : color,
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                Text(
                  title,
                  style: AppTextStyles.titleSmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: ResponsiveValues.spacingXXS(context) / 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption(
                    context,
                  ).copyWith(color: AppColors.getTextSecondary(context)),
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
          delay: (index * 50).ms,
        );
  }

  Widget _buildFAQItem(String question, String answer, {int index = 0}) {
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
                    AppColors.telegramPurple.withValues(alpha: 0.1),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_rounded,
                size: ResponsiveValues.iconSizeXS(context),
                color: AppColors.telegramBlue,
              ),
            ),
            title: Text(
              question,
              style: AppTextStyles.titleSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w500),
            ),
            children: [
              Padding(
                padding: ResponsiveValues.cardPadding(context),
                child: Text(
                  answer,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
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
          delay: (index * 50).ms,
        );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingM(context),
        top: ResponsiveValues.spacingXL(context),
      ),
      child: Text(
        title,
        style: AppTextStyles.titleLarge(
          context,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _getIconColorForType(ContactType type) {
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

  Widget _buildContactTab() {
    final contactInfo = _settingsProvider.getContactInfoList();

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
              _buildSectionHeader(AppStrings.contactInformation),
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
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        Text(
                          _settingsProvider.getSupportNoContactTitle(),
                          style: AppTextStyles.bodyLarge(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Text(
                          _settingsProvider.getSupportNoContactMessage(),
                          style: AppTextStyles.bodySmall(context).copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...contactInfo.asMap().entries.map(
                      (entry) => _buildContactCard(
                        entry.value.title,
                        entry.value.value,
                        entry.value.icon,
                        entry.value.type,
                        index: entry.key,
                      ),
                    ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildSectionHeader(AppStrings.responseTime),
              _buildResponseTimeCard(),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildFAQTab() {
    final faqs = _settingsProvider.getSupportFaqItems();

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
              _buildSectionHeader(AppStrings.frequentlyAskedQuestions),
              ...faqs.asMap().entries.map(
                    (entry) => _buildFAQItem(
                      entry.value['question']!,
                      entry.value['answer']!,
                      index: entry.key,
                    ),
                  ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildSectionHeader(AppStrings.stillNeedHelp),
              AppCard.glass(
                child: Padding(
                  padding: ResponsiveValues.cardPadding(context),
                  child: Column(
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: ResponsiveValues.iconSizeXXXXL(context),
                        color: AppColors.telegramBlue,
                      ),
                      SizedBox(height: ResponsiveValues.spacingL(context)),
                      Text(
                        _settingsProvider.getSupportStillNeedHelpTitle(),
                        style: AppTextStyles.titleMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: ResponsiveValues.spacingS(context)),
                      Text(
                        _settingsProvider.getSupportStillNeedHelpMessage(),
                        style: AppTextStyles.bodyMedium(
                          context,
                        ).copyWith(color: AppColors.getTextSecondary(context)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsTab() {
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
              _buildSectionHeader(AppStrings.quickActions),
              _buildQuickActionGrid(),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildSectionHeader(_settingsProvider.getSupportHoursLabel()),
              _buildSupportHoursCard(),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              _buildSectionHeader(AppStrings.responseTime),
              _buildResponseTimeCard(),
              SizedBox(height: ResponsiveValues.spacingXXL(context)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: ResponsiveValues.gridSpacing(context),
      mainAxisSpacing: ResponsiveValues.gridRunSpacing(context),
      children: [
        _buildQuickActionCard(
          _settingsProvider.getSupportQuickActionTitle(),
          _settingsProvider.getSupportQuickActionDescription(),
          Icons.chat_rounded,
          _handleQuickSupportAction,
          AppColors.telegramGreen,
        ),
        _buildQuickActionCard(
          AppStrings.faq,
          AppStrings.frequentlyAskedQuestions,
          Icons.help_rounded,
          () => _tabController.animateTo(1),
          AppColors.telegramYellow,
          index: 1,
        ),
      ],
    );
  }

  Widget _buildResponseTimeCard() {
    final responseBadge = _settingsProvider.getSupportResponseBadgeLabel();
    final responseMessage = _settingsProvider.getSupportResponseMessage();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: ResponsiveValues.selectionSheetLeadingSize(context),
                  height: ResponsiveValues.selectionSheetLeadingSize(context),
                  decoration: BoxDecoration(
                    color: AppColors.telegramGreen.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.timer_rounded,
                    size: ResponsiveValues.iconSizeL(context),
                    color: AppColors.telegramGreen,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _settingsProvider.getSupportResponseTitle(),
                        style: AppTextStyles.titleMedium(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXXS(context)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.telegramGreen.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusFull(context),
                          ),
                        ),
                        child: Text(
                          responseBadge,
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: AppColors.telegramGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              responseMessage,
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: AppColors.getTextSecondary(context)),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  Widget _buildSupportHoursCard() {
    final hours = _settingsProvider.getOfficeHours();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: AppColors.telegramBlue,
                  size: ResponsiveValues.iconSizeS(context),
                ),
                SizedBox(width: ResponsiveValues.spacingS(context)),
                Text(
                  AppStrings.supportHours,
                  style: AppTextStyles.titleSmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: ResponsiveValues.spacingL(context)),
            Text(
              hours,
              style: AppTextStyles.bodyMedium(
                context,
              ).copyWith(color: AppColors.getTextSecondary(context)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }

  Widget _buildHeroSection() {
    return AppCard.glass(
      child: Container(
        padding: ResponsiveValues.dialogPadding(context),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.selectionSheetLeadingSize(context),
              height: ResponsiveValues.selectionSheetLeadingSize(context),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.telegramBlue,
                  size: ResponsiveValues.iconSizeL(context),
                ),
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingL(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.weAreHereToHelp,
                    style: AppTextStyles.titleLarge(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXXS(context)),
                  Text(
                    AppStrings.getHelpWith,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(color: AppColors.getTextSecondary(context)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    if (_hasError) {
      return Center(
        child: buildErrorWidget(
          _errorMessage ?? AppStrings.unableToLoadSupportInfo,
          onRetry: () => _refreshTab(_tabController.index),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingM(context),
          ),
          child: _buildHeroSection(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
          ),
          child: AppCard.solid(
            hasShadow: false,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.telegramBlue,
              indicatorWeight: 3,
              labelColor: AppColors.telegramBlue,
              unselectedLabelColor: AppColors.getTextSecondary(context),
              labelStyle: AppTextStyles.labelMedium(context),
              unselectedLabelStyle: AppTextStyles.labelMedium(context),
              tabs: const [
                Tab(text: AppStrings.contact),
                Tab(text: AppStrings.faq),
                Tab(text: AppStrings.actions),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refreshTab(_tabController.index),
            color: AppColors.telegramBlue,
            backgroundColor: AppColors.getSurface(context),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildContactTab(),
                _buildFAQTab(),
                _buildActionsTab(),
              ],
            ),
          ),
        ),
      ],
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
