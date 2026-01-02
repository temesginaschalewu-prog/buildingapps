import 'dart:io';
import 'package:familyacademyclient/utils/api_response.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/device_provider.dart';
import '../../utils/helpers.dart';
import '../../widgets/auth/auth_form_field.dart';
import '../../widgets/auth/password_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _deviceId;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mounted) {
        _initializeDevice();
      }
    });
  }

  Future<void> _initializeDevice() async {
    if (!_mounted) return;

    try {
      final deviceProvider =
          Provider.of<DeviceProvider>(context, listen: false);
      await deviceProvider.initialize();
      if (_mounted) {
        setState(() {
          _deviceId = deviceProvider.deviceId;
        });
      }
      debugLog('LoginScreen', 'Device ID: $_deviceId');
    } catch (e) {
      debugLog('LoginScreen', 'Error initializing device: $e');
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deviceId == null) {
      showSnackBar(context, 'Device initialization failed', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    try {
      await authProvider.studentLogin(username, password, _deviceId!);

      if (authProvider.error == null && authProvider.isAuthenticated) {
        // Check if device change is required
        if (authProvider.deviceChangeRequired) {
          // Navigate to device change screen
          context.go('/device-change', extra: {
            'username': username,
            'password': password,
            'deviceId': _deviceId,
            'currentDeviceId': authProvider.currentDeviceId,
          });
        } else {
          // Check if school is selected
          if (authProvider.user?.schoolId == null) {
            context.go('/school-selection');
          } else {
            context.go('/');
          }
        }
      } else {
        showSnackBar(context, authProvider.error ?? 'Login failed',
            isError: true);
      }
    } catch (e) {
      if (e is ApiError && e.data?['action'] == 'device_change_required') {
        // Navigate to device change screen
        context.go('/device-change', extra: {
          'username': username,
          'password': password,
          'deviceId': _deviceId,
          'currentDeviceId': e.data?['currentDeviceId'],
        });
      } else {
        showSnackBar(context, 'Login failed: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome Back',
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Login to continue your learning journey',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                AuthFormField(
                  controller: _usernameController,
                  label: 'Username',
                  hintText: 'Enter your username',
                  prefixIcon: Icons.person,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                PasswordField(
                  controller: _passwordController,
                  label: 'Password',
                  hintText: 'Enter your password',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    context.go('/auth/register');
                  },
                  child: const Text('Don\'t have an account? Register'),
                ),
                if (Platform.isAndroid && _deviceId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Text(
                      'Device ID: $_deviceId',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
