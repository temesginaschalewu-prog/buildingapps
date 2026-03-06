import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/user_model.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/school_provider.dart';
import '../../services/api_service.dart';
import '../../services/device_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_dialog.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../utils/constants.dart';
import '../../utils/app_enums.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../widgets/common/responsive_widgets.dart';

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
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  File? _profileImageFile;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  String? _schoolName;
  bool _notificationsEnabled = true;
  bool _isOffline = false;
  bool _isRefreshing = false;
  String _refreshSubtitle = '';

  User? _cachedUser;
  bool _hasCachedData = false;
  bool _isFirstLoad = true;

  Timer? _refreshTimer;
  StreamSubscription? _userSubscription;
  StreamSubscription? _schoolSubscription;
  StreamSubscription? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      _initializeScreen();
      _setupStreamListeners();
      _checkSubscriptionStatus();
      _setupConnectivityListener();
    });
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() => _isOffline = !isOnline);
        if (isOnline && !_isRefreshing && _cachedUser != null) {
          _refreshInBackground();
        }
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _schoolSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _refreshTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() => _isOffline = !connectivityService.isOnline);
  }

  Future<void> _initializeScreen() async {
    await _loadFromCache();
    if (_hasCachedData) {
      setState(() => _isFirstLoad = false);
      if (_cachedUser != null) {
        _emailController.text = _cachedUser!.email ?? '';
        _phoneController.text = _cachedUser!.phone ?? '';
      }
      if (!_isOffline) {
        await _refreshInBackground();
      }
    } else {
      await _loadFreshData();
    }
    if (!_isOffline) {
      _startAutoRefresh();
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final deviceService = context.read<DeviceService>();
      final cachedUser = await deviceService.getCacheItem<User>('user_profile',
          isUserSpecific: true);

      if (cachedUser != null) {
        _cachedUser = cachedUser;
        _hasCachedData = true;

        if (cachedUser.schoolId != null) {
          final cachedSchool =
              await deviceService.getCacheItem<Map<String, dynamic>>(
            'school_${cachedUser.schoolId}',
            isUserSpecific: true,
          );
          if (cachedSchool != null) _schoolName = cachedSchool['name'];
        }
      } else {
        final authProvider = context.read<AuthProvider>();
        final user = authProvider.currentUser;
        if (user != null) {
          _cachedUser = user;
          _hasCachedData = true;
        }
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error loading from cache: $e');
    }
  }

  Future<void> _loadFreshData() async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() {
        _isOffline = true;
        _isFirstLoad = false;
      });
      return;
    }

    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.loadUserProfile(forceRefresh: true);

      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser ?? userProvider.currentUser;

      if (user != null) {
        _cachedUser = user;
        _hasCachedData = true;

        if (mounted) {
          setState(() {
            _emailController.text = user.email ?? '';
            _phoneController.text = user.phone ?? '';
          });
          if (user.schoolId != null) {
            await _loadSchoolName(user.schoolId, forceRefresh: true);
          }
        }
        await _saveToCache(user);
      }

      await _loadNotificationSettings();
    } catch (e) {
      debugLog('ProfileScreen', 'Error loading fresh data: $e');
      setState(() => _isOffline = true);
    } finally {
      if (mounted) setState(() => _isFirstLoad = false);
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing || _isOffline) return;
    _isRefreshing = true;

    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.loadUserProfile(forceRefresh: true);

      final authProvider = context.read<AuthProvider>();
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
      debugLog('ProfileScreen', 'Error refreshing in background: $e');
      setState(() => _isOffline = true);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isOffline = true);
      SnackbarService().showOffline(context);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.loadUserProfile(forceRefresh: true);

      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUser ?? userProvider.currentUser;

      if (user != null && mounted) {
        setState(() {
          _cachedUser = user;
          _emailController.text = user.email ?? '';
          _phoneController.text = user.phone ?? '';
          _isOffline = false;
        });
        if (user.schoolId != null) {
          await _loadSchoolName(user.schoolId, forceRefresh: true);
        }
        await _saveToCache(user);
      }

      SnackbarService().showSuccess(context, 'Profile updated');
    } catch (e) {
      debugLog('ProfileScreen', 'Error during manual refresh: $e');
      setState(() => _isOffline = true);
      SnackbarService().showError(context, 'Refresh failed, using cached data');
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
      });
    }
  }

  Future<void> _saveToCache(User user) async {
    try {
      final deviceService = context.read<DeviceService>();
      await deviceService.saveCacheItem('user_profile', user,
          ttl: const Duration(hours: 24), isUserSpecific: true);
    } catch (e) {
      debugLog('ProfileScreen', 'Error saving to cache: $e');
    }
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && !_isEditing && !_isSaving && !_isOffline) {
        _refreshInBackground();
      }
    });
  }

  void _setupStreamListeners() {
    final userProvider = context.read<UserProvider>();
    final schoolProvider = context.read<SchoolProvider>();

    _userSubscription?.cancel();
    _schoolSubscription?.cancel();

    _userSubscription = userProvider.userUpdates.listen((user) {
      if (user != null && mounted && !_isEditing && !_isOffline) {
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
      if (mounted && !_isOffline) _loadSchoolName(schoolId);
    });
  }

  Future<void> _loadSchoolName(int? schoolId,
      {bool forceRefresh = false}) async {
    if (schoolId == null) {
      setState(() => _schoolName = null);
      return;
    }

    try {
      final schoolProvider = context.read<SchoolProvider>();
      if (forceRefresh || schoolProvider.schools.isEmpty) {
        await schoolProvider.loadSchools(
            forceRefresh: forceRefresh && !_isOffline);
      }
      final school = schoolProvider.getSchoolById(schoolId);
      if (mounted) setState(() => _schoolName = school?.name);
    } catch (e) {
      debugLog('ProfileScreen', 'Error loading school name: $e');
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      await subscriptionProvider.loadSubscriptions();
    } catch (e) {
      debugLog('ProfileScreen', 'Error checking subscription status: $e');
    }
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final storageService = context.read<AuthProvider>().storageService;
      final enabled = await storageService.getNotificationPreferences();
      if (mounted) setState(() => _notificationsEnabled = enabled);
    } catch (e) {
      debugLog('ProfileScreen', 'Error loading notification settings: $e');
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    try {
      final storageService = context.read<AuthProvider>().storageService;
      await storageService.saveNotificationPreferences(value);

      setState(() => _notificationsEnabled = value);
      SnackbarService().showSuccess(
          context, value ? 'Notifications enabled' : 'Notifications disabled');
    } catch (e) {
      debugLog('ProfileScreen', 'Error toggling notifications: $e');
      SnackbarService()
          .showError(context, 'Failed to update notification settings');
    }
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
      debugLog('ProfileScreen', 'Error compressing image: $e');
      return imageFile;
    }
  }

  Future<void> _pickProfileImage() async {
    if (!_isEditing || _isOffline) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        final imageFile = File(image.path);
        final fileSize = imageFile.lengthSync();

        if (fileSize > 10 * 1024 * 1024) {
          SnackbarService()
              .showError(context, 'Image size too large. Max 10MB.');
          return;
        }

        setState(() {
          _profileImageFile = imageFile;
          _isUploadingImage = true;
        });

        try {
          final compressedFile = await _compressImage(imageFile);
          if (compressedFile != imageFile) {
            setState(() => _profileImageFile = compressedFile);
          }
          await _uploadProfileImage(compressedFile!);
        } catch (e) {
          debugLog('ProfileScreen', 'Error processing image: $e');
          SnackbarService().showError(context, 'Failed to process image');
          setState(() => _profileImageFile = null);
        } finally {
          if (mounted) setState(() => _isUploadingImage = false);
        }
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error picking image: $e');
      SnackbarService().showError(context, 'Failed to pick image');
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: 'upload image');
      setState(() => _profileImageFile = null);
      return;
    }

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.uploadImage(imageFile);

      if (response.success && response.data != null) {
        final imageUrl = response.data!;

        final userProvider = context.read<UserProvider>();
        await userProvider.updateProfile(profileImage: imageUrl);

        SnackbarService().showSuccess(context, 'Profile image updated');
        setState(() => _profileImageFile = null);
      } else {
        SnackbarService().showError(context, 'Failed to upload image');
        setState(() => _profileImageFile = null);
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error uploading image: $e');
      SnackbarService().showError(context, 'Failed to upload image');
      setState(() => _profileImageFile = null);
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: 'update profile');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      final userProvider = context.read<UserProvider>();
      await userProvider.updateProfile(
        email: email.isNotEmpty ? email : null,
        phone: phone.isNotEmpty ? phone : null,
      );

      SnackbarService().showSuccess(context, 'Profile updated successfully');
      setState(() {
        _isEditing = false;
        _isSaving = false;
      });

      await userProvider.loadUserProfile(forceRefresh: true);
    } catch (e) {
      debugLog('ProfileScreen', 'Error saving profile: $e');
      SnackbarService().showError(context, formatErrorMessage(e));
      setState(() => _isSaving = false);
    }

    if (!_isSaving) await _refreshInBackground();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9+\-()\s]{10,15}$').hasMatch(phone);
  }

  Widget _buildEditButton() {
    return AppButton.icon(
      icon: _isOffline ? Icons.wifi_off_rounded : Icons.edit_rounded,
      onPressed: _isOffline
          ? null
          : (_isEditing ? null : () => setState(() => _isEditing = true)),
    );
  }

  Widget _buildSaveButton() {
    if (_isSaving) {
      return Container(
        width: ResponsiveValues.appBarButtonSize(context),
        height: ResponsiveValues.appBarButtonSize(context),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SizedBox(
            width: ResponsiveValues.appBarIconSize(context),
            height: ResponsiveValues.appBarIconSize(context),
            child: const CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.telegramBlue),
          ),
        ),
      );
    }
    return AppButton.icon(
      icon: Icons.save_rounded,
      onPressed: _saveProfile,
    );
  }

  Widget _buildProfileHeader(User user) {
    final avatarSize = ResponsiveValues.avatarSizeLarge(context);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: (_isEditing && !_isOffline) ? _pickProfileImage : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.telegramBlue.withValues(alpha: 0.3),
                      width: 2),
                ),
                child: ClipOval(
                  child: _profileImageFile != null
                      ? Image.file(_profileImageFile!,
                          fit: BoxFit.cover,
                          width: avatarSize,
                          height: avatarSize)
                      : (user.profileImage?.isNotEmpty == true
                          ? CachedNetworkImage(
                              imageUrl: user.profileImage!,
                              fit: BoxFit.cover,
                              width: avatarSize,
                              height: avatarSize,
                              placeholder: (context, url) => Container(
                                color: AppColors.getSurface(context),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.telegramBlue),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  _buildInitialsAvatar(
                                      user.username, avatarSize),
                            )
                          : _buildInitialsAvatar(user.username, avatarSize)),
                ),
              ),
            ),
            if (_isEditing && !_isUploadingImage && !_isOffline)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: Container(
                    width: ResponsiveValues.iconSizeXL(context) * 1.2,
                    height: ResponsiveValues.iconSizeXL(context) * 1.2,
                    decoration: const BoxDecoration(
                      gradient:
                          LinearGradient(colors: AppColors.telegramGradient),
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                          BorderSide(color: Colors.white, width: 3)),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
              ),
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        Text(
          user.username,
          style: AppTextStyles.headlineSmall(context)
              .copyWith(fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        if (_schoolName != null) ...[
          SizedBox(height: ResponsiveValues.spacingXS(context)),
          Text(
            _schoolName!,
            style: AppTextStyles.bodySmall(context)
                .copyWith(color: AppColors.getTextSecondary(context)),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: ResponsiveValues.spacingM(context)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingM(context),
            vertical: ResponsiveValues.spacingXXS(context),
          ),
          decoration: BoxDecoration(
            color: AppColors.getStatusBackground(user.accountStatus, context),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusFull(context)),
          ),
          child: Text(
            user.accountStatus.toUpperCase(),
            style: AppTextStyles.statusBadge(context).copyWith(
              fontSize: ResponsiveValues.fontStatusBadge(context),
              fontWeight: FontWeight.w600,
              color: AppColors.getStatusColor(user.accountStatus, context),
            ),
          ),
        ),
        if (_isOffline)
          Padding(
            padding: EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingM(context),
                vertical: ResponsiveValues.spacingXXS(context),
              ),
              decoration: BoxDecoration(
                color: AppColors.telegramYellow.withValues(alpha: 0.1),
                borderRadius:
                    BorderRadius.circular(ResponsiveValues.radiusFull(context)),
                border: Border.all(
                    color: AppColors.telegramYellow.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 12, color: AppColors.telegramYellow),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String username, double size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: AppColors.purpleGradient),
      ),
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
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              AppTextField.email(
                controller: _emailController,
                label: 'Email',
                hint: 'email@example.com',
                enabled: !_isOffline,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !_isValidEmail(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField.phone(
                controller: _phoneController,
                label: 'Phone Number',
                hint: '+1 (123) 456-7890',
                enabled: !_isOffline,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !_isValidPhone(value)) {
                    return 'Please enter a valid phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              if (_isOffline)
                Padding(
                  padding: EdgeInsets.only(
                      bottom: ResponsiveValues.spacingL(context)),
                  child: Container(
                    padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.telegramYellow.withValues(alpha: 0.2),
                          AppColors.telegramYellow.withValues(alpha: 0.1)
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.telegramYellow, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are offline. Connect to update profile.',
                            style: AppTextStyles.bodySmall(context)
                                .copyWith(color: AppColors.telegramYellow),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      label: 'Cancel',
                      onPressed: () => setState(() => _isEditing = false),
                      expanded: true,
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: AppButton.primary(
                      label: _isOffline ? 'Offline' : 'Save',
                      onPressed: _isSaving || _isOffline ? null : _saveProfile,
                      isLoading: _isSaving,
                      expanded: true,
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
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoItem(
                Icons.email_outlined, 'Email', user.email ?? 'Not set'),
            const Divider(height: 1),
            _buildInfoItem(
                Icons.phone_outlined, 'Phone', user.phone ?? 'Not set'),
            const Divider(height: 1),
            _buildInfoItem(
                Icons.school_outlined, 'School', _schoolName ?? 'Not selected'),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: ResponsiveValues.spacingXS(context)),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.telegramBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.labelMedium(context).copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return AppCard.menu(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
              vertical: 0,
            ),
            height: 56,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (iconColor ?? AppColors.telegramBlue)
                            .withValues(alpha: 0.2),
                        (iconColor ?? AppColors.telegramBlue)
                            .withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 20, color: iconColor ?? AppColors.telegramBlue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium(context)
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.getTextSecondary(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMenuCard(
          icon: Icons.subscriptions_outlined,
          title: 'Subscriptions',
          onTap: () => context.push('/subscriptions'),
        ),
        _buildMenuCard(
          icon: Icons.tv_outlined,
          title: 'TV Pairing',
          onTap: () => context.push('/tv-pairing'),
        ),
        _buildMenuCard(
          icon: Icons.family_restroom_outlined,
          title: 'Parent Controls',
          onTap: () => context.push('/parent-link'),
        ),
        _buildMenuCard(
          icon: Icons.feedback_outlined,
          title: 'Feedback',
          onTap: _openTelegramGroup,
          iconColor: AppColors.telegramBlue,
        ),
        _buildMenuCard(
          icon: Icons.support_outlined,
          title: 'Help & Support',
          onTap: () => context.push('/support'),
        ),
        _buildMenuCard(
          icon: Icons.info_outline,
          title: 'App Info',
          onTap: _showAppInfo,
        ),
      ],
    );
  }

  Future<void> _openTelegramGroup() async {
    const username = 's_upport_familyacademy';
    try {
      const telegramUrl = 'https://t.me/$username';
      final uri = Uri.parse(telegramUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        SnackbarService().showError(context, 'Could not open Telegram');
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error opening Telegram: $e');
      SnackbarService().showError(context, 'Could not open Telegram');
    }
  }

  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool)? onChanged,
  }) {
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.telegramBlue.withValues(alpha: 0.2),
                    AppColors.telegramPurple.withValues(alpha: 0.1)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.telegramBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium(context)
                    .copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.telegramBlue,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection() {
    final themeProvider = context.read<ThemeProvider>();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingCard(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              value: _notificationsEnabled,
              onChanged: _isOffline ? null : _toggleNotifications,
            ),
            const Divider(height: 1),
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

  void _showAppInfo() {
    AppDialog.info(
      context: context,
      title: 'Family Academy',
      message:
          'Version 1.4.0+1\n\nEmpowering students with quality education through modern technology.\n\n© 2024 Family Academy',
    );
  }

  Widget _buildLogoutButton() {
    return AppCard.glass(
      child: AppButton.danger(
        label: 'Logout',
        onPressed: _showLogoutConfirmation,
        expanded: true,
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout?',
      confirmText: 'Logout',
      cancelText: 'Cancel',
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
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
          const SliverToBoxAdapter(
            child:
                CustomAppBar(title: 'Profile', subtitle: 'Loading profile...'),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: ResponsiveValues.screenPadding(context),
                child: const Column(
                  children: [
                    AppShimmer(type: ShimmerType.circle),
                    SizedBox(height: 16),
                    AppShimmer(type: ShimmerType.textLine, customWidth: 150),
                  ],
                ),
              ),
              AppCard.glass(
                child: Container(
                  margin: ResponsiveValues.screenPadding(context),
                  padding: ResponsiveValues.cardPadding(context),
                  child: Column(
                    children: List.generate(
                      3,
                      (index) => Padding(
                        padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context)),
                        child: const Row(
                          children: [
                            AppShimmer(
                                type: ShimmerType.circle,
                                customWidth: 40,
                                customHeight: 40),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppShimmer(
                                      type: ShimmerType.textLine,
                                      customWidth: 100),
                                  SizedBox(height: 4),
                                  AppShimmer(
                                      type: ShimmerType.textLine,
                                      customWidth: double.infinity),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: CustomAppBar(
            title: 'Profile',
            subtitle: _isRefreshing
                ? 'Refreshing...'
                : (_isOffline ? 'Offline mode' : 'Manage your account'),
            customTrailing:
                _isEditing ? _buildSaveButton() : _buildEditButton(),
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            Container(
                alignment: Alignment.center, child: _buildProfileHeader(user)),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
            if (_isEditing)
              _buildEditProfileForm()
            else
              _buildInfoSection(user),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
            _buildMenuSection(),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
            _buildSettingsSection(),
            SizedBox(height: ResponsiveValues.spacingXXL(context)),
            _buildLogoutButton(),
            SizedBox(height: ResponsiveValues.spacingXXXL(context)),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();

    User? user;
    if (_cachedUser != null) {
      user = _cachedUser;
    } else if (authProvider.currentUser != null) {
      user = authProvider.currentUser;
    } else if (userProvider.currentUser != null) {
      user = userProvider.currentUser;
    }

    if (_isFirstLoad && !_hasCachedData) return _buildSkeletonLoader();

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(
          child: AppEmptyState.error(
            title: 'Failed to load profile',
            message: _isOffline
                ? 'No cached profile available. Please check your connection.'
                : 'Please try again later',
            onRetry: _manualRefresh,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: RefreshIndicator(
        key: _refreshIndicatorKey,
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: _buildContent(user),
      ),
    );
  }
}
