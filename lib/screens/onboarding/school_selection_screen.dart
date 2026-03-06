import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/school_model.dart';
import '../../providers/school_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../utils/constants.dart';
import '../../utils/app_enums.dart';
import '../../widgets/common/responsive_widgets.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<School> _filteredSchools = [];
  int? _selectedSchoolId;
  bool _isLoading = false;
  bool _schoolsLoaded = false;
  bool _isOffline = false;
  Timer? _debounceTimer;
  StreamSubscription? _connectivitySubscription;

  late AnimationController _headerAnimationController;

  @override
  void initState() {
    super.initState();
    _headerAnimationController =
        AnimationController(vsync: this, duration: AppThemes.animationMedium);
    _searchController.addListener(_filterSchools);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      _loadSchools();
      _headerAnimationController.forward();
    });

    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) setState(() => _isOffline = !isOnline);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _headerAnimationController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() => _isOffline = !connectivityService.isOnline);
  }

  void _filterSchools() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.toLowerCase().trim();
      final schoolProvider = context.read<SchoolProvider>();

      setState(() {
        if (query.isEmpty) {
          _filteredSchools = schoolProvider.schools;
        } else {
          _filteredSchools = schoolProvider.schools
              .where((school) => school.name.toLowerCase().contains(query))
              .toList();
        }
      });
    });
  }

  Future<void> _loadSchools({bool forceRefresh = false}) async {
    if (_schoolsLoaded && !forceRefresh) return;

    final schoolProvider = context.read<SchoolProvider>();

    try {
      await schoolProvider.loadSchools(
          forceRefresh: forceRefresh && !_isOffline);
      setState(() {
        _filteredSchools = schoolProvider.schools;
        _schoolsLoaded = true;
      });
    } catch (e) {
      debugLog('SchoolSelectionScreen', 'Error loading schools: $e');
      setState(() => _isOffline = true);
    }
  }

  void _handleSchoolSelection(int? schoolId) {
    setState(() => _selectedSchoolId = schoolId);
  }

  Future<void> _selectSchool() async {
    if (_selectedSchoolId == null) {
      SnackbarService().showError(context, 'Please select a school');
      return;
    }

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: 'select school');
      return;
    }

    if (_selectedSchoolId == 0) {
      await _handleOtherSchoolSelection();
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final schoolProvider = context.read<SchoolProvider>();
    final apiService = context.read<ApiService>();

    try {
      if (!authProvider.isAuthenticated) {
        throw Exception('Session expired. Please login again.');
      }

      final response = await apiService.selectSchool(_selectedSchoolId!);

      if (!mounted) return;

      if (response.success) {
        await schoolProvider.selectSchool(_selectedSchoolId!);

        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          final updatedUser = currentUser.copyWith(schoolId: _selectedSchoolId);
          await authProvider.updateUser(updatedUser);
        }

        SnackbarService().showSuccess(context, 'School selected successfully');

        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;
        context.go('/');
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (!mounted) return;

      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        SnackbarService().showError(
            context, 'Your session has expired. Please login again.');
        await Future.delayed(const Duration(seconds: 1));
        await authProvider.logout();
        if (mounted) context.go('/auth/login');
      } else {
        SnackbarService().showError(context, 'Failed to select school: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOtherSchoolSelection() async {
    if (!mounted) return;

    final schoolProvider = context.read<SchoolProvider>();
    setState(() => _isLoading = true);

    try {
      await schoolProvider.selectSchool(0);
      SnackbarService()
          .showSuccess(context, 'Proceeding without specific school selection');
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted)
        SnackbarService().showError(context, 'Failed to proceed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSchoolCard(BuildContext context, School school, int index) {
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
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
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
                          fontSize: ScreenSize.fontSize(
                              context: context,
                              base: 16,
                              tablet: 18,
                              desktop: 20),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: ResponsiveValues.iconSizeXXS(context),
                              color: AppColors.getTextSecondary(context)),
                          SizedBox(width: ResponsiveValues.spacingXS(context)),
                          Text(
                            'Added: ${formatDate(school.createdAt)}',
                            style: AppTextStyles.caption(context).copyWith(
                                color: AppColors.getTextSecondary(context)),
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
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationMedium,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationMedium,
          delay: (index * 50).ms,
        );
  }

  Widget _buildOtherOption(BuildContext context, int index) {
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
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
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
                        'Other School',
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontSize: ScreenSize.fontSize(
                              context: context,
                              base: 16,
                              tablet: 18,
                              desktop: 20),
                        ),
                      ),
                      SizedBox(height: ResponsiveValues.spacingXS(context)),
                      Text(
                        'My school is not listed',
                        style: AppTextStyles.caption(context).copyWith(
                            color: AppColors.getTextSecondary(context)),
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
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationMedium,
          delay: (index * 50).ms,
        )
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationMedium,
          delay: (index * 50).ms,
        );
  }

  @override
  Widget build(BuildContext context) {
    final schoolProvider = context.watch<SchoolProvider>();

    if (schoolProvider.isLoading && !_schoolsLoaded) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: const AppShimmer(type: ShimmerType.textLine, customWidth: 150),
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
          leading: AppButton.icon(
              icon: Icons.arrow_back_rounded, onPressed: () => context.go('/')),
          bottom: PreferredSize(
            preferredSize:
                Size.fromHeight(ResponsiveValues.appBarHeight(context) + 16),
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: AppCard.glass(
                child: AppTextField.search(
                  controller: _searchController,
                  hint: 'Search schools...',
                  enabled: !_isOffline,
                ),
              ),
            ),
          ),
        ),
        body: ListView.builder(
          padding: ResponsiveValues.screenPadding(context),
          itemCount: 5,
          itemBuilder: (context, index) => Padding(
            padding:
                EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
            child: AppShimmer(type: ShimmerType.schoolCard, index: index),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('Select School', style: AppTextStyles.appBarTitle(context)),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: AppButton.icon(
            icon: Icons.arrow_back_rounded, onPressed: () => context.go('/')),
        bottom: PreferredSize(
          preferredSize:
              Size.fromHeight(ResponsiveValues.appBarHeight(context) + 16),
          child: Padding(
            padding: ResponsiveValues.screenPadding(context),
            child: AppCard.glass(
              child: AppTextField.search(
                controller: _searchController,
                hint: 'Search schools...',
                enabled: !_isOffline,
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: ResponsiveValues.screenPadding(context),
            sliver: SliverList.separated(
              itemCount: _filteredSchools.length + 1,
              itemBuilder: (context, index) {
                if (index == _filteredSchools.length) {
                  return _buildOtherOption(context, index);
                }
                return _buildSchoolCard(
                    context, _filteredSchools[index], index);
              },
              separatorBuilder: (context, index) =>
                  SizedBox(height: ResponsiveValues.spacingL(context)),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: Column(
                children: [
                  if (_isOffline)
                    Container(
                      padding: ResponsiveValues.cardPadding(context),
                      margin: EdgeInsets.only(
                          bottom: ResponsiveValues.spacingL(context)),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramYellow.withValues(alpha: 0.2),
                            AppColors.telegramYellow.withValues(alpha: 0.1)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context)),
                        border: Border.all(
                            color: AppColors.telegramYellow
                                .withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: AppColors.telegramYellow, size: 20),
                          SizedBox(width: ResponsiveValues.spacingM(context)),
                          Expanded(
                            child: Text(
                              'You are offline. Showing cached schools.',
                              style: AppTextStyles.bodySmall(context)
                                  .copyWith(color: AppColors.telegramYellow),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: ResponsiveValues.spacingL(context)),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      label: _isOffline
                          ? 'Offline'
                          : (_selectedSchoolId == 0
                              ? 'Continue with Other School'
                              : 'Continue to Learning'),
                      onPressed:
                          _isLoading || _selectedSchoolId == null || _isOffline
                              ? null
                              : _selectSchool,
                      icon: _isOffline
                          ? Icons.wifi_off_rounded
                          : (_selectedSchoolId == 0
                              ? Icons.arrow_forward_rounded
                              : Icons.check_rounded),
                      isLoading: _isLoading,
                      expanded: true,
                    )
                        .animate()
                        .fadeIn(
                          duration: AppThemes.animationMedium,
                          delay: 600.ms,
                        )
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: AppThemes.animationMedium,
                        ),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXXL(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
