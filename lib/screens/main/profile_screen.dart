import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/profile/menu_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
              ),
              child: Row(
                children: [
                  // In lib/screens/main/profile_screen.dart, update the CircleAvatar:
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: user?.fullProfileImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.network(
                              user!.fullProfileImageUrl!,
                              fit: BoxFit.cover,
                              width: 80,
                              height: 80,
                              errorBuilder: (context, error, stackTrace) {
                                debugLog('ProfileScreen',
                                    'Failed to load image: ${user!.fullProfileImageUrl}');
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Center(
                                    child: Text(
                                      user?.username
                                              .substring(0, 1)
                                              .toUpperCase() ??
                                          'S',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              borderRadius: BorderRadius.circular(40),
                            ),
                            child: Center(
                              child: Text(
                                user?.username.substring(0, 1).toUpperCase() ??
                                    'S',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.username ?? 'Student',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(
                            user?.accountStatus.toUpperCase() ?? 'UNPAID',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: user?.isActive == true
                              ? Colors.green.withOpacity(0.1)
                              : user?.isExpired == true
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                          side: BorderSide(
                            color: user?.isActive == true
                                ? Colors.green
                                : user?.isExpired == true
                                    ? Colors.orange
                                    : Colors.grey,
                          ),
                        ),
                        if (user?.schoolId != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'School ID: ${user!.schoolId}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            const SizedBox(height: 16),
            MenuItem(
              icon: Icons.subscriptions,
              title: 'Subscriptions',
              onTap: () {
                context.push('/subscriptions');
              },
            ),
            MenuItem(
              icon: Icons.tv,
              title: 'TV Device Pairing',
              onTap: () {
                context.push('/tv-pairing');
              },
            ),
            MenuItem(
              icon: Icons.family_restroom,
              title: 'Parent Controls',
              onTap: () {
                context.push('/parent-link');
              },
            ),
            MenuItem(
              icon: Icons.support,
              title: 'Support',
              onTap: () {
                context.push('/support');
              },
            ),
            MenuItem(
              icon: Icons.info,
              title: 'App Info',
              onTap: () {
                _showAppInfo();
              },
            ),

            // Settings Section
            const Padding(
              padding: EdgeInsets.all(16),
              child: Divider(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Switch(
                    value: true,
                    onChanged: (value) {
                      // Update notification settings
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dark Mode',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Switch(
                    value: themeProvider.themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      themeProvider.setTheme(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ],
              ),
            ),

            // Logout Button
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await authProvider.logout();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showAppInfo() {
    showAboutDialog(
      context: context,
      applicationName: 'Family Academy',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Family Academy',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Family Academy is an educational platform designed to help students learn effectively.',
        ),
        const SizedBox(height: 8),
        const Text(
          'For support, please contact us through the support section.',
        ),
      ],
    );
  }
}
