import 'dart:io';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/school_provider.dart';
import '../../widgets/profile/menu_item.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _profileImageFile;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  String? _schoolName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _loadSchoolName();
    });
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.currentUser;

    if (user != null) {
      _emailController.text = user.email ?? '';
      _phoneController.text = user.phone ?? '';
    }
  }

  Future<void> _loadSchoolName() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);
    final user = authProvider.user;

    if (user?.schoolId != null) {
      await schoolProvider.loadSchools();
      final school = schoolProvider.getSchoolById(user!.schoolId!);
      if (mounted) {
        setState(() {
          _schoolName = school?.name;
        });
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileImageFile = File(image.path);
        });

        await _uploadProfileImage(_profileImageFile!);
      }
    } catch (e) {
      showSnackBar(context, 'Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    setState(() => _isUploadingImage = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final apiService = userProvider.apiService;

      final response = await apiService.uploadImage(imageFile);
      final imagePath = response.data;

      if (imagePath != null) {
        await userProvider.updateProfile(profileImage: imagePath);
        showSnackBar(context, 'Profile image updated successfully');

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.refreshUserData();
      }
    } catch (e) {
      showSnackBar(context, 'Failed to upload image: $e', isError: true);
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user ?? userProvider.currentUser;

    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isNotEmpty && !_isValidEmail(email)) {
      showSnackBar(context, 'Please enter a valid email address',
          isError: true);
      setState(() => _isSaving = false);
      return;
    }

    if (phone.isNotEmpty && !_isValidPhone(phone)) {
      showSnackBar(context, 'Please enter a valid phone number', isError: true);
      setState(() => _isSaving = false);
      return;
    }

    try {
      debugLog(
          'ProfileScreen', 'Saving profile with email: $email, phone: $phone');

      String? profileImageUrl;
      if (_profileImageFile != null) {
        debugLog('ProfileScreen', 'Uploading profile image...');
        final response =
            await userProvider.apiService.uploadImage(_profileImageFile!);
        profileImageUrl = response.data;
        debugLog('ProfileScreen', 'Profile image uploaded: $profileImageUrl');
      }

      await userProvider.updateProfile(
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
        profileImage: profileImageUrl,
      );

      await authProvider.refreshUserData();

      debugLog('ProfileScreen', 'Profile saved successfully');

      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;

          if (profileImageUrl != null) {
            _profileImageFile = null;
          }
        });
      }

      showSnackBar(context, 'Profile updated successfully');
    } catch (e) {
      debugLog('ProfileScreen', 'Error saving profile: $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
      showSnackBar(context, 'Failed to update profile: $e', isError: true);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9+\-()\s]{10,15}$').hasMatch(phone);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = authProvider.user ?? userProvider.currentUser;

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveProfile,
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _isEditing ? _pickProfileImage : null,
                    child: Stack(
                      children: [
                        Container(
                          width: isSmallScreen ? 70 : 80,
                          height: isSmallScreen ? 70 : 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(isSmallScreen ? 35 : 40),
                            child: _profileImageFile != null
                                ? Image.file(
                                    _profileImageFile!,
                                    fit: BoxFit.cover,
                                    width: isSmallScreen ? 70 : 80,
                                    height: isSmallScreen ? 70 : 80,
                                  )
                                : user?.fullProfileImageUrl != null
                                    ? Image.network(
                                        user!.fullProfileImageUrl!,
                                        fit: BoxFit.cover,
                                        width: isSmallScreen ? 70 : 80,
                                        height: isSmallScreen ? 70 : 80,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade200,
                                            child: Center(
                                              child: Text(
                                                user.username
                                                    .substring(0, 1)
                                                    .toUpperCase(),
                                                style: TextStyle(
                                                  fontSize:
                                                      isSmallScreen ? 28 : 32,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey.shade200,
                                        child: Center(
                                          child: Text(
                                            user?.username
                                                    .substring(0, 1)
                                                    .toUpperCase() ??
                                                'S',
                                            style: TextStyle(
                                              fontSize: isSmallScreen ? 28 : 32,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                        if (_isUploadingImage)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(
                                    isSmallScreen ? 35 : 40),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              ),
                            ),
                          ),
                        if (_isEditing && !_isUploadingImage)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.username ?? 'Student',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18 : 20,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Chip(
                          label: Text(
                            user?.accountStatus.toUpperCase() ?? 'UNPAID',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              fontWeight: FontWeight.w500,
                            ),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 10,
                            vertical: isSmallScreen ? 2 : 4,
                          ),
                        ),
                        if (_schoolName != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _schoolName!,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isEditing)
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
                            prefixIcon: const Icon(Icons.email),
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 14 : 16,
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            hintText: 'Enter your phone number',
                            prefixIcon: const Icon(Icons.phone),
                            border: const OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 12 : 16,
                              vertical: isSmallScreen ? 14 : 16,
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _isSaving
                                  ? null
                                  : () => setState(() => _isEditing = false),
                              child: const Text('Cancel'),
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            ElevatedButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                            Colors.white),
                                      ),
                                    )
                                  : const Text('Save Changes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_isEditing)
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.email,
                          'Email',
                          user?.email ?? 'Not set',
                          isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildInfoRow(
                          Icons.phone,
                          'Phone',
                          user?.phone ?? 'Not set',
                          isSmallScreen,
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        _buildInfoRow(
                          Icons.school,
                          'School',
                          _schoolName ?? 'Not selected',
                          isSmallScreen,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
              onTap: _showAppInfo,
            ),
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: const Divider(),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Switch(
                    value: true,
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dark Mode',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
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
            SizedBox(height: isSmallScreen ? 24 : 32),
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
              child: SizedBox(
                width: double.infinity,
                height: isSmallScreen ? 44 : 48,
                child: ElevatedButton(
                  onPressed: () async {
                    await authProvider.logout();
                    context.go('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: isSmallScreen ? 18 : 20, color: Colors.grey),
        SizedBox(width: isSmallScreen ? 10 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
