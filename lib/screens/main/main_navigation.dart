import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/subscription_provider.dart';

class MainNavigation extends StatefulWidget {
  final Widget child;

  const MainNavigation({
    super.key,
    required this.child,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isInitializing = false;
  bool _dataLoadedInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserDataInBackground();
    });
  }

  // Load data in background without blocking UI
  Future<void> _initializeUserDataInBackground() async {
    if (_isInitializing) return;

    _isInitializing = true;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final subscriptionProvider =
        Provider.of<SubscriptionProvider>(context, listen: false);

    if (authProvider.isAuthenticated && !_dataLoadedInBackground) {
      try {
        // Load essential data in background
        await userProvider.loadUserProfile();

        // Load other data in background without waiting
        unawaited(userProvider.loadNotifications());
        unawaited(userProvider.loadPayments());
        unawaited(subscriptionProvider.loadSubscriptions());

        _dataLoadedInBackground = true;
      } catch (e) {
        // Silently fail, data will load when screens need it
      }
    }

    _isInitializing = false;
  }

  // Update current index based on route
  void _updateCurrentIndex() {
    final location = GoRouterState.of(context).uri.toString();

    if (location == '/' || location.startsWith('/?')) {
      _currentIndex = 0;
    } else if (location == '/chatbot' || location.startsWith('/chatbot?')) {
      _currentIndex = 1;
    } else if (location == '/progress' || location.startsWith('/progress?')) {
      _currentIndex = 2;
    } else if (location == '/profile' || location.startsWith('/profile?')) {
      _currentIndex = 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        GoRouter.of(context).go('/auth/login');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Update index based on current route
    _updateCurrentIndex();

    return Scaffold(
      body: widget.child, // Use the child from ShellRoute
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
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
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chatbot',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
