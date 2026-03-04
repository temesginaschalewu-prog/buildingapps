import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/api_service.dart';
import '../../providers/school_provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
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

  late AnimationController _headerAnimationController;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    );
    _searchController.addListener(_filterSchools);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      _loadSchools();
      _headerAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _headerAnimationController.dispose();
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
        color: onPressed == null
            ? AppColors.telegramGray.withValues(alpha: 0.2)
            : null,
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
                          color: onPressed != null
                              ? Colors.white
                              : AppColors.getTextSecondary(context),
                        ),
                        const ResponsiveSizedBox(width: AppSpacing.s),
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

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Shimmer.fromColors(
          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
          highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
          child: Container(
            width: ResponsiveValues.spacingXXXL(context) * 3,
            height: ResponsiveValues.spacingXL(context),
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: ResponsiveValues.screenPadding(context),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(
            bottom: ResponsiveValues.spacingL(context),
          ),
          child: _buildGlassContainer(
            child: Padding(
              padding: ResponsiveValues.cardPadding(context),
              child: ResponsiveRow(
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                    highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                    child: Container(
                      width: ResponsiveValues.iconSizeXL(context) * 1.5,
                      height: ResponsiveValues.iconSizeXL(context) * 1.5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const ResponsiveSizedBox(width: AppSpacing.l),
                  Expanded(
                    child: ResponsiveColumn(
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height: ResponsiveValues.spacingXL(context),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusSmall(context),
                              ),
                            ),
                          ),
                        ),
                        const ResponsiveSizedBox(height: AppSpacing.s),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height: ResponsiveValues.spacingL(context),
                            width: ResponsiveValues.spacingXXXL(context) * 3,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _filterSchools() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final query = _searchController.text.toLowerCase().trim();
      final schoolProvider =
          Provider.of<SchoolProvider>(context, listen: false);

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

    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

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
      showTopSnackBar(context, 'Please select a school', isError: true);
      return;
    }

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showTopSnackBar(
        context,
        'You are offline. Please check your internet connection.',
        isError: true,
      );
      return;
    }

    if (_selectedSchoolId == 0) {
      await _handleOtherSchoolSelection();
      return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

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

        showTopSnackBar(context, 'School selected successfully');

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
        showTopSnackBar(
            context, 'Your session has expired. Please login again.',
            isError: true);
        await Future.delayed(const Duration(seconds: 1));
        await authProvider.logout();
        if (mounted) context.go('/auth/login');
      } else {
        showTopSnackBar(context, 'Failed to select school: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOtherSchoolSelection() async {
    if (!mounted) return;

    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      await schoolProvider.selectSchool(0);
      showTopSnackBar(context, 'Proceeding without specific school selection');
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        showTopSnackBar(context, 'Failed to proceed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSchoolCard(BuildContext context, School school, int index) {
    final isSelected = _selectedSchoolId == school.id;

    return _buildGlassContainer(
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
            child: ResponsiveRow(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1),
                            ]
                          : [
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.3),
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                  child: ResponsiveIcon(
                    Icons.school_rounded,
                    size: ResponsiveValues.iconSizeL(context),
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.telegramBlue.withValues(alpha: 0.5),
                  ),
                ),
                const ResponsiveSizedBox(width: AppSpacing.l),
                Expanded(
                  child: ResponsiveColumn(
                    children: [
                      ResponsiveText(
                        school.name,
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontSize: ScreenSize.fontSize(
                            context: context,
                            base: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const ResponsiveSizedBox(height: AppSpacing.xs),
                      ResponsiveRow(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: ResponsiveValues.iconSizeXXS(context),
                              color: AppColors.getTextSecondary(context)),
                          const ResponsiveSizedBox(width: AppSpacing.xs),
                          ResponsiveText(
                            'Added: ${formatDate(school.createdAt)}',
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
                        ? const LinearGradient(
                            colors: AppColors.blueGradient,
                          )
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
            duration: AppThemes.animationDurationMedium, delay: (index * 50).ms)
        .slideX(
            begin: 0.1,
            end: 0,
            duration: AppThemes.animationDurationMedium,
            delay: (index * 50).ms);
  }

  Widget _buildOtherOption(BuildContext context, int index) {
    final isSelected = _selectedSchoolId == 0;

    return _buildGlassContainer(
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
            child: ResponsiveRow(
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXL(context) * 1.5,
                  height: ResponsiveValues.iconSizeXL(context) * 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1),
                            ]
                          : [
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.3),
                              AppColors.getSurface(context)
                                  .withValues(alpha: 0.1),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                  ),
                  child: ResponsiveIcon(
                    Icons.help_outline_rounded,
                    size: ResponsiveValues.iconSizeL(context),
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.telegramGray,
                  ),
                ),
                const ResponsiveSizedBox(width: AppSpacing.l),
                Expanded(
                  child: ResponsiveColumn(
                    children: [
                      ResponsiveText(
                        'Other School',
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontSize: ScreenSize.fontSize(
                            context: context,
                            base: 16,
                            tablet: 18,
                            desktop: 20,
                          ),
                        ),
                      ),
                      const ResponsiveSizedBox(height: AppSpacing.xs),
                      ResponsiveText(
                        'My school is not listed',
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
                        ? const LinearGradient(
                            colors: AppColors.blueGradient,
                          )
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
            duration: AppThemes.animationDurationMedium, delay: (index * 50).ms)
        .slideX(
            begin: 0.1,
            end: 0,
            duration: AppThemes.animationDurationMedium,
            delay: (index * 50).ms);
  }

  Widget _buildMobileLayout() {
    final schoolProvider = Provider.of<SchoolProvider>(context);

    if (schoolProvider.isLoading && !_schoolsLoaded) {
      return _buildSkeletonLoader();
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: ResponsiveText(
          'Select School',
          style: AppTextStyles.appBarTitle(context),
        ),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: ResponsiveIcon(
            Icons.arrow_back_rounded,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => context.go('/'),
        ),
        bottom: PreferredSize(
          preferredSize:
              Size.fromHeight(ResponsiveValues.appBarHeight(context) + 16),
          child: Padding(
            padding: ResponsiveValues.screenPadding(context),
            child: _buildGlassContainer(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search schools...',
                  hintStyle: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context)
                        .withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.getTextSecondary(context),
                      size: ResponsiveValues.iconSizeS(context)),
                  border: InputBorder.none,
                  contentPadding: ResponsiveValues.listItemPadding(context),
                ),
                style: AppTextStyles.bodyMedium(context),
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
                  const ResponsiveSizedBox(height: AppSpacing.l),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: ResponsiveColumn(
                children: [
                  if (_isOffline)
                    Container(
                      padding: ResponsiveValues.cardPadding(context),
                      margin: EdgeInsets.only(
                        bottom: ResponsiveValues.spacingL(context),
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramYellow.withValues(alpha: 0.2),
                            AppColors.telegramYellow.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                        border: Border.all(
                          color:
                              AppColors.telegramYellow.withValues(alpha: 0.3),
                        ),
                      ),
                      child: ResponsiveRow(
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: AppColors.telegramYellow, size: 20),
                          const ResponsiveSizedBox(width: AppSpacing.m),
                          Expanded(
                            child: ResponsiveText(
                              'You are offline. Showing cached schools.',
                              style: AppTextStyles.bodySmall(context).copyWith(
                                color: AppColors.telegramYellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const ResponsiveSizedBox(height: AppSpacing.l),
                  SizedBox(
                    width: double.infinity,
                    child: _buildGradientButton(
                      label: _isOffline
                          ? 'Offline'
                          : (_selectedSchoolId == 0
                              ? 'Continue with Other School'
                              : 'Continue to Learning'),
                      onPressed:
                          _isLoading || _selectedSchoolId == null || _isOffline
                              ? null
                              : _selectSchool,
                      gradient: AppColors.blueGradient,
                      icon: _isOffline
                          ? Icons.wifi_off_rounded
                          : (_selectedSchoolId == 0
                              ? Icons.arrow_forward_rounded
                              : Icons.check_rounded),
                      isLoading: _isLoading,
                    )
                        .animate()
                        .fadeIn(
                            duration: AppThemes.animationDurationMedium,
                            delay: 600.ms)
                        .slideY(
                            begin: 0.1,
                            end: 0,
                            duration: AppThemes.animationDurationMedium),
                  ),
                  const ResponsiveSizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return _buildMobileLayout();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}
