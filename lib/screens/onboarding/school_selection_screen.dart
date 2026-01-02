import 'package:familyacademyclient/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/school_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/helpers.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen> {
  int? _selectedSchoolId;
  bool _isLoading = false;
  bool _schoolsLoaded = false;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSchools();
    });
  }

  Future<void> _loadSchools() async {
    if (_schoolsLoaded) return;

    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);
    await schoolProvider.loadSchools();
    _schoolsLoaded = true;
  }

  Future<void> _selectSchool() async {
    if (_selectedSchoolId == null) {
      showSnackBar(context, 'Please select a school', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);
    final storageService = StorageService();
    await storageService.init();

    try {
      // Get token directly from storage
      final token = await storageService.getToken();

      if (token == null || token.isEmpty) {
        throw Exception('No authentication token found');
      }

      debugLog('SchoolSelection', 'Using token for school selection');

      // Use direct method with token
      await authProvider.selectSchool(_selectedSchoolId!);
      schoolProvider.selectSchool(_selectedSchoolId!);

      showSnackBar(context, 'School selected successfully');

      // Navigate to main screen
      context.go('/');
    } catch (e) {
      showSnackBar(context, 'Failed to select school: $e', isError: true);
      debugLog('SchoolSelection', 'Error details: $e');

      // If token expired, go back to login
      if (e.toString().contains('401') ||
          e.toString().contains('unauthorized')) {
        debugLog('SchoolSelection', 'Authentication failed, logging out');
        await authProvider.logout();
        context.go('/auth/login');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final schoolProvider = Provider.of<SchoolProvider>(context);
    final schools = schoolProvider.schools;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your School'),
      ),
      body: schoolProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Select your school',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This helps us provide better analytics for your learning journey',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Expanded(
                    child: ListView.builder(
                      itemCount: schools.length + 1, // +1 for "Other" option
                      itemBuilder: (context, index) {
                        if (index == schools.length) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.school_outlined),
                              title: const Text('Other'),
                              subtitle: const Text('My school is not listed'),
                              trailing: Radio<int?>(
                                value: 0,
                                groupValue: _selectedSchoolId,
                                onChanged: (value) {
                                  setState(() => _selectedSchoolId = value);
                                },
                              ),
                              onTap: () {
                                setState(() => _selectedSchoolId = 0);
                              },
                            ),
                          );
                        }

                        final school = schools[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.school),
                            title: Text(school.name),
                            subtitle:
                                Text('Added: ${formatDate(school.createdAt)}'),
                            trailing: Radio<int?>(
                              value: school.id,
                              groupValue: _selectedSchoolId,
                              onChanged: (value) {
                                setState(() => _selectedSchoolId = value);
                              },
                            ),
                            onTap: () {
                              setState(() => _selectedSchoolId = school.id);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _selectSchool,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ],
              ),
            ),
    );
  }
}
