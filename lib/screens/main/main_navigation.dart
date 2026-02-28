import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/notification_provider.dart';
import '../../utils/helpers.dart';

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
  List<int> _navigationHistory = [0];
  late AnimationController _tabAnimationController;
  late Animation<double> _tabAnimation;
  Timer? _labelTimer;
  double _bottomNavBarHeight = 70.0;
  bool _showLabels = true;

  @override
  void initState() {
    super.initState();

    _tabAnimationController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
    _tabAnimation = CurvedAnimation(
        parent: _tabAnimationController, curve: Curves.easeInOut);

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
      borderRadius: BorderRadius.circular(24),
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
                AppColors.getCard(context).withOpacity(0.4),
                AppColors.getCard(context).withOpacity(0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.telegramBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildMobileNavigation() {
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: true);
    final unreadCount = notificationProvider.unreadCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            height: _showLabels ? 72 : 64,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom
                  : 0,
            ),
            child: Row(
              children: [
                _buildMobileNavItem(
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                    unreadCount: 0),
                _buildMobileNavItem(
                    index: 1,
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                    unreadCount: 0),
                _buildMobileNavItem(
                    index: 2,
                    icon: Icons.auto_graph_outlined,
                    activeIcon: Icons.auto_graph_rounded,
                    label: 'Progress',
                    unreadCount: 0),
                _buildMobileNavItem(
                    index: 3,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile',
                    unreadCount: unreadCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(
      {required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label,
      required int unreadCount}) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppColors.telegramBlue.withOpacity(0.2),
                                AppColors.telegramPurple.withOpacity(0.1),
                              ],
                            )
                          : null,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        color: isSelected
                            ? AppColors.telegramBlue
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary),
                        size: isSelected ? 22 : 20,
                      ),
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: -2,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
                            ),
                            borderRadius: BorderRadius.circular(8)),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          unreadCount > 9 ? '9+' : unreadCount.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1.0),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showLabels ? 1.0 : 0.0,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.telegramBlue
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
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
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: true);
    final unreadCount = notificationProvider.unreadCount;
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final user = authProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          _buildGlassContainer(
            width: 88,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Container(
                    width: 48,
                    height: 48,
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: AppColors.blueGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: Colors.white, size: 24),
                  ),
                  _buildTabletNavItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      unreadCount: 0),
                  const SizedBox(height: 12),
                  _buildTabletNavItem(
                      index: 1,
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Chat',
                      unreadCount: 0),
                  const SizedBox(height: 12),
                  _buildTabletNavItem(
                      index: 2,
                      icon: Icons.auto_graph_outlined,
                      activeIcon: Icons.auto_graph_rounded,
                      label: 'Progress',
                      unreadCount: 0),
                  const SizedBox(height: 12),
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
                      padding: const EdgeInsets.all(16),
                      child: Tooltip(
                        message: user.username,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.purpleGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                                user.username.substring(0, 2).toUpperCase(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildTabletNavItem(
      {required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label,
      int unreadCount = 0}) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => _onNavigationItemTapped(index),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                AppColors.telegramBlue.withOpacity(0.2),
                                AppColors.telegramPurple.withOpacity(0.1),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          Icon(isSelected ? activeIcon : icon,
                              color: isSelected
                                  ? AppColors.telegramBlue
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary),
                              size: isSelected ? 24 : 22),
                          if (unreadCount > 0)
                            Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? AppColors.telegramBlue
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNavigation() {
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: true);
    final unreadCount = notificationProvider.unreadCount;
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final user = authProvider.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          _buildGlassContainer(
            width: 260,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 24, top: 32, bottom: 32),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: AppColors.blueGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: Colors.white, size: 20),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Family Academy',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.lightTextPrimary)),
                            Text('Learning Platform',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary)),
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
                              unreadCount: 0),
                          _buildDesktopNavItem(
                              index: 1,
                              icon: Icons.chat_bubble_outline_rounded,
                              activeIcon: Icons.chat_bubble_rounded,
                              label: 'Chat Assistant',
                              description: 'AI-powered learning help',
                              unreadCount: 0),
                          _buildDesktopNavItem(
                              index: 2,
                              icon: Icons.auto_graph_outlined,
                              activeIcon: Icons.auto_graph_rounded,
                              label: 'Progress',
                              description: 'Track your learning journey',
                              unreadCount: 0),
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
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.getCard(context).withOpacity(0.4),
                            AppColors.getCard(context).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: AppColors.purpleGradient,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                  user.username.substring(0, 2).toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.username,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.lightTextPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (user.email != null &&
                                    user.email!.isNotEmpty)
                                  Text(user.email!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
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

  Widget _buildDesktopNavItem(
      {required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label,
      required String description,
      int unreadCount = 0}) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    AppColors.telegramBlue.withOpacity(0.2),
                    AppColors.telegramPurple.withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppColors.telegramBlue.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.telegramBlue.withOpacity(0.2),
                              AppColors.telegramPurple.withOpacity(0.1),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              AppColors.getCard(context).withOpacity(0.3),
                              AppColors.getCard(context).withOpacity(0.1),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Stack(
                      children: [
                        Icon(isSelected ? activeIcon : icon,
                            color: isSelected
                                ? AppColors.telegramBlue
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary),
                            size: isSelected ? 20 : 18),
                        if (unreadCount > 0)
                          Positioned(
                              top: 2,
                              right: 2,
                              child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFFF3B30),
                                      shape: BoxShape.circle))),
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
                  Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.telegramBlue
                              : (isDark
                                  ? Colors.white
                                  : AppColors.lightTextPrimary))),
                  const SizedBox(height: 2),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppColors.telegramBlue.withOpacity(0.8)
                              : (isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.telegramBlue),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: true);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateCurrentIndexFromRoute());

    if (authProvider.isAuthenticated && !authProvider.isInitializing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => authProvider.checkSession());
    }

    return ResponsiveLayout(
      mobile: _buildMobileNavigation(),
      tablet: _buildTabletNavigation(),
      desktop: _buildDesktopNavigation(),
      animateTransition: true,
    );
  }
}
