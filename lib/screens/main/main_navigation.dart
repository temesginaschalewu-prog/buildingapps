import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/connectivity_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../widgets/common/app_brand_logo.dart';

class MainNavigation extends StatefulWidget {
  final Widget child;

  const MainNavigation({super.key, required this.child});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isInitializing = false;
  bool _dataLoadedInBackground = false;
  bool _isOffline = false;
  StreamSubscription? _authStateSubscription;
  StreamSubscription? _connectivitySubscription;
  late NotificationProvider _notificationProvider;
  final List<int> _navigationHistory = [0];
  late AnimationController _tabAnimationController;
  Timer? _labelTimer;
  bool _showLabels = true;
  DateTime? _lastResumeRefreshAt;
  static const Duration _minResumeRefreshInterval = Duration(minutes: 3);
  late SettingsProvider _settingsProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySubscription?.cancel();
    _tabAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
    _labelTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showLabels = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authStateSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _notificationProvider.removeListener(_refreshUIOnNotificationChange);
    _tabAnimationController.dispose();
    _labelTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isOffline) {
      final now = DateTime.now();
      if (_lastResumeRefreshAt != null &&
          now.difference(_lastResumeRefreshAt!) < _minResumeRefreshInterval) {
        return;
      }
      _lastResumeRefreshAt = now;
      debugLog('MainNavigation', 'App resumed - refreshing cached data');
      unawaited(_refreshDataOnResume());
    }
  }

  Future<void> _refreshDataOnResume() async {
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final paymentProvider = context.read<PaymentProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final authProvider = context.read<AuthProvider>();

      if (authProvider.isAuthenticated) {
        await subscriptionProvider.loadSubscriptions(forceRefresh: true);
        await paymentProvider.loadPayments(forceRefresh: true);
        await categoryProvider.loadCategories(forceRefresh: true);

        debugLog('MainNavigation', 'Resume refresh complete');
      }
    } catch (e) {
      debugLog('MainNavigation', 'Error during resume refresh: $e');
    }
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    unawaited(_initializeUserDataInBackground());
    _setupStreamListeners();
    _updateCurrentIndexFromRoute();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (!mounted) return;
      setState(() {
        _isOffline = !isOnline;
      });
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOffline = !connectivityService.isOnline;
    });
  }

  void _setupStreamListeners() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _authStateSubscription = authProvider.authStateChanges.listen((isAuth) {
      if (!mounted) return;
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
    final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
    final paymentProvider =
        Provider.of<PaymentProvider>(context, listen: false);
    final connectivityService =
        Provider.of<ConnectivityService>(context, listen: false);

    if (authProvider.isAuthenticated && !_dataLoadedInBackground) {
      try {
        await userProvider.loadUserProfile();
        if (!mounted) return;
        await subscriptionProvider.syncFromUserProfile(userProvider.currentUser);
        if (!mounted) return;

        // Access-critical state should reconcile against backend truth on app
        // entry whenever we have connectivity, instead of relying on stale cache.
        final forceBackendRefresh = connectivityService.isOnline;
        await subscriptionProvider.loadSubscriptions(
          forceRefresh: forceBackendRefresh,
        );
        await paymentProvider.loadPayments(
          forceRefresh: forceBackendRefresh,
        );
        unawaited(notificationProvider.loadNotifications());
        _dataLoadedInBackground = true;
      } catch (e) {
        debugLog('MainNavigation', 'Background data load error: $e');
      }
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

  Widget _buildMobileNavigation() {
    final notificationProvider = Provider.of<NotificationProvider>(context);
    final unreadCount = notificationProvider.unreadCount;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          ResponsiveValues.spacingM(context),
          0,
          ResponsiveValues.spacingM(context),
          ResponsiveValues.spacingM(context),
        ),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _showLabels = true),
          onTapUp: (_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _showLabels = false);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _showLabels
                ? ResponsiveValues.bottomNavBarHeight(context) * 1.08
                : ResponsiveValues.bottomNavBarHeight(context),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? MediaQuery.of(context).viewInsets.bottom
                  : 0,
            ),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(
                ResponsiveValues.radiusXLarge(context),
              ),
              border: Border.all(
                color: AppColors.getDivider(context).withValues(alpha: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
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
    final navContainerSize = ScreenSize.isMobile(context) ? 36.0 : 38.0;
    final selectedIconSize = ScreenSize.isMobile(context) ? 25.0 : 26.0;
    final unselectedIconSize = ScreenSize.isMobile(context) ? 22.5 : 24.0;
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
                    width: navContainerSize,
                    height: navContainerSize,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.telegramBlue.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context),
                      ),
                      border: isSelected
                          ? Border.all(
                              color: AppColors.telegramBlue
                                  .withValues(alpha: 0.18),
                            )
                          : null,
                    ),
                    child: Center(
                      child: Icon(
                        isSelected ? activeIcon : icon,
                        size:
                            isSelected ? selectedIconSize : unselectedIconSize,
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
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusSmall(context)),
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
                  if (isSelected)
                    Positioned(
                      bottom: -ResponsiveValues.spacingS(context),
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: ResponsiveValues.spacingXL(context),
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.telegramBlue,
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusFull(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingXS(context)),
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
          Container(
            width: ResponsiveValues.spacingXXXXL(context) * 2,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context).withValues(alpha: 0.98),
              border: Border(
                right: BorderSide(
                  color: AppColors.getDivider(context).withValues(alpha: 0.75),
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveValues.spacingL(context),
              ),
              child: Column(
                    children: [
                      SizedBox(height: ResponsiveValues.spacingXXL(context)),
                      Container(
                        width:
                            ResponsiveValues.sidebarBrandIconContainerSize(
                                context),
                        height:
                            ResponsiveValues.sidebarBrandIconContainerSize(
                                context),
                        margin: EdgeInsets.only(
                            bottom: ResponsiveValues.spacingXXL(context)),
                        decoration: BoxDecoration(
                          color: AppColors.getCard(context),
                          borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context)),
                          border: Border.all(
                            color: AppColors.getDivider(context)
                                .withValues(alpha: 0.75),
                          ),
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context)),
                            child: Image.asset(
                              'assets/images/logo_clean.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.school_rounded,
                                    size: ResponsiveValues.iconSizeL(context),
                                    color: AppColors.getTextSecondary(context));
                              },
                            ),
                          ),
                        ),
                      ),
                      _buildTabletNavItem(
                        index: 0,
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home_rounded,
                        label: 'Home',
                      ),
                      SizedBox(height: ResponsiveValues.spacingM(context)),
                      _buildTabletNavItem(
                        index: 1,
                        icon: Icons.chat_bubble_outline_rounded,
                        activeIcon: Icons.chat_bubble_rounded,
                        label: 'Chat',
                      ),
                      SizedBox(height: ResponsiveValues.spacingM(context)),
                      _buildTabletNavItem(
                        index: 2,
                        icon: Icons.auto_graph_outlined,
                        activeIcon: Icons.auto_graph_rounded,
                        label: 'Progress',
                      ),
                      SizedBox(height: ResponsiveValues.spacingM(context)),
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
                              ResponsiveValues.spacingL(context)),
                          child: Tooltip(
                            message: user.username,
                            child: _buildSidebarAvatar(user),
                          ),
                        ),
                      SizedBox(height: ResponsiveValues.spacingL(context)),
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
    final navContainerSize = ScreenSize.isDesktop(context) ? 46.0 : 42.0;
    final selectedIconSize = ScreenSize.isDesktop(context) ? 29.0 : 27.0;
    final unselectedIconSize = ScreenSize.isDesktop(context) ? 26.0 : 24.0;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => _onNavigationItemTapped(index),
        child: Container(
          margin: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingS(context)),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: navContainerSize,
                    height: navContainerSize,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.telegramBlue.withValues(alpha: 0.10)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context)),
                      border: isSelected
                          ? Border.all(
                              color: AppColors.telegramBlue
                                  .withValues(alpha: 0.16),
                            )
                          : null,
                    ),
                    child: Center(
                      child: Stack(
                        children: [
                          Icon(
                            isSelected ? activeIcon : icon,
                            size:
                                isSelected ? selectedIconSize : unselectedIconSize,
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
                                    shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveValues.spacingXS(context)),
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
    final avatarSize = ResponsiveValues.sidebarAvatarSize(context);
    final hasImage = user.profileImage != null && user.profileImage!.isNotEmpty;
    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: hasImage ? null : AppColors.getCard(context),
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(user.profileImage!), fit: BoxFit.cover)
            : null,
        border: Border.all(
          color: AppColors.getDivider(context).withValues(alpha: 0.8),
        ),
      ),
      child: !hasImage
          ? Center(
              child: Text(
                user.username.substring(0, 2).toUpperCase(),
                style: TextStyle(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.bold,
                  fontSize:
                      ResponsiveValues.sidebarAvatarInitialsFontSize(context),
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
          Container(
            width: ResponsiveValues.desktopSidebarWidth(context),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context).withValues(alpha: 0.98),
              border: Border(
                right: BorderSide(
                  color: AppColors.getDivider(context).withValues(alpha: 0.75),
                ),
              ),
            ),
            child: Padding(
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
                              width: ResponsiveValues
                                  .sidebarBrandIconContainerSize(context),
                              height: ResponsiveValues
                                  .sidebarBrandIconContainerSize(context),
                              margin: EdgeInsets.only(
                                  right: ResponsiveValues.spacingM(context)),
                              decoration: BoxDecoration(
                                color: AppColors.getCard(context),
                                borderRadius: BorderRadius.circular(
                                    ResponsiveValues.radiusSmall(context)),
                                border: Border.all(
                                  color: AppColors.getDivider(context)
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                              child: Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                      ResponsiveValues.radiusSmall(context)),
                                  child: Image.asset(
                                    'assets/images/logo_clean.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.school_rounded,
                                          size: ResponsiveValues.iconSizeS(
                                              context),
                                          color:
                                              AppColors.getTextSecondary(context));
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Family Academy',
                                  style: TextStyle(
                                    fontSize: ResponsiveValues.fontTitleLarge(
                                        context),
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
                              ResponsiveValues.spacingL(context)),
                          padding: ResponsiveValues.cardPadding(context),
                          decoration: BoxDecoration(
                            color: AppColors.getCard(context),
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context)),
                            border: Border.all(
                              color: AppColors.getDivider(context)
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildSidebarAvatar(user),
                              SizedBox(
                                  width: ResponsiveValues.spacingM(context)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.username,
                                      style: TextStyle(
                                        fontSize:
                                            ResponsiveValues.fontTitleMedium(
                                                context),
                                        fontWeight: FontWeight.w600,
                                        color:
                                            AppColors.getTextPrimary(context),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (user.email != null &&
                                        user.email!.isNotEmpty)
                                      Text(
                                        user.email!,
                                        style: TextStyle(
                                          fontSize:
                                              ResponsiveValues.fontBodySmall(
                                                  context),
                                          color: AppColors.getTextSecondary(
                                              context),
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
          color: isSelected
              ? AppColors.telegramBlue.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppColors.telegramBlue.withValues(alpha: 0.16),
                )
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
                    color: isSelected
                        ? AppColors.telegramBlue.withValues(alpha: 0.10)
                        : AppColors.getCard(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.telegramBlue.withValues(alpha: 0.14)
                          : AppColors.getDivider(context).withValues(alpha: 0.55),
                    ),
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
                                    shape: BoxShape.circle),
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
                      fontSize: ResponsiveValues.fontBodyMedium(context),
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
                      fontSize: ResponsiveValues.fontBodySmall(context),
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

  bool _shouldShowStartupShell({
    required AuthProvider authProvider,
    required UserProvider userProvider,
    required CategoryProvider categoryProvider,
    required SubscriptionProvider subscriptionProvider,
    required PaymentProvider paymentProvider,
  }) {
    final location = GoRouterState.of(context).uri.toString();
    final isHomeRoute = location == '/' || location.startsWith('/?');
    final hasBootstrapData = userProvider.hasInitialData ||
        categoryProvider.hasInitialData ||
        subscriptionProvider.hasInitialData ||
        paymentProvider.hasInitialData;

    return authProvider.isAuthenticated &&
        isHomeRoute &&
        (_isInitializing || !_dataLoadedInBackground) &&
        !hasBootstrapData;
  }

  Widget _buildStartupShell() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: ResponsiveValues.screenPadding(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppBrandLogo(
                    size: ResponsiveValues.splashLogoSize(context) * 0.72,
                    borderRadius: ResponsiveValues.radiusXLarge(context),
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  Text(
                    _settingsProvider.getStartupShellTitle(),
                    style: AppTextStyles.headlineSmall(context).copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveValues.spacingS(context)),
                  Text(
                    _settingsProvider.getStartupShellMessage(),
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.55,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: ResponsiveValues.spacingXL(context)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(ResponsiveValues.spacingL(context)),
                    decoration: BoxDecoration(
                      color: AppColors.getSurface(context),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context),
                      ),
                      border: Border.all(
                        color:
                            AppColors.getDivider(context).withValues(alpha: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.overlayLight.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(999),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.telegramBlue,
                          ),
                          backgroundColor: AppColors.getDivider(context)
                              .withValues(alpha: 0.35),
                        ),
                        SizedBox(height: ResponsiveValues.spacingL(context)),
                        _buildShellLine(0.94),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        _buildShellLine(0.72),
                        SizedBox(height: ResponsiveValues.spacingM(context)),
                        Row(
                          children: [
                            Expanded(child: _buildShellPill()),
                            SizedBox(width: ResponsiveValues.spacingM(context)),
                            Expanded(child: _buildShellPill()),
                          ],
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

  Widget _buildShellLine(double widthFactor) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.getDivider(context).withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildShellPill() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.getDivider(context).withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(
          ResponsiveValues.radiusMedium(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateCurrentIndexFromRoute());
    if (authProvider.isAuthenticated && authProvider.isInitialized) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => authProvider.checkSession());
    }
    if (_shouldShowStartupShell(
      authProvider: authProvider,
      userProvider: userProvider,
      categoryProvider: categoryProvider,
      subscriptionProvider: subscriptionProvider,
      paymentProvider: paymentProvider,
    )) {
      return _buildStartupShell();
    }
    if (ScreenSize.isMobile(context)) {
      return _buildMobileNavigation();
    } else if (ScreenSize.isTablet(context)) {
      return _buildTabletNavigation();
    } else {
      return _buildDesktopNavigation();
    }
  }
}
