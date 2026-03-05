import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/widgets/common/responsive_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/notification_provider.dart';

class MainNavigation extends StatefulWidget {
  final Widget child;

  const MainNavigation({super.key, required this.child});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isInitializing = false;
  bool _dataLoadedInBackground = false;
  StreamSubscription? _authStateSubscription;
  late NotificationProvider _notificationProvider;
  final List<int> _navigationHistory = [0];
  late AnimationController _tabAnimationController;
  Timer? _labelTimer;
  bool _showLabels = true;

  @override
  void initState() {
    super.initState();

    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserDataInBackground();
      _setupStreamListeners();
      _updateCurrentIndexFromRoute();
    });

    _labelTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showLabels = false);
    });
  }

  void _setupStreamListeners() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    _authStateSubscription = authProvider.authStateChanges.listen((isAuth) {
      if (isAuth) {
        _initializeUserDataInBackground();
      } else {
        setState(() => _dataLoadedInBackground = false);
      }
    });

    _notificationProvider.addListener(_refreshUIOnNotificationChange);
  }

  void _refreshUIOnNotificationChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initializeUserDataInBackground() async {
    if (_isInitializing || _dataLoadedInBackground) return;

    _isInitializing = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);
    final categoryProvider =
        Provider.of<CategoryProvider>(context, listen: false);
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);

    if (authProvider.isAuthenticated && !_dataLoadedInBackground) {
      try {
        await userProvider.loadUserProfile();
        await Future.wait([
          subscriptionProvider.loadSubscriptions(),
          categoryProvider.loadCategoriesWithSubscriptionCheck()
        ]);
        unawaited(notificationProvider.loadNotifications());
        unawaited(userProvider.loadPayments());

        _dataLoadedInBackground = true;
      } catch (e) {}
    }

    _isInitializing = false;
  }

  void _updateCurrentIndexFromRoute() {
    if (!mounted) return;

    final location = GoRouterState.of(context).uri.toString();

    if (location == '/' || location.startsWith('/?')) {
      _setCurrentIndexWithAnimation(0);
    } else if (location == '/chatbot' || location.startsWith('/chatbot?')) {
      _setCurrentIndexWithAnimation(1);
    } else if (location == '/progress' || location.startsWith('/progress?')) {
      _setCurrentIndexWithAnimation(2);
    } else if (location == '/profile' || location.startsWith('/profile?')) {
      _setCurrentIndexWithAnimation(3);
    }
  }

  void _setCurrentIndexWithAnimation(int newIndex) {
    if (newIndex != _currentIndex) {
      _navigationHistory.add(newIndex);
      if (_navigationHistory.length > 5) _navigationHistory.removeAt(0);

      if (!_showLabels) {
        setState(() => _showLabels = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _showLabels = false);
        });
      }

      _tabAnimationController.reset();
      _tabAnimationController.forward();

      setState(() => _currentIndex = newIndex);
    }
  }

  Widget _buildGlassContainer(
      {required Widget child, double? width, double? height}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: width,
          height: height,
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

  Widget _buildMobileNavigation() {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notificationProvider.unreadCount;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: GestureDetector(
        onTapDown: (_) => setState(() => _showLabels = true),
        onTapUp: (_) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _showLabels = false);
          });
        },
        child: _buildGlassContainer(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _showLabels
                ? ResponsiveValues.bottomNavBarHeight(context) * 1.2
                : ResponsiveValues.bottomNavBarHeight(context),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom
                  : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMobileNavItem(
                  index: 0,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  unreadCount: 0,
                ),
                _buildMobileNavItem(
                  index: 1,
                  icon: Icons.chat_bubble_outline_rounded,
                  activeIcon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  unreadCount: 0,
                ),
                _buildMobileNavItem(
                  index: 2,
                  icon: Icons.auto_graph_outlined,
                  activeIcon: Icons.auto_graph_rounded,
                  label: 'Progress',
                  unreadCount: 0,
                ),
                _buildMobileNavItem(
                  index: 3,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  unreadCount: unreadCount,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int unreadCount,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onNavigationItemTapped(index),
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: ResponsiveValues.iconSizeL(context),
                    height: ResponsiveValues.iconSizeL(context),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppColors.telegramBlue.withValues(alpha: 0.2),
                                AppColors.telegramPurple.withValues(alpha: 0.1),
                              ],
                            )
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: ResponsiveIcon(
                        isSelected ? activeIcon : icon,
                        size: isSelected
                            ? ResponsiveValues.iconSizeM(context)
                            : ResponsiveValues.iconSizeS(context),
                        color: isSelected
                            ? AppColors.telegramBlue
                            : AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -ResponsiveValues.spacingXXS(context),
                      right: ResponsiveValues.spacingS(context),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingXXS(context),
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusSmall(context),
                          ),
                        ),
                        constraints: BoxConstraints(
                          minWidth: ResponsiveValues.spacingL(context),
                          minHeight: ResponsiveValues.spacingL(context),
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : unreadCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize:
                                  ResponsiveValues.fontLabelSmall(context) *
                                      0.9,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const ResponsiveSizedBox(height: AppSpacing.xs),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showLabels ? 1.0 : 0.0,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: ResponsiveValues.fontBottomNavLabel(context),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.telegramBlue
                        : AppColors.getTextSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletNavigation() {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notificationProvider.unreadCount;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      body: Row(
        children: [
          _buildGlassContainer(
            width: ResponsiveValues.spacingXXXXL(context) * 2,
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveValues.spacingL(context),
              ),
              child: Column(
                children: [
                  const ResponsiveSizedBox(height: AppSpacing.xxl),
                  Container(
                    width: ResponsiveValues.iconSizeXL(context) * 1.5,
                    height: ResponsiveValues.iconSizeXL(context) * 1.5,
                    margin: EdgeInsets.only(
                      bottom: ResponsiveValues.spacingXXL(context),
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.blueGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                    child: Center(
                      child: ResponsiveIcon(
                        Icons.school_rounded,
                        size: ResponsiveValues.iconSizeL(context),
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _buildTabletNavItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  const ResponsiveSizedBox(height: AppSpacing.m),
                  _buildTabletNavItem(
                    index: 1,
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                  ),
                  const ResponsiveSizedBox(height: AppSpacing.m),
                  _buildTabletNavItem(
                    index: 2,
                    icon: Icons.auto_graph_outlined,
                    activeIcon: Icons.auto_graph_rounded,
                    label: 'Progress',
                  ),
                  const ResponsiveSizedBox(height: AppSpacing.m),
                  _buildTabletNavItem(
                    index: 3,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    unreadCount: unreadCount,
                  ),
                  const Spacer(),
                  if (user != null)
                    Padding(
                      padding: EdgeInsets.all(
                        ResponsiveValues.spacingL(context),
                      ),
                      child: Tooltip(
                        message: user.username,
                        child: _buildSidebarAvatar(user),
                      ),
                    ),
                  const ResponsiveSizedBox(height: AppSpacing.l),
                ],
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildTabletNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int unreadCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => _onNavigationItemTapped(index),
        child: Container(
          margin: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingS(context),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: ResponsiveValues.iconSizeXL(context) * 1.5,
                    height: ResponsiveValues.iconSizeXL(context) * 1.5,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppColors.telegramBlue.withValues(alpha: 0.2),
                                AppColors.telegramPurple.withValues(alpha: 0.1),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          ResponsiveIcon(
                            isSelected ? activeIcon : icon,
                            size: isSelected
                                ? ResponsiveValues.iconSizeL(context)
                                : ResponsiveValues.iconSizeM(context),
                            color: isSelected
                                ? AppColors.telegramBlue
                                : AppColors.getTextSecondary(context),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: ResponsiveValues.spacingXXS(context),
                              right: ResponsiveValues.spacingXXS(context),
                              child: Container(
                                width: ResponsiveValues.spacingS(context),
                                height: ResponsiveValues.spacingS(context),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const ResponsiveSizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: ResponsiveValues.fontBottomNavLabel(context),
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? AppColors.telegramBlue
                      : AppColors.getTextSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarAvatar(User user) {
    final avatarSize = ResponsiveValues.iconSizeXL(context) * 2.3;
    final hasImage = user.profileImage != null && user.profileImage!.isNotEmpty;

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(user.profileImage!),
                fit: BoxFit.cover,
              )
            : null,
        gradient: !hasImage
            ? const LinearGradient(
                colors: AppColors.purpleGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: !hasImage
          ? Center(
              child: Text(
                user.username.substring(0, 2).toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveValues.fontTitleMedium(context) * 0.10,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildDesktopNavigation() {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notificationProvider.unreadCount;
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      body: Row(
        children: [
          _buildGlassContainer(
            width: ResponsiveValues.desktopSidebarWidth(context),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveValues.spacingL(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: ResponsiveValues.spacingXL(context),
                      top: ResponsiveValues.spacingXXL(context),
                      bottom: ResponsiveValues.spacingXXL(context),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: ResponsiveValues.iconSizeXL(context) * 1.5,
                          height: ResponsiveValues.iconSizeXL(context) * 1.5,
                          margin: EdgeInsets.only(
                            right: ResponsiveValues.spacingM(context),
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: AppColors.blueGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusSmall(context),
                            ),
                          ),
                          child: Center(
                            child: ResponsiveIcon(
                              Icons.school_rounded,
                              size: ResponsiveValues.iconSizeS(context),
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Family Academy',
                              style: TextStyle(
                                fontSize:
                                    ResponsiveValues.fontTitleLarge(context),
                                fontWeight: FontWeight.w700,
                                color: AppColors.getTextPrimary(context),
                              ),
                            ),
                            Text(
                              'Learning Platform',
                              style: TextStyle(
                                fontSize:
                                    ResponsiveValues.fontBodySmall(context),
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildDesktopNavItem(
                            index: 0,
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: 'Home',
                            description: 'Discover courses and content',
                          ),
                          _buildDesktopNavItem(
                            index: 1,
                            icon: Icons.chat_bubble_outline_rounded,
                            activeIcon: Icons.chat_bubble_rounded,
                            label: 'Chat Assistant',
                            description: 'AI-powered learning help',
                          ),
                          _buildDesktopNavItem(
                            index: 2,
                            icon: Icons.auto_graph_outlined,
                            activeIcon: Icons.auto_graph_rounded,
                            label: 'Progress',
                            description: 'Track your learning journey',
                          ),
                          _buildDesktopNavItem(
                            index: 3,
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: 'Profile',
                            description: 'Account and settings',
                            unreadCount: unreadCount,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (user != null)
                    Container(
                      margin: EdgeInsets.all(
                        ResponsiveValues.spacingL(context),
                      ),
                      padding: ResponsiveValues.cardPadding(context),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.getCard(context).withValues(alpha: 0.4),
                            AppColors.getCard(context).withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildSidebarAvatar(user),
                          const ResponsiveSizedBox(width: AppSpacing.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.username,
                                  style: TextStyle(
                                    fontSize: ResponsiveValues.fontTitleMedium(
                                        context),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.getTextPrimary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (user.email != null &&
                                    user.email!.isNotEmpty)
                                  Text(
                                    user.email!,
                                    style: TextStyle(
                                      fontSize: ResponsiveValues.fontBodySmall(
                                          context),
                                      color:
                                          AppColors.getTextSecondary(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String description,
    int unreadCount = 0,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onNavigationItemTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.telegramBlue.withValues(alpha: 0.2),
                    AppColors.telegramPurple.withValues(alpha: 0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: AppColors.telegramBlue.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withValues(alpha: 0.2),
                              AppColors.telegramPurple.withValues(alpha: 0.1),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              AppColors.getCard(context).withValues(alpha: 0.3),
                              AppColors.getCard(context).withValues(alpha: 0.1),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Stack(
                      children: [
                        Icon(
                          isSelected ? activeIcon : icon,
                          color: isSelected
                              ? AppColors.telegramBlue
                              : AppColors.getTextSecondary(context),
                          size: isSelected ? 22 : 20,
                        ),
                        if (unreadCount > 0)
                          const Positioned(
                            top: 2,
                            right: 2,
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFFF3B30),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.telegramBlue
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppColors.telegramBlue.withValues(alpha: 0.8)
                          : AppColors.getTextSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.telegramBlue,
              ),
          ],
        ),
      ),
    );
  }

  void _onNavigationItemTapped(int index) {
    if (!mounted) return;

    _setCurrentIndexWithAnimation(index);

    switch (index) {
      case 0:
        GoRouter.of(context).go('/');
        break;
      case 1:
        GoRouter.of(context).go('/chatbot');
        break;
      case 2:
        GoRouter.of(context).go('/progress');
        break;
      case 3:
        GoRouter.of(context).go('/profile');
        break;
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _notificationProvider.removeListener(_refreshUIOnNotificationChange);
    _tabAnimationController.dispose();
    _labelTimer?.cancel();
    super.dispose();
  }

  Widget _buildMobileLayout() {
    return _buildMobileNavigation();
  }

  Widget _buildTabletLayout() {
    return _buildTabletNavigation();
  }

  Widget _buildDesktopLayout() {
    return _buildDesktopNavigation();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateCurrentIndexFromRoute());

    if (authProvider.isAuthenticated && !authProvider.isInitializing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => authProvider.checkSession());
    }

    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}
