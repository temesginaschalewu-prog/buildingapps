import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/api_service.dart';
import '../../providers/school_provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/empty_state.dart';

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

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
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
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildGlassContainer(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                    highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height: 20,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(
                          baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                          highlightColor:
                              Colors.grey[100]!.withValues(alpha: 0.6),
                          child: Container(
                            height: 16,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
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
        schoolProvider.selectSchool(_selectedSchoolId!);

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
      schoolProvider.selectSchool(0);
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
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.all(ScreenSize.responsiveValue(
              context: context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            )),
            child: Row(
              children: [
                Container(
                  width: ScreenSize.responsiveValue(
                      context: context, mobile: 48, tablet: 56, desktop: 64),
                  height: ScreenSize.responsiveValue(
                      context: context, mobile: 48, tablet: 56, desktop: 64),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: ScreenSize.responsiveValue(
                        context: context, mobile: 24, tablet: 28, desktop: 32),
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.telegramBlue.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        school.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontSize: ScreenSize.responsiveFontSize(
                              context: context,
                              mobile: 16,
                              tablet: 18,
                              desktop: 20),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12,
                              color: AppColors.getTextSecondary(context)),
                          const SizedBox(width: 4),
                          Text(
                            'Added: ${formatDate(school.createdAt)}',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.getTextSecondary(context)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
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
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.all(ScreenSize.responsiveValue(
              context: context,
              mobile: 16,
              tablet: 20,
              desktop: 24,
            )),
            child: Row(
              children: [
                Container(
                  width: ScreenSize.responsiveValue(
                      context: context, mobile: 48, tablet: 56, desktop: 64),
                  height: ScreenSize.responsiveValue(
                      context: context, mobile: 48, tablet: 56, desktop: 64),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    size: ScreenSize.responsiveValue(
                        context: context, mobile: 24, tablet: 28, desktop: 32),
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.telegramGray,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Other School',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontSize: ScreenSize.responsiveFontSize(
                              context: context,
                              mobile: 16,
                              tablet: 18,
                              desktop: 20),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'My school is not listed',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.getTextSecondary(context)),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
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

  Widget _buildHeader(BuildContext context) {
    return _buildGlassContainer(
      child: Container(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: 24,
          tablet: 32,
          desktop: 40,
        )),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: AppColors.blueGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _headerAnimationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (0.2 * _headerAnimationController.value),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    child: Icon(Icons.school_rounded,
                        size: ScreenSize.responsiveValue(
                            context: context,
                            mobile: 48,
                            tablet: 56,
                            desktop: 64),
                        color: Colors.white),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text('Select Your School',
                style: AppTextStyles.headlineMedium
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('This helps personalize your learning experience',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    ).animate().fadeIn(duration: AppThemes.animationDurationMedium).slideY(
        begin: -0.1, end: 0, duration: AppThemes.animationDurationMedium);
  }

  @override
  Widget build(BuildContext context) {
    final schoolProvider = Provider.of<SchoolProvider>(context);

    if (schoolProvider.isLoading && !_schoolsLoaded) {
      return _buildSkeletonLoader();
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text('Select School',
            style: AppTextStyles.appBarTitle
                .copyWith(color: AppColors.getTextPrimary(context))),
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: AppColors.getTextPrimary(context)),
            onPressed: () => context.go('/')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildGlassContainer(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search schools...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context)
                          .withValues(alpha: 0.5)),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: AppColors.getTextSecondary(context)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextPrimary(context)),
                enabled: !_isOffline,
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(ScreenSize.responsiveValue(
                context: context, mobile: 16, tablet: 20, desktop: 24)),
            sliver: SliverList.separated(
              itemCount: _filteredSchools.length + 1,
              itemBuilder: (context, index) {
                if (index == _filteredSchools.length) {
                  return _buildOtherOption(context, index);
                }
                return _buildSchoolCard(
                    context, _filteredSchools[index], index);
              },
              separatorBuilder: (context, index) => const SizedBox(height: 16),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(ScreenSize.responsiveValue(
                  context: context, mobile: 16, tablet: 20, desktop: 24)),
              child: Column(
                children: [
                  if (_isOffline)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.telegramYellow.withValues(alpha: 0.2),
                            AppColors.telegramYellow.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              AppColors.telegramYellow.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded,
                              color: AppColors.telegramYellow, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You are offline. Showing cached schools.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.telegramYellow,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _selectedSchoolId == null || _isOffline
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                              ),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                        boxShadow: _selectedSchoolId != null && !_isOffline
                            ? [
                                BoxShadow(
                                  color: AppColors.telegramBlue
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ||
                                _selectedSchoolId == null ||
                                _isOffline
                            ? null
                            : _selectSchool,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: _isOffline
                              ? AppColors.getTextSecondary(context)
                              : Colors.white,
                          shadowColor: Colors.transparent,
                          disabledBackgroundColor: _selectedSchoolId == null
                              ? AppColors.telegramGray.withValues(alpha: 0.2)
                              : Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      _isOffline
                                          ? Icons.wifi_off_rounded
                                          : (_selectedSchoolId == 0
                                              ? Icons.arrow_forward_rounded
                                              : Icons.check_rounded),
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isOffline
                                        ? 'Offline'
                                        : (_selectedSchoolId == 0
                                            ? 'Continue with Other School'
                                            : 'Continue to Learning'),
                                    style: AppTextStyles.buttonMedium.copyWith(
                                        color: _isOffline
                                            ? AppColors.getTextSecondary(
                                                context)
                                            : Colors.white),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                          duration: AppThemes.animationDurationMedium,
                          delay: 600.ms)
                      .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: AppThemes.animationDurationMedium),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
