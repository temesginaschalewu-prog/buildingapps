import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/common/app_bar.dart';
import 'package:familyacademyclient/widgets/common/loading_indicator.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/user_provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/providers/school_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:badges/badges.dart' as badges;
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _profileImageFile;
  String? _tempProfileImageUrl;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  String? _schoolName;
  bool _notificationsEnabled = true;
  int _unreadNotifications = 0;

  User? _cachedUser;
  bool _hasCachedData = false;
  bool _isFirstLoad = true;
  bool _isOffline = false;
  bool _isRefreshing = false;

  Timer? _refreshTimer;
  StreamSubscription? _userSubscription;
  StreamSubscription? _schoolSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
      _setupStreamListeners();
      _checkSubscriptionStatus();
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _schoolSubscription?.cancel();
    _refreshTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildGlassContainer(BuildContext context, {required Widget child}) {
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

  Future<void> _openTelegramGroup() async {
    final username = 's_upport_familyacademy';
    try {
      final telegramUrl = 'https://t.me/$username';
      final uri = Uri.parse(telegramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        showTopSnackBar(context, 'Could not open Telegram', isError: true);
      }
    } catch (e) {
      showTopSnackBar(context, 'Could not open Telegram', isError: true);
    }
  }

  Future<void> _initializeScreen() async {
    await _loadFromCache();
    if (_hasCachedData) {
      setState(() => _isFirstLoad = false);
      if (_cachedUser != null) {
        _emailController.text = _cachedUser!.email ?? '';
        _phoneController.text = _cachedUser!.phone ?? '';
      }
      _refreshInBackground();
    } else {
      await _loadFreshData();
    }
    _startAutoRefresh();
  }

  Future<void> _loadFromCache() async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      final cachedUser = await deviceService.getCacheItem<User>('user_profile',
          isUserSpecific: true);

      if (cachedUser != null) {
        _cachedUser = cachedUser;
        _hasCachedData = true;

        if (cachedUser.schoolId != null) {
          final cachedSchool =
              await deviceService.getCacheItem<Map<String, dynamic>>(
                  'school_${cachedUser.schoolId}',
                  isUserSpecific: true);
          if (cachedSchool != null) _schoolName = cachedSchool['name'];
        }
      } else {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final user = authProvider.currentUser;
        if (user != null) {
          _cachedUser = user;
          _hasCachedData = true;
        }
      }
    } catch (e) {}
  }

  Future<void> _loadFreshData() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserProfile(forceRefresh: true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser ?? userProvider.currentUser;

      if (user != null) {
        _cachedUser = user;
        _hasCachedData = true;

        if (mounted) {
          setState(() {
            _emailController.text = user.email ?? '';
            _phoneController.text = user.phone ?? '';
          });
          if (user.schoolId != null)
            await _loadSchoolName(user.schoolId, forceRefresh: true);
        }
        await _saveToCache(user);
      }

      await _loadNotificationSettings();
    } catch (e) {
      setState(() => _isOffline = true);
    } finally {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserProfile(forceRefresh: true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser ?? userProvider.currentUser;

      if (user != null && mounted && !_isEditing) {
        setState(() {
          _cachedUser = user;
          _emailController.text = user.email ?? '';
          _phoneController.text = user.phone ?? '';
          _isOffline = false;
        });
        if (user.schoolId != null) await _loadSchoolName(user.schoolId);
        await _saveToCache(user);
      }
    } catch (e) {
      setState(() => _isOffline = true);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.loadUserProfile(forceRefresh: true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser ?? userProvider.currentUser;

      if (user != null && mounted) {
        setState(() {
          _cachedUser = user;
          _emailController.text = user.email ?? '';
          _phoneController.text = user.phone ?? '';
          _isOffline = false;
        });
        if (user.schoolId != null)
          await _loadSchoolName(user.schoolId, forceRefresh: true);
        await _saveToCache(user);
      }

      showTopSnackBar(context, 'Profile updated');
    } catch (e) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'Refresh failed, using cached data',
          isError: true);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _saveToCache(User user) async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      await deviceService.saveCacheItem('user_profile', user,
          ttl: Duration(hours: 24), isUserSpecific: true);
    } catch (e) {}
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && !_isEditing && !_isSaving) _refreshInBackground();
    });
  }

  void _setupStreamListeners() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

    _userSubscription?.cancel();
    _schoolSubscription?.cancel();

    _userSubscription = userProvider.userUpdates.listen((user) {
      if (user != null && mounted && !_isEditing) {
        setState(() {
          _cachedUser = user;
          _emailController.text = user.email ?? '';
          _phoneController.text = user.phone ?? '';
        });
        _saveToCache(user);
      }
    });

    _schoolSubscription =
        schoolProvider.selectedSchoolUpdates.listen((schoolId) {
      if (mounted) _loadSchoolName(schoolId);
    });
  }

  Future<void> _loadSchoolName(int? schoolId,
      {bool forceRefresh = false}) async {
    if (schoolId == null) {
      setState(() => _schoolName = null);
      return;
    }

    try {
      final schoolProvider =
          Provider.of<SchoolProvider>(context, listen: false);
      if (forceRefresh || schoolProvider.schools.isEmpty)
        await schoolProvider.loadSchools(forceRefresh: forceRefresh);
      final school = schoolProvider.getSchoolById(schoolId);
      if (mounted) setState(() => _schoolName = school?.name);
    } catch (e) {}
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final subscriptionProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      await subscriptionProvider.loadSubscriptions();
    } catch (e) {}
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final storageService =
          Provider.of<AuthProvider>(context, listen: false).storageService;
      final enabled = await storageService.getNotificationPreferences();
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (e) {}
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      final storageService =
          Provider.of<AuthProvider>(context, listen: false).storageService;
      await storageService.saveNotificationPreferences(value);

      setState(() => _notificationsEnabled = value);
      showTopSnackBar(
          context, value ? 'Notifications enabled' : 'Notifications disabled');
    } catch (e) {}
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        minWidth: 800,
        minHeight: 800,
        quality: 85,
      );

      if (compressedBytes == null) return imageFile;

      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      return tempFile;
    } catch (e) {
      return imageFile;
    }
  }

  Future<void> _pickProfileImage() async {
    if (!_isEditing) return;

    try {
      final image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1200,
          maxHeight: 1200);

      if (image != null) {
        final imageFile = File(image.path);
        final fileSize = imageFile.lengthSync();

        if (fileSize > 10 * 1024 * 1024) {
          showTopSnackBar(context, 'Image size too large. Max 10MB.',
              isError: true);
          return;
        }

        setState(() {
          _profileImageFile = imageFile;
          _isUploadingImage = true;
        });

        try {
          final compressedFile = await _compressImage(imageFile);
          if (compressedFile != imageFile)
            setState(() => _profileImageFile = compressedFile);
          await _uploadProfileImage(compressedFile!);
        } catch (e) {
          showTopSnackBar(context, 'Failed to process image', isError: true);
          setState(() => _profileImageFile = null);
        } finally {
          if (mounted) setState(() => _isUploadingImage = false);
        }
      }
    } catch (e) {
      showTopSnackBar(context, 'Failed to pick image', isError: true);
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.uploadImage(imageFile);

      if (response.success && response.data != null) {
        final imageUrl = response.data!;
        setState(() => _tempProfileImageUrl = imageUrl);

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.updateProfile(profileImage: imageUrl);

        showTopSnackBar(context, 'Profile image updated');
        setState(() {
          _profileImageFile = null;
          _tempProfileImageUrl = null;
        });
      } else {
        showTopSnackBar(context, 'Failed to upload image', isError: true);
        setState(() => _profileImageFile = null);
      }
    } catch (e) {
      showTopSnackBar(context, 'Failed to upload image', isError: true);
      setState(() => _profileImageFile = null);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.updateProfile(
          email: email.isNotEmpty ? email : null,
          phone: phone.isNotEmpty ? phone : null);

      showTopSnackBar(context, 'Profile updated successfully');
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      await userProvider.loadUserProfile(forceRefresh: true);
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.telegramRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(AppThemes.borderRadiusMedium)),
        ),
      );
      setState(() => _isSaving = false);
    }

    if (!_isSaving) _refreshInBackground();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9+\-()\s]{10,15}$').hasMatch(phone);
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () {
        GoRouter.of(context).push('/notifications');
      },
      child: _buildGlassContainer(
        context,
        child: Container(
          width: 40,
          height: 40,
          child: Center(
            child: _unreadNotifications > 0
                ? badges.Badge(
                    position: badges.BadgePosition.topEnd(top: -4, end: -4),
                    badgeContent: Text(
                      _unreadNotifications > 9
                          ? '9+'
                          : _unreadNotifications.toString(),
                      style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                    badgeStyle: badges.BadgeStyle(
                      badgeColor: AppColors.telegramRed,
                      padding: const EdgeInsets.all(4),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusFull),
                    ),
                    child: Icon(Icons.notifications_outlined,
                        size: 22, color: AppColors.getTextPrimary(context)),
                  )
                : Icon(Icons.notifications_outlined,
                    size: 22, color: AppColors.getTextPrimary(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleButton() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GestureDetector(
          onTap: themeProvider.toggleTheme,
          child: _buildGlassContainer(
            context,
            child: Container(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 22,
                  color: AppColors.getTextPrimary(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: _isEditing ? null : () => setState(() => _isEditing = true),
      child: _buildGlassContainer(
        context,
        child: Container(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(
              Icons.edit_rounded,
              size: 22,
              color: AppColors.telegramBlue,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveProfile,
      child: _buildGlassContainer(
        context,
        child: Container(
          width: 40,
          height: 40,
          child: Center(
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.telegramBlue,
                    ),
                  )
                : Icon(
                    Icons.save_rounded,
                    color: AppColors.telegramBlue,
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User user) {
    final avatarSize = ScreenSize.responsiveValue(
        context: context, mobile: 80.0, tablet: 100.0, desktop: 120.0);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: _isEditing ? _pickProfileImage : null,
              behavior: HitTestBehavior.opaque,
              child: _buildGlassContainer(
                context,
                child: Container(
                  width: avatarSize,
                  height: avatarSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(avatarSize / 2),
                    child: _profileImageFile != null
                        ? Image.file(_profileImageFile!,
                            fit: BoxFit.cover,
                            width: avatarSize,
                            height: avatarSize)
                        : user.profileImage?.isNotEmpty == true
                            ? Image.network(
                                user.profileImage!,
                                fit: BoxFit.cover,
                                width: avatarSize,
                                height: avatarSize,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                      color: AppColors.telegramBlue,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildInitialsAvatar(
                                        user.username, avatarSize),
                              )
                            : _buildInitialsAvatar(user.username, avatarSize),
                  ),
                ),
              ),
            ),
            if (_isEditing && !_isUploadingImage)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  behavior: HitTestBehavior.opaque,
                  child: _buildGlassContainer(
                    context,
                    child: Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: AppColors.blueGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.getBackground(context),
                              width: 3),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Icon(Icons.edit_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(avatarSize / 2)),
                  child: Center(
                      child: CircularProgressIndicator(
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white))),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppThemes.spacingL),
        Text(user.username,
            style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        if (_schoolName != null) ...[
          const SizedBox(height: 4),
          Text(_schoolName!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.getTextSecondary(context)),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppThemes.spacingM),
        _buildGlassContainer(
          context,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppThemes.spacingM, vertical: 6),
            child: Text(
              user.accountStatus.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.getStatusColor(user.accountStatus, context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String username, double size) {
    return Container(
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: AppColors.purpleGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          shape: BoxShape.circle),
      child: Center(
        child: Text(
          username.substring(0, 2).toUpperCase(),
          style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.bold,
              color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEditProfileForm() {
    return _buildGlassContainer(
      context,
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL)),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'email@example.com',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppColors.getSurface(context),
                ),
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextPrimary(context)),
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !_isValidEmail(value))
                    return 'Please enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: AppThemes.spacingL),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1 (123) 456-7890',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                      borderSide: BorderSide.none),
                  filled: true,
                  fillColor: AppColors.getSurface(context),
                ),
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.getTextPrimary(context)),
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !_isValidPhone(value))
                    return 'Please enter a valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: AppThemes.spacingXL),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextPrimary(context),
                        side: BorderSide(
                            color: AppColors.getTextSecondary(context)),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppThemes.spacingM),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppThemes.spacingM),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                        ),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusMedium),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.telegramBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              vertical: AppThemes.spacingM),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium)),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white)))
                            : const Text('Save'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Widget _buildInfoSection(User user) {
    return _buildGlassContainer(
      context,
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL)),
        child: Column(
          children: [
            _buildInfoItem(
                Icons.email_outlined, 'Email', user.email ?? 'Not set'),
            const Divider(),
            _buildInfoItem(
                Icons.phone_outlined, 'Phone', user.phone ?? 'Not set'),
            const Divider(),
            _buildInfoItem(
                Icons.school_outlined, 'School', _schoolName ?? 'Not selected'),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppThemes.spacingM),
      child: Row(
        children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.telegramBlue.withOpacity(0.2),
                      AppColors.telegramPurple.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.telegramBlue, size: 20)),
          const SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? iconColor}) {
    return _buildGlassContainer(
      context,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppThemes.spacingM),
            child: Row(
              children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (iconColor ?? AppColors.getTextSecondary(context))
                                .withOpacity(0.2),
                            (iconColor ?? AppColors.getTextSecondary(context))
                                .withOpacity(0.1),
                          ],
                        ),
                        shape: BoxShape.circle),
                    child: Icon(icon,
                        color: iconColor ?? AppColors.getTextSecondary(context),
                        size: 20)),
                const SizedBox(width: AppThemes.spacingM),
                Expanded(
                    child: Text(title,
                        style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.getTextPrimary(context),
                            fontWeight: FontWeight.w500))),
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.getTextSecondary(context), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return _buildGlassContainer(
      context,
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL)),
        child: Column(
          children: [
            _buildMenuCard(
                icon: Icons.subscriptions_outlined,
                title: 'Subscriptions',
                onTap: () => context.push('/subscriptions')),
            const Divider(),
            _buildMenuCard(
                icon: Icons.tv_outlined,
                title: 'TV Pairing',
                onTap: () => context.push('/tv-pairing')),
            const Divider(),
            _buildMenuCard(
                icon: Icons.family_restroom_outlined,
                title: 'Parent Controls',
                onTap: () => context.push('/parent-link')),
            const Divider(),
            _buildMenuCard(
                icon: Icons.feedback_outlined,
                title: 'Feedback',
                onTap: _openTelegramGroup,
                iconColor: AppColors.telegramBlue),
            const Divider(),
            _buildMenuCard(
                icon: Icons.support_outlined,
                title: 'Help & Support',
                onTap: () => context.push('/support')),
            const Divider(),
            _buildMenuCard(
                icon: Icons.info_outline,
                title: 'App Info',
                onTap: _showAppInfo),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Widget _buildSettingsSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return _buildGlassContainer(
      context,
      child: Padding(
        padding: EdgeInsets.all(ScreenSize.responsiveValue(
            context: context,
            mobile: AppThemes.spacingL,
            tablet: AppThemes.spacingXL,
            desktop: AppThemes.spacingXXL)),
        child: Column(
          children: [
            _buildSettingCard(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
            const Divider(),
            _buildSettingCard(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (value) => themeProvider
                  .setTheme(value ? ThemeMode.dark : ThemeMode.light),
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Widget _buildSettingCard(
      {required IconData icon,
      required String title,
      required bool value,
      required Function(bool) onChanged}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppThemes.spacingM),
          child: Row(
            children: [
              Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.telegramBlue.withOpacity(0.2),
                          AppColors.telegramPurple.withOpacity(0.1),
                        ],
                      ),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: AppColors.telegramBlue, size: 20)),
              const SizedBox(width: AppThemes.spacingM),
              Expanded(
                  child: Text(title,
                      style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w500))),
              Switch.adaptive(
                  value: value,
                  onChanged: onChanged,
                  activeColor: AppColors.telegramBlue,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          context,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: AppColors.blueGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                          child: Icon(Icons.info_outline,
                              size: 20, color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text('Family Academy',
                            style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.getTextPrimary(context),
                                fontWeight: FontWeight.w700))),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Version 1.4.0+1',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.getTextSecondary(context))),
                const SizedBox(height: 12),
                Text(
                    'Empowering students with quality education through modern technology.',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.getTextSecondary(context))),
                const SizedBox(height: 24),
                Text('© 2024 Family Academy',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.getTextSecondary(context))),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                      ),
                      borderRadius:
                          BorderRadius.circular(AppThemes.borderRadiusMedium),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.telegramBlue.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(ScreenSize.responsiveValue(
          context: context,
          mobile: AppThemes.spacingL,
          tablet: AppThemes.spacingXL,
          desktop: AppThemes.spacingXXL)),
      margin: EdgeInsets.symmetric(
          horizontal: ScreenSize.responsiveValue(
              context: context,
              mobile: AppThemes.spacingL,
              tablet: AppThemes.spacingXL,
              desktop: AppThemes.spacingXXL)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showLogoutConfirmation(),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
              ),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppColors.telegramRed.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: AppThemes.spacingM),
            child: Center(
              child: Text('Logout',
                  style: AppTextStyles.buttonMedium.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          context,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withOpacity(0.2),
                        AppColors.telegramRed.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout_rounded,
                      size: 32, color: AppColors.telegramRed),
                ),
                const SizedBox(height: 16),
                Text('Logout',
                    style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.getTextPrimary(context),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text('Are you sure you want to logout?',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.getTextSecondary(context)),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          side: BorderSide(
                              color: AppColors.getTextSecondary(context)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.telegramRed.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppThemes.borderRadiusMedium)),
                          ),
                          child: const Text('Logout'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      if (mounted) context.go('/auth/login');
    }
  }

  Widget _buildSkeletonLoader() {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: CustomAppBar(
              title: 'Profile',
              subtitle: 'Loading profile...',
              showThemeToggle: true,
              showNotification: true,
              showRefresh: false,
              useSliver: false,
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenSize.responsiveValue(
                      context: context,
                      mobile: AppThemes.spacingL,
                      tablet: AppThemes.spacingXL,
                      desktop: AppThemes.spacingXXL),
                  vertical: AppThemes.spacingXL,
                ),
                child: Column(
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withOpacity(0.3),
                      highlightColor: Colors.grey[100]!.withOpacity(0.6),
                      child: _buildGlassContainer(
                        context,
                        child: Container(
                          width: ScreenSize.responsiveValue(
                              context: context,
                              mobile: 80,
                              tablet: 100,
                              desktop: 120),
                          height: ScreenSize.responsiveValue(
                              context: context,
                              mobile: 80,
                              tablet: 100,
                              desktop: 120),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppThemes.spacingL),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withOpacity(0.3),
                      highlightColor: Colors.grey[100]!.withOpacity(0.6),
                      child: Container(
                          width: 150, height: 24, color: Colors.white),
                    ),
                  ],
                ),
              ),
              _buildGlassContainer(
                context,
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: ScreenSize.responsiveValue(
                        context: context,
                        mobile: AppThemes.spacingL,
                        tablet: AppThemes.spacingXL,
                        desktop: AppThemes.spacingXXL),
                  ),
                  padding: EdgeInsets.all(ScreenSize.responsiveValue(
                      context: context,
                      mobile: AppThemes.spacingL,
                      tablet: AppThemes.spacingXL,
                      desktop: AppThemes.spacingXXL)),
                  child: Column(
                    children: List.generate(
                        3,
                        (index) => Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppThemes.spacingM),
                              child: Row(
                                children: [
                                  Shimmer.fromColors(
                                    baseColor:
                                        Colors.grey[300]!.withOpacity(0.3),
                                    highlightColor:
                                        Colors.grey[100]!.withOpacity(0.6),
                                    child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle)),
                                  ),
                                  const SizedBox(width: AppThemes.spacingM),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!
                                              .withOpacity(0.3),
                                          highlightColor: Colors.grey[100]!
                                              .withOpacity(0.6),
                                          child: Container(
                                              width: 100,
                                              height: 16,
                                              color: Colors.white),
                                        ),
                                        const SizedBox(height: 4),
                                        Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!
                                              .withOpacity(0.3),
                                          highlightColor: Colors.grey[100]!
                                              .withOpacity(0.6),
                                          child: Container(
                                              width: double.infinity,
                                              height: 20,
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(User user) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: CustomAppBar(
            title: 'Profile',
            subtitle: _isOffline ? 'Offline mode' : 'Manage your account',
            showThemeToggle: true,
            showNotification: true,
            showRefresh: true,
            isLoading: _isRefreshing,
            onRefresh: _manualRefresh,
            customTrailing:
                _isEditing ? _buildSaveButton() : _buildEditButton(),
            useSliver: false,
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            Container(
                alignment: Alignment.center, child: _buildProfileHeader(user)),
            const SizedBox(height: AppThemes.spacingXXL),
            _isEditing ? _buildEditProfileForm() : _buildInfoSection(user),
            const SizedBox(height: AppThemes.spacingXXL),
            _buildMenuSection(),
            const SizedBox(height: AppThemes.spacingXXL),
            _buildSettingsSection(),
            const SizedBox(height: AppThemes.spacingXXL),
            _buildLogoutButton(context),
            const SizedBox(height: AppThemes.spacingXXXL),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad && !_hasCachedData) return _buildSkeletonLoader();

    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final user =
        _cachedUser ?? authProvider.currentUser ?? userProvider.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(
          child: EmptyState(
            icon: Icons.error_outline,
            title: 'Failed to load profile',
            message: _isOffline
                ? 'No cached profile available. Please check your connection.'
                : 'Please try again later',
            centerContent: true,
            actionText: 'Retry',
            onAction: _manualRefresh,
          ),
        ),
      );
    }

    return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: _buildContent(user));
  }
}
