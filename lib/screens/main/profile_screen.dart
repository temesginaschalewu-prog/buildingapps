// lib/screens/main/profile_screen.dart
// PRODUCTION STANDARD - FIXED LATE INITIALIZATION ERROR

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/school_provider.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/device_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../themes/app_themes.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_dialog.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive_values.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with BaseScreenMixin<ProfileScreen>, TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  File? _profileImageFile;
  bool _isEditing = false;
  bool _isUploadingImage = false;
  bool _isSaving = false;
  String? _schoolName;
  bool _notificationsEnabled = true;

  User? _cachedUser;

  late AnimationController _headerAnimationController;
  late UserProvider _userProvider;
  late SchoolProvider _schoolProvider;
  late ThemeProvider _themeProvider;

  @override
  String get screenTitle => AppStrings.profile;

  @override
  String? get screenSubtitle =>
      isOffline ? AppStrings.offlineMode : AppStrings.manageAccount;

  @override
  bool get isLoading =>
      _userProvider.isLoadingProfile && !_userProvider.hasInitialData;

  @override
  bool get hasCachedData => _userProvider.hasInitialData;

  @override
  dynamic get errorMessage => _cachedUser == null ? 'No user data' : null;

  @override
  void initState() {
    super.initState();

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationMedium,
    );

    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userProvider = Provider.of<UserProvider>(context);
    _schoolProvider = Provider.of<SchoolProvider>(context);
    _themeProvider = Provider.of<ThemeProvider>(context);

    // ✅ FIXED: Get current user from UserProvider or AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _cachedUser = _userProvider.currentUser ?? authProvider.currentUser;

    if (_cachedUser != null) {
      _emailController.text = _cachedUser!.email ?? '';
      _phoneController.text = _cachedUser!.phone ?? '';

      if (_cachedUser!.schoolId != null) {
        _loadSchoolName(_cachedUser!.schoolId);
      }
    }

    _loadNotificationSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _headerAnimationController.forward();
    await _loadNotificationSettings();
  }

  @override
  Future<void> onRefresh() async {
    await _userProvider.loadUserProfile(
        forceRefresh: true, isManualRefresh: true);

    // ✅ FIXED: Get user from provider directly
    final user = _userProvider.currentUser;
    if (user != null) {
      setState(() {
        _cachedUser = user;
        _emailController.text = user.email ?? '';
        _phoneController.text = user.phone ?? '';
      });
      if (user.schoolId != null) {
        await _loadSchoolName(user.schoolId, forceRefresh: true);
      }
      await _saveToCache(user);
    }
  }

  Future<void> _saveToCache(User user) async {
    try {
      final deviceService = context.read<DeviceService>();
      deviceService.saveCacheItem(
        'user_profile',
        user,
        ttl: const Duration(hours: 24),
        isUserSpecific: true,
      );
    } catch (e) {
      debugLog('ProfileScreen', 'Error saving to cache: $e');
    }
  }

  Future<void> _loadSchoolName(int? schoolId,
      {bool forceRefresh = false}) async {
    if (schoolId == null) {
      setState(() => _schoolName = null);
      return;
    }

    try {
      final cachedName = _schoolProvider.getSchoolNameById(schoolId);
      if (cachedName != null && !forceRefresh) {
        if (isMounted) setState(() => _schoolName = cachedName);
        return;
      }

      if (forceRefresh || _schoolProvider.schools.isEmpty) {
        await _schoolProvider.loadSchools(
            forceRefresh: forceRefresh && !isOffline);
      }

      final school = _schoolProvider.getSchoolById(schoolId);
      if (isMounted) setState(() => _schoolName = school?.name);
    } catch (e) {
      debugLog('ProfileScreen', 'Error loading school name: $e');
    }
  }

  // ✅ FIXED: Get storage service from AuthProvider via Provider
  Future<void> _loadNotificationSettings() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final storageService = authProvider.storageService;
      final enabled = await storageService.getNotificationPreferences();
      if (isMounted) setState(() => _notificationsEnabled = enabled);
    } catch (e) {
      debugLog('ProfileScreen', 'Error loading notification settings: $e');
    }
  }

  // ✅ FIXED: Get storage service from AuthProvider via Provider
  Future<void> _toggleNotifications(bool value) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final storageService = authProvider.storageService;
      await storageService.saveNotificationPreferences(value);
      if (!isMounted) return;

      setState(() => _notificationsEnabled = value);
      SnackbarService().showSuccess(
        context,
        value
            ? AppStrings.notificationsEnabled
            : AppStrings.notificationsDisabled,
      );
    } catch (e) {
      debugLog('ProfileScreen', 'Error toggling notifications: $e');
      SnackbarService()
          .showError(context, AppStrings.failedToUpdateNotifications);
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
        '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await tempFile.writeAsBytes(compressedBytes);
      return tempFile;
    } catch (e) {
      debugLog('ProfileScreen', 'Error compressing image: $e');
      return imageFile;
    }
  }

  Future<void> _pickProfileImage() async {
    if (!_isEditing || isOffline) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        if (!isMounted) return;
        final imageFile = File(image.path);
        final fileSize = imageFile.lengthSync();

        if (fileSize > 10 * 1024 * 1024) {
          SnackbarService().showError(context, AppStrings.imageTooLarge);
          return;
        }

        setState(() {
          _profileImageFile = imageFile;
          _isUploadingImage = true;
        });

        try {
          File fileToUpload = imageFile;

          if (!Platform.isLinux) {
            try {
              final compressedFile = await _compressImage(imageFile);
              if (compressedFile != null && compressedFile != imageFile) {
                fileToUpload = compressedFile;
              }
            } catch (e) {
              debugLog(
                  'ProfileScreen', 'Compression failed, using original: $e');
            }
          }

          setState(() => _profileImageFile = fileToUpload);
          await _uploadProfileImage(fileToUpload);
        } catch (e) {
          debugLog('ProfileScreen', 'Error processing image: $e');
          if (isMounted) {
            SnackbarService()
                .showError(context, AppStrings.failedToProcessImage);
          }
          setState(() {
            _profileImageFile = null;
            _isUploadingImage = false;
          });
        }
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error picking image: $e');
      SnackbarService().showError(context, AppStrings.failedToPickImage);
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      SnackbarService().showOffline(context, action: AppStrings.uploadImage);
      setState(() {
        _profileImageFile = null;
        _isUploadingImage = false;
      });
      return;
    }

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.uploadProfileImage(imageFile);

      if (!isMounted) return;

      if (response.success && response.data != null) {
        final imageUrl = response.data!;
        debugPrint('✅ Profile image uploaded: $imageUrl');

        final updateResponse =
            await _userProvider.updateProfile(profileImage: imageUrl);

        if (!isMounted) return;

        if (updateResponse.success) {
          await _userProvider.loadUserProfile(forceRefresh: true);

          setState(() {
            _cachedUser = _userProvider.currentUser;
            _profileImageFile = null;
            _isUploadingImage = false;
          });

          SnackbarService()
              .showSuccess(context, AppStrings.profileImageUpdated);
        } else {
          setState(() {
            _profileImageFile = null;
            _isUploadingImage = false;
          });
          SnackbarService().showError(context, updateResponse.message);
        }
      } else {
        setState(() {
          _profileImageFile = null;
          _isUploadingImage = false;
        });
        SnackbarService().showError(context, response.message);
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error uploading image: $e');
      if (isMounted) {
        setState(() {
          _profileImageFile = null;
          _isUploadingImage = false;
        });
        SnackbarService().showError(context, AppStrings.failedToUploadImage);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() => _isSaving = true);
      try {
        final email = _emailController.text.trim();
        final phone = _phoneController.text.trim();

        final queueManager = context.read<OfflineQueueManager>();
        queueManager.addItem(
          type: AppConstants.queueActionUpdateProfile,
          data: {
            'email': email.isNotEmpty ? email : null,
            'phone': phone.isNotEmpty ? phone : null,
          },
        );

        if (!isMounted) return;

        SnackbarService().showQueued(context, action: AppStrings.profileUpdate);
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      } catch (e) {
        if (isMounted) {
          SnackbarService().showError(context, AppStrings.failedToQueueUpdate);
        }
        setState(() => _isSaving = false);
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();

      final response = await _userProvider
          .updateProfile(
            email: email.isNotEmpty ? email : null,
            phone: phone.isNotEmpty ? phone : null,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (!isMounted) return;

      if (response.success) {
        await _userProvider.loadUserProfile(forceRefresh: true);

        setState(() {
          _cachedUser = _userProvider.currentUser;
          _emailController.text = _userProvider.currentUser?.email ?? '';
          _phoneController.text = _userProvider.currentUser?.phone ?? '';
          _isEditing = false;
          _isSaving = false;
        });

        if (_cachedUser?.schoolId != null) {
          await _loadSchoolName(_cachedUser!.schoolId, forceRefresh: true);
        }

        SnackbarService()
            .showSuccess(context, AppStrings.profileUpdatedSuccess);
      } else {
        setState(() => _isSaving = false);
        SnackbarService().showError(context, response.message);
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error saving profile: $e');
      if (isMounted) {
        String errorMessage = getUserFriendlyErrorMessage(e);
        if (errorMessage.contains('timed out')) {
          errorMessage = 'Request timed out. Please try again.';
        }
        SnackbarService().showError(context, errorMessage);
      }
      setState(() => _isSaving = false);
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r'^[0-9+\-()\s]{10,15}$').hasMatch(phone);
  }

  Widget _buildEditButton() {
    return AppButton.icon(
      icon: isOffline ? Icons.wifi_off_rounded : Icons.edit_rounded,
      onPressed: isOffline
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
              strokeWidth: 2,
              color: AppColors.telegramBlue,
            ),
          ),
        ),
      );
    }
    return AppButton.icon(icon: Icons.save_rounded, onPressed: _saveProfile);
  }

  Widget _buildProfileHeader() {
    final user = _cachedUser;
    if (user == null) return const SizedBox.shrink();

    final avatarSize = ResponsiveValues.avatarSizeLarge(context);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: (_isEditing && !isOffline) ? _pickProfileImage : null,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.telegramBlue.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: _profileImageFile != null
                      ? Image.file(
                          _profileImageFile!,
                          fit: BoxFit.cover,
                          width: avatarSize,
                          height: avatarSize,
                        )
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
                                    color: AppColors.telegramBlue,
                                  ),
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
            if (_isEditing && !_isUploadingImage && !isOffline)
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
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: ResponsiveValues.spacingL(context)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              user.username,
              style: AppTextStyles.headlineSmall(context)
                  .copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (isOffline)
              Padding(
                padding:
                    EdgeInsets.only(left: ResponsiveValues.spacingXS(context)),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: ResponsiveValues.iconSizeXS(context),
                  color: AppColors.warning,
                ),
              ),
            if (pendingCount > 0)
              Padding(
                padding:
                    EdgeInsets.only(left: ResponsiveValues.spacingXS(context)),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: AppColors.info, shape: BoxShape.circle),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      pendingCount > 9 ? '9+' : pendingCount.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveValues.fontBadgeSmall(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
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
      ],
    );
  }

  Widget _buildInitialsAvatar(String username, double size) {
    return Container(
      decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColors.purpleGradient)),
      child: Center(
        child: Text(
          username.substring(0, 2).toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.3,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
                label: AppStrings.email,
                hint: AppStrings.enterEmail,
                enabled: !isOffline,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !_isValidEmail(value)) {
                    return AppStrings.invalidEmail;
                  }
                  return null;
                },
              ),
              SizedBox(height: ResponsiveValues.spacingL(context)),
              AppTextField.phone(
                controller: _phoneController,
                label: AppStrings.phone,
                hint: AppStrings.enterPhone,
                enabled: !isOffline,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !_isValidPhone(value)) {
                    return AppStrings.invalidPhone;
                  }
                  return null;
                },
              ),
              SizedBox(height: ResponsiveValues.spacingXL(context)),
              Row(
                children: [
                  Expanded(
                    child: AppButton.outline(
                      label: AppStrings.cancel,
                      onPressed: () => setState(() => _isEditing = false),
                      expanded: true,
                    ),
                  ),
                  SizedBox(width: ResponsiveValues.spacingM(context)),
                  Expanded(
                    child: AppButton.primary(
                      label:
                          isOffline ? AppStrings.queueChanges : AppStrings.save,
                      onPressed: _isSaving ? null : _saveProfile,
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

  Widget _buildInfoSection() {
    final user = _cachedUser;
    if (user == null) return const SizedBox.shrink();

    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoItem(
              Icons.email_outlined,
              AppStrings.email,
              user.email ?? AppStrings.notSet,
            ),
            const Divider(height: 1),
            _buildInfoItem(
              Icons.phone_outlined,
              AppStrings.phone,
              user.phone ?? AppStrings.notSet,
            ),
            const Divider(height: 1),
            _buildInfoItem(
              Icons.school_outlined,
              AppStrings.school,
              _schoolName ?? AppStrings.notSelected,
            ),
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
          splashColor: AppColors.telegramBlue.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingL(context)),
            alignment: Alignment.center,
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
          title: AppStrings.subscriptions,
          onTap: () => context.push('/subscriptions'),
        ),
        _buildMenuCard(
          icon: Icons.tv_outlined,
          title: AppStrings.tvPairing,
          onTap: () => context.push('/tv-pairing'),
        ),
        _buildMenuCard(
          icon: Icons.family_restroom_outlined,
          title: AppStrings.parentControls,
          onTap: () => context.push('/parent-link'),
        ),
        _buildMenuCard(
          icon: Icons.feedback_outlined,
          title: AppStrings.feedback,
          onTap: _openTelegramGroup,
          iconColor: AppColors.telegramBlue,
        ),
        _buildMenuCard(
          icon: Icons.support_outlined,
          title: AppStrings.helpSupport,
          onTap: () => context.push('/support'),
        ),
        _buildMenuCard(
          icon: Icons.info_outline,
          title: AppStrings.appInfo,
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
        SnackbarService().showError(context, AppStrings.cannotOpenTelegram);
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error opening Telegram: $e');
      SnackbarService().showError(context, AppStrings.cannotOpenTelegram);
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
                    AppColors.telegramPurple.withValues(alpha: 0.1),
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
    return AppCard.glass(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingCard(
              icon: Icons.notifications_outlined,
              title: AppStrings.notifications,
              value: _notificationsEnabled,
              onChanged: isOffline ? null : _toggleNotifications,
            ),
            const Divider(height: 1),
            _buildSettingCard(
              icon: Icons.dark_mode_outlined,
              title: AppStrings.darkMode,
              value: _themeProvider.themeMode == ThemeMode.dark,
              onChanged: (value) => _themeProvider
                  .setTheme(value ? ThemeMode.dark : ThemeMode.light),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppInfo() {
    AppDialog.info(
      context: context,
      title: AppStrings.familyAcademy,
      message:
          '${AppStrings.version} 1.5.0+1\n\n${AppStrings.empoweringStudents}\n\n© 2025 Family Academy',
    );
  }

  Widget _buildLogoutButton() {
    return AppCard.glass(
      child: AppButton.danger(
        label: AppStrings.logout,
        onPressed: _showLogoutConfirmation,
        expanded: true,
      ),
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await AppDialog.confirm(
      context: context,
      title: AppStrings.logout,
      message: AppStrings.logoutConfirm,
      confirmText: AppStrings.logout,
    );

    if (confirmed == true && isMounted) {
      await authProvider.logout();
      if (isMounted) context.go('/auth/login');
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    final user = _cachedUser;
    if (user == null) {
      return buildErrorWidget('No user data available');
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: buildAppBar(),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            if (isOffline && pendingCount > 0)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.info.withValues(alpha: 0.2),
                      AppColors.info.withValues(alpha: 0.1)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: AppColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$pendingCount pending change${pendingCount > 1 ? 's' : ''}',
                        style: const TextStyle(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
                alignment: Alignment.center, child: _buildProfileHeader()),
            const SizedBox(height: 24),
            if (_isEditing) _buildEditProfileForm() else _buildInfoSection(),
            const SizedBox(height: 24),
            _buildMenuSection(),
            const SizedBox(height: 24),
            _buildSettingsSection(),
            const SizedBox(height: 24),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(content: buildContent(context), showAppBar: false);
  }
}
