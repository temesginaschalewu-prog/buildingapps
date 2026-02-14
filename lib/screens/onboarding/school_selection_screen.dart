import 'dart:async';
import 'package:familyacademyclient/models/school_model.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import '../../services/api_service.dart';
import '../../providers/school_provider.dart';
import '../../providers/auth_provider.dart';
import '../../themes/app_themes.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';
import '../../utils/helpers.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen>
    with TickerProviderStateMixin {
  int? _selectedSchoolId;
  bool _isLoading = false;
  bool _schoolsLoaded = false;
  Timer? _debounceTimer;

  late AnimationController _headerAnimationController;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchools();
      _headerAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _headerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadSchools({bool forceRefresh = false}) async {
    if (_schoolsLoaded && !forceRefresh) return;

    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

    try {
      await schoolProvider.loadSchools(forceRefresh: forceRefresh);
      _schoolsLoaded = true;
    } catch (e) {
      debugLog('SchoolSelectionScreen', 'Error loading schools: $e');
    }
  }

  void _handleSchoolSelection(int? schoolId) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _selectedSchoolId = schoolId);
      }
    });
  }

  Future<void> _selectSchool() async {
    if (_selectedSchoolId == null) {
      showSnackBar(context, 'Please select a school', isError: true);
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
      if (!mounted) return;

      if (!authProvider.isAuthenticated) {
        throw Exception('Session expired. Please login again.');
      }

      debugLog('SchoolSelection', 'Selecting school: $_selectedSchoolId');

      final response = await apiService.selectSchool(_selectedSchoolId!);

      if (!mounted) return;

      if (response.success) {
        // Cache the selection
        schoolProvider.selectSchool(_selectedSchoolId!);

        final currentUser = authProvider.currentUser;
        if (currentUser != null) {
          final updatedUser = currentUser.copyWith(schoolId: _selectedSchoolId);
          await authProvider.updateUser(updatedUser);
        }

        showSnackBar(context, 'School selected successfully');

        await Future.delayed(const Duration(milliseconds: 100));

        if (!mounted) return;
        context.go('/');
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (!mounted) return;

      debugLog('SchoolSelection', 'Error details: $e');

      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        showSnackBar(
          context,
          'Your session has expired. Please login again.',
          isError: true,
        );

        await Future.delayed(const Duration(seconds: 1));

        await authProvider.logout();

        if (mounted) {
          context.go('/auth/login');
        }
      } else {
        showSnackBar(context, 'Failed to select school: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleOtherSchoolSelection() async {
    if (!mounted) return;

    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      schoolProvider.selectSchool(0);

      showSnackBar(context, 'Proceeding without specific school selection');

      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, 'Failed to proceed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSchoolCard(BuildContext context, School school, int index) {
    final isSelected = _selectedSchoolId == school.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSchoolSelection(school.id),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        splashColor: AppColors.telegramBlue.withOpacity(0.1),
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
              color: isSelected
                  ? AppColors.telegramBlue
                  : Theme.of(context).dividerColor,
              width: isSelected ? 2.0 : 0.5,
            ),
          ),
          child: Row(
            children: [
              // School icon
              Container(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.telegramBlue.withOpacity(0.1)
                      : AppColors.getSurface(context),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.school_rounded,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
                  color: isSelected
                      ? AppColors.telegramBlue
                      : AppColors.telegramBlue.withOpacity(0.5),
                ),
              ),

              SizedBox(width: AppThemes.spacingL),

              // School info
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
                          desktop: 20,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppColors.getTextSecondary(context),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Added: ${formatDate(school.createdAt)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.getTextSecondary(context).withOpacity(0.3),
                    width: 2,
                  ),
                  color:
                      isSelected ? AppColors.telegramBlue : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
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
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  Widget _buildOtherOption(BuildContext context, int index) {
    final isSelected = _selectedSchoolId == 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSchoolSelection(0),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        splashColor: AppColors.telegramBlue.withOpacity(0.1),
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
              color: isSelected
                  ? AppColors.telegramBlue
                  : Theme.of(context).dividerColor,
              width: isSelected ? 2.0 : 0.5,
            ),
          ),
          child: Row(
            children: [
              // Other school icon
              Container(
                width: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                height: ScreenSize.responsiveValue(
                  context: context,
                  mobile: 48,
                  tablet: 56,
                  desktop: 64,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.telegramBlue.withOpacity(0.1)
                      : AppColors.getSurface(context),
                  borderRadius:
                      BorderRadius.circular(AppThemes.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: ScreenSize.responsiveValue(
                    context: context,
                    mobile: 24,
                    tablet: 28,
                    desktop: 32,
                  ),
                  color: isSelected
                      ? AppColors.telegramBlue
                      : AppColors.telegramGray,
                ),
              ),

              SizedBox(width: AppThemes.spacingL),

              // Other school info
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
                          desktop: 20,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'My school is not listed',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.getTextSecondary(context).withOpacity(0.3),
                    width: 2,
                  ),
                  color:
                      isSelected ? AppColors.telegramBlue : Colors.transparent,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
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
        .slideX(
          begin: 0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
          delay: (index * 50).ms,
        );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.telegramBlue,
                ),
              ),
            ),
            SizedBox(height: AppThemes.spacingL),
            Text(
              'Loading schools...',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingXL),
                decoration: BoxDecoration(
                  color: AppColors.telegramRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: AppColors.telegramRed,
                ),
              ),
              SizedBox(height: AppThemes.spacingXL),
              Text(
                'Failed to load schools',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Please check your internet connection and try again',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXXL),
              ElevatedButton(
                onPressed: () => _loadSchools(forceRefresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemes.spacingXL,
                    vertical: AppThemes.spacingM,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                ),
                child: Text(
                  'Retry',
                  style: AppTextStyles.buttonMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Select School',
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
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(AppThemes.spacingXL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(AppThemes.spacingXL),
                decoration: BoxDecoration(
                  color: AppColors.telegramYellow.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_outlined,
                  size: 64,
                  color: AppColors.telegramYellow,
                ),
              ),
              SizedBox(height: AppThemes.spacingXL),
              Text(
                'No schools available',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppThemes.spacingL),
              Text(
                'Schools will be added by your administrator.\nYou can proceed with "Other School" for now.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppThemes.spacingXXL),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleOtherSchoolSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.telegramBlue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppThemes.spacingXL,
                    vertical: AppThemes.spacingL,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusMedium),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'Continue with Other School',
                        style: AppTextStyles.buttonMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(
        ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingXL,
          tablet: AppThemes.spacingXXL,
          desktop: AppThemes.spacingXXXL,
        ),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.blueGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppThemes.borderRadiusLarge),
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _headerAnimationController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.8 + (0.2 * _headerAnimationController.value),
                child: Container(
                  padding: EdgeInsets.all(AppThemes.spacingL),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    size: ScreenSize.responsiveValue(
                      context: context,
                      mobile: 48,
                      tablet: 56,
                      desktop: 64,
                    ),
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: AppThemes.spacingL),
          Text(
            'Select Your School',
            style: AppTextStyles.headlineMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppThemes.spacingS),
          Text(
            'This helps personalize your learning experience',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          duration: AppThemes.animationDurationMedium,
        )
        .slideY(
          begin: -0.1,
          end: 0,
          duration: AppThemes.animationDurationMedium,
        );
  }

  Widget _buildSchoolsList(List<School> schools) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        title: Text(
          'Select School',
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
          onPressed: () => context.go('/'),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: _buildHeader(context),
          ),

          // Schools list
          SliverPadding(
            padding: EdgeInsets.all(
              ScreenSize.responsiveValue(
                context: context,
                mobile: AppThemes.spacingL,
                tablet: AppThemes.spacingXL,
                desktop: AppThemes.spacingXXL,
              ),
            ),
            sliver: SliverList.separated(
              itemCount: schools.length + 1, // +1 for "Other School"
              itemBuilder: (context, index) {
                if (index == schools.length) {
                  return _buildOtherOption(context, index);
                }
                return _buildSchoolCard(context, schools[index], index);
              },
              separatorBuilder: (context, index) {
                return SizedBox(height: AppThemes.spacingL);
              },
            ),
          ),

          // Continue button
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(
                ScreenSize.responsiveValue(
                  context: context,
                  mobile: AppThemes.spacingL,
                  tablet: AppThemes.spacingXL,
                  desktop: AppThemes.spacingXXL,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(height: AppThemes.spacingL),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading || _selectedSchoolId == null
                          ? null
                          : _selectSchool,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedSchoolId == null
                            ? AppColors.telegramGray.withOpacity(0.3)
                            : AppColors.telegramBlue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.telegramGray.withOpacity(0.2),
                        padding: EdgeInsets.symmetric(
                          vertical: AppThemes.spacingL,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _selectedSchoolId == 0
                                      ? Icons.arrow_forward_rounded
                                      : Icons.check_rounded,
                                  size: 20,
                                ),
                                SizedBox(width: AppThemes.spacingS),
                                Text(
                                  _selectedSchoolId == 0
                                      ? 'Continue with Other School'
                                      : 'Continue to Learning',
                                  style: AppTextStyles.buttonMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  )
                      .animate()
                      .fadeIn(
                        duration: AppThemes.animationDurationMedium,
                        delay: 600.ms,
                      )
                      .slideY(
                        begin: 0.1,
                        end: 0,
                        duration: AppThemes.animationDurationMedium,
                      ),
                  SizedBox(height: AppThemes.spacingXXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolProvider = Provider.of<SchoolProvider>(context);

    if (schoolProvider.isLoading) {
      return _buildLoadingState();
    }

    if (schoolProvider.hasError) {
      return _buildErrorState();
    }

    if (schoolProvider.schools.isEmpty) {
      return _buildEmptyState();
    }

    return _buildSchoolsList(schoolProvider.schools);
  }
}
