// lib/screens/onboarding/school_selection_screen.dart
// PRODUCTION STANDARD - WITH SHIMMER TYPE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/school_model.dart';
import '../../providers/school_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/device_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen>
    with BaseScreenMixin<SchoolSelectionScreen>, TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<School> _filteredSchools = [];
  int? _selectedSchoolId;
  bool _schoolsLoaded = false;
  Timer? _debounceTimer;
  late SchoolProvider _schoolProvider;
  late AuthProvider _authProvider;

  @override
  String get screenTitle => AppStrings.selectSchool;

  @override
  String? get screenSubtitle =>
      isOffline ? AppStrings.offlineCachedSchools : null;

  @override
  bool get isLoading => _schoolProvider.isLoading && !_schoolsLoaded;

  @override
  bool get hasCachedData =>
      _schoolsLoaded && _schoolProvider.schools.isNotEmpty;

  // ✅ Shimmer type for school selection
  @override
  ShimmerType get shimmerType => ShimmerType.schoolCard;

  @override
  int get shimmerItemCount => 5;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSchools);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schoolProvider = Provider.of<SchoolProvider>(context);
    _authProvider = Provider.of<AuthProvider>(context);

    _loadSchools();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _filterSchools() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!isMounted) return;
      final query = _searchController.text.toLowerCase().trim();

      setState(() {
        if (query.isEmpty) {
          _filteredSchools = _schoolProvider.schools;
        } else {
          _filteredSchools = _schoolProvider.schools
              .where((school) => school.name.toLowerCase().contains(query))
              .toList();
        }
      });
    });
  }

  Future<void> _loadSchools({bool forceRefresh = false}) async {
    if (_schoolsLoaded && !forceRefresh) return;

    try {
      await _schoolProvider.loadSchools(
          forceRefresh: forceRefresh && !isOffline);
      setState(() {
        _filteredSchools = _schoolProvider.schools;
        _schoolsLoaded = true;
      });
    } catch (e) {
      debugLog('SchoolSelectionScreen', 'Error loading schools: $e');
    }
  }

  @override
  Future<void> onRefresh() async {
    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.refresh);
      return;
    }

    try {
      await _loadSchools(forceRefresh: true);
    } catch (e) {
      if (!isMounted) return;
      SnackbarService().showInfo(
        context,
        hasCachedData
            ? 'We could not refresh schools just now. Your saved list is still available.'
            : AppStrings.refreshFailed,
      );
    }
  }

  void _handleSchoolSelection(int? schoolId) {
    setState(() => _selectedSchoolId = schoolId);
  }

  Future<void> _selectSchool() async {
    if (_selectedSchoolId == null) {
      SnackbarService().showError(context, AppStrings.selectSchool);
      return;
    }

    if (isOffline) {
      SnackbarService().showOffline(context, action: AppStrings.selectSchool);
      return;
    }

    if (_selectedSchoolId == 0) {
      await _handleOtherSchoolSelection();
      return;
    }

    if (!isMounted) return;

    try {
      if (!_authProvider.isAuthenticated) {
        throw Exception(AppStrings.sessionExpired);
      }

      final response = await _schoolProvider.selectSchool(_selectedSchoolId!);

      if (!isMounted) return;

      if (response.success) {
        await _authProvider.updateSelectedSchool(_selectedSchoolId!);
        await _saveToCache(_selectedSchoolId!);

        SnackbarService().showSuccess(context, AppStrings.schoolSelected);
        await Future.delayed(const Duration(milliseconds: 100));
        if (!isMounted) return;
        context.go('/');
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (!isMounted) return;

      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        SnackbarService().showError(context, AppStrings.sessionExpired);
        await Future.delayed(const Duration(seconds: 1));
        await _authProvider.logout();
        if (isMounted) context.go('/auth/login');
      } else {
        SnackbarService()
            .showError(context, '${AppStrings.failedToSelectSchool}: $e');
      }
    }
  }

  Future<void> _saveToCache(int schoolId) async {
    try {
      final deviceService = context.read<DeviceService>();
      deviceService.saveCacheItem(
        AppConstants.selectedSchoolKey,
        schoolId,
        ttl: const Duration(days: 365),
      );
    } catch (e) {
      debugLog('SchoolSelectionScreen', 'Error saving to cache: $e');
    }
  }

  Future<void> _handleOtherSchoolSelection() async {
    if (!isMounted) return;

    try {
      await _schoolProvider.selectSchool(0);
      await _authProvider.updateSelectedSchool(0);
      await _saveToCache(0);

      SnackbarService()
          .showSuccess(context, AppStrings.proceedingWithoutSchool);
      await Future.delayed(const Duration(milliseconds: 100));
      if (isMounted) context.go('/');
    } catch (e) {
      if (isMounted) {
        SnackbarService()
            .showError(context, '${AppStrings.failedToProceed}: $e');
      }
    }
  }

  Widget _buildSchoolCard(School school, int index) {
    final isSelected = _selectedSchoolId == school.id;

    return AppCard.school(
      isSelected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSchoolSelection(school.id),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Row(
              children: [
                Container(
                  width: ResponsiveValues.schoolSelectionIconContainerSize(
                    context,
                  ),
                  height: ResponsiveValues.schoolSelectionIconContainerSize(
                    context,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1)
                            ]
                          : [
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.3),
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.1)
                            ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: ResponsiveValues.iconSizeL(context),
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.telegramBlue.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        school.name,
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontSize:
                              ResponsiveValues.schoolSelectionTitleFont(
                            context,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: ResponsiveValues.iconSizeXXS(context),
                            color: AppColors.getTextSecondary(context),
                          ),
                          SizedBox(width: ResponsiveValues.spacingXS(context)),
                          Text(
                            '${AppStrings.added}: ${formatDate(school.createdAt)}',
                            style: AppTextStyles.caption(context).copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? const LinearGradient(colors: AppColors.blueGradient)
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.getTextSecondary(context)
                              .withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtherOption(int index) {
    final isSelected = _selectedSchoolId == 0;

    return AppCard.school(
      isSelected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleSchoolSelection(0),
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: ResponsiveValues.cardPadding(context),
            child: Row(
              children: [
                Container(
                  width: ResponsiveValues.schoolSelectionIconContainerSize(
                    context,
                  ),
                  height: ResponsiveValues.schoolSelectionIconContainerSize(
                    context,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1)
                            ]
                          : [
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.3),
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.1)
                            ],
                    ),
                    borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context)),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: ResponsiveValues.iconSizeL(context),
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.telegramGray,
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingL(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.otherSchool,
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontSize:
                              ResponsiveValues.schoolSelectionTitleFont(
                            context,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        AppStrings.mySchoolNotListed,
                        style: AppTextStyles.caption(context).copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: ResponsiveValues.iconSizeL(context),
                  height: ResponsiveValues.iconSizeL(context),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? const LinearGradient(colors: AppColors.blueGradient)
                        : null,
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.getTextSecondary(context)
                              .withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroPanel() {
    final selectedSchool = _selectedSchoolId != null && _selectedSchoolId != 0
        ? _schoolProvider.schools
            .cast<School?>()
            .firstWhere(
              (school) => school?.id == _selectedSchoolId,
              orElse: () => null,
            )
        : null;

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Choose your school before entering the learning workspace.',
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.45,
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingM(context)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: ResponsiveValues.spacingM(context),
                    vertical: ResponsiveValues.spacingXS(context),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.telegramBlue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusFull(context),
                    ),
                  ),
                  child: Text(
                    '${_filteredSchools.length + 1} options',
                    style: AppTextStyles.labelSmall(context).copyWith(
                      color: AppColors.telegramBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedSchoolId != null) ...[
              SizedBox(height: ResponsiveValues.spacingL(context)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveValues.spacingM(context),
                  vertical: ResponsiveValues.spacingM(context),
                ),
                decoration: BoxDecoration(
                  color: AppColors.telegramBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(
                    ResponsiveValues.radiusMedium(context),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: ResponsiveValues.iconSizeS(context),
                      color: AppColors.telegramBlue,
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Text(
                        selectedSchool != null
                            ? 'Selected: ${selectedSchool.name}'
                            : 'Selected: ${AppStrings.otherSchool}',
                        style: AppTextStyles.bodyMedium(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget buildContent(BuildContext context) {
    if (isLoading && !hasCachedData) {
      return buildLoadingShimmer();
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            color: AppColors.telegramBlue,
            backgroundColor: AppColors.getSurface(context),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      ResponsiveValues.onboardingHeaderPadding(context).left,
                      ResponsiveValues.onboardingHeaderPadding(context).top,
                      ResponsiveValues.onboardingHeaderPadding(context).right,
                      ResponsiveValues.onboardingHeaderPadding(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntroPanel(),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: ResponsiveValues.onboardingHeaderPadding(context).left,
                    right:
                        ResponsiveValues.onboardingHeaderPadding(context).right,
                    top: ResponsiveValues.onboardingListSpacing(context),
                  ),
                  sliver: SliverList.separated(
                    itemCount: _filteredSchools.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _filteredSchools.length) {
                        return _buildOtherOption(index);
                      }
                      return _buildSchoolCard(_filteredSchools[index], index);
                    },
                    separatorBuilder: (context, index) =>
                        SizedBox(
                      height: ResponsiveValues.onboardingListSpacing(context),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                    child: SizedBox(
                        height: ResponsiveValues.onboardingListSpacing(
                      context,
                    ))),
              ],
            ),
          ),
        ),
        Container(
          color: AppColors.getBackground(context),
          child: Padding(
            padding: ResponsiveValues.onboardingFooterPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: isOffline
                        ? AppStrings.offline
                        : (_selectedSchoolId == 0
                            ? AppStrings.continueWithOtherSchool
                            : AppStrings.continueToLearning),
                    size: ButtonSize.large,
                    onPressed: _selectedSchoolId == null || isOffline
                        ? null
                        : _selectSchool,
                    icon: isOffline
                        ? Icons.wifi_off_rounded
                        : (_selectedSchoolId == 0
                            ? Icons.arrow_forward_rounded
                            : Icons.check_rounded),
                    expanded: true,
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingXL(context),
                      vertical: ResponsiveValues.spacingM(context),
                    ),
                  )
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
                Text(
                  isOffline
                      ? AppStrings.offlineCachedSchools
                      : 'You can change this later from your profile settings.',
                  style: AppTextStyles.bodySmall(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveValues.spacingS(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(screenTitle, style: AppTextStyles.appBarTitle(context)),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/'),
          tooltip: 'Back',
        ),
        bottom: PreferredSize(
          preferredSize:
              Size.fromHeight(ResponsiveValues.appBarHeight(context) + 16),
          child: Padding(
            padding: ResponsiveValues.screenPadding(context),
            child: AppTextField.search(
              controller: _searchController,
              hint: AppStrings.searchSchools,
              enabled: !isOffline,
            ),
          ),
        ),
      ),
      body: buildContent(context),
    );
  }
}
