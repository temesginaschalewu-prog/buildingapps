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
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/school_provider.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/device_service.dart';
import '../../services/notification_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../themes/app_themes.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
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
  int? _selectedSchoolId;

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
  late SettingsProvider _settingsProvider;
  late ThemeProvider _themeProvider;

  void _syncDraftFromUser(User? user, {bool force = false}) {
    if (user == null) return;
    if (!force && (_isEditing || _isUploadingImage)) return;

    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
    _selectedSchoolId = user.schoolId;
  }

  @override
  String get screenTitle => AppStrings.profile;

  @override
  String? get screenSubtitle =>
      isOffline ? AppStrings.offlineMode : _settingsProvider.getProfileScreenSubtitle();

  @override
  bool get isLoading =>
      _userProvider.isLoadingProfile && !_userProvider.hasInitialData;

  @override
  bool get hasCachedData => _userProvider.hasInitialData;

  @override
  dynamic get errorMessage =>
      _cachedUser == null ? _settingsProvider.getProfileLoadErrorMessage() : null;

  @override
  List<Widget>? get appBarActions => [
        if (_isEditing) _buildSaveButton() else _buildEditButton(),
      ];

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
    _settingsProvider = Provider.of<SettingsProvider>(context);
    _themeProvider = Provider.of<ThemeProvider>(context);

    // ✅ FIXED: Get current user from UserProvider or AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _cachedUser = _userProvider.currentUser ?? authProvider.currentUser;

    if (_cachedUser != null) {
      _syncDraftFromUser(_cachedUser);

      if (_cachedUser!.schoolId != null) {
        unawaited(_loadSchoolName(_cachedUser!.schoolId));
      }
    }

    if (_schoolProvider.schools.isEmpty) {
      unawaited(_schoolProvider.loadSchools());
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
    unawaited(_headerAnimationController.forward());
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
        _syncDraftFromUser(user, force: true);
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
      final notificationService = NotificationService();
      await notificationService.setNotificationsEnabled(value);
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
      final draftEmail = _emailController.text;
      final draftPhone = _phoneController.text;
      final draftSchoolId = _selectedSchoolId;

      final apiService = context.read<ApiService>();
      final response = await apiService.uploadProfileImage(imageFile);

      if (!isMounted) return;

      if (response.success && response.data != null) {
        final imageUrl = response.data!;

        final updateResponse =
            await _userProvider.updateProfile(profileImage: imageUrl);

        if (!isMounted) return;

        if (updateResponse.success) {
          await _userProvider.loadUserProfile(forceRefresh: true);

          setState(() {
            final refreshedUser = _userProvider.currentUser;
            _cachedUser = refreshedUser != null
                ? refreshedUser.copyWith(profileImage: imageUrl)
                : _cachedUser?.copyWith(profileImage: imageUrl);
            _emailController.text = draftEmail;
            _phoneController.text = draftPhone;
            _selectedSchoolId = draftSchoolId;
            _profileImageFile = null;
            _isUploadingImage = false;
          });

          await _loadSchoolName(_selectedSchoolId);

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
            'schoolId': _selectedSchoolId,
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
            schoolId: _selectedSchoolId,
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
          _syncDraftFromUser(_userProvider.currentUser, force: true);
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
      icon: Icons.edit_rounded,
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
                    width: ResponsiveValues.profileAvatarActionSize(context),
                    height: ResponsiveValues.profileAvatarActionSize(context),
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
              SizedBox(height: ResponsiveValues.spacingL(context)),
              DropdownButtonFormField<int>(
                value: _selectedSchoolId != null &&
                        _schoolProvider.schools
                            .any((school) => school.id == _selectedSchoolId)
                    ? _selectedSchoolId
                    : null,
                decoration: const InputDecoration(
                  labelText: AppStrings.school,
                  hintText: 'Choose your school',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                items: _schoolProvider.schools
                    .map(
                      (school) => DropdownMenuItem<int>(
                        value: school.id,
                        child: Text(
                          school.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isOffline
                    ? null
                    : (value) => setState(() => _selectedSchoolId = value),
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
                      label: AppStrings.save,
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
              width: ResponsiveValues.listItemIconContainerSize(context),
              height: ResponsiveValues.listItemIconContainerSize(context),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: ResponsiveValues.listItemIconSize(context),
                color: AppColors.telegramBlue,
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
        splashColor: AppColors.telegramBlue.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingL(context),
            vertical: ResponsiveValues.spacingXS(context),
          ),
          alignment: Alignment.center,
          child: Row(
            children: [
              Container(
                width: ResponsiveValues.listItemIconContainerSize(context),
                height: ResponsiveValues.listItemIconContainerSize(context),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.telegramBlue)
                      .withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: ResponsiveValues.listItemIconSize(context),
                  color: iconColor ?? AppColors.telegramBlue,
                ),
              ),
              SizedBox(width: ResponsiveValues.spacingM(context)),
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
    );
  }

  Widget _buildSectionTitle(String eyebrow, String title) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingM(context),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingM(context),
            vertical: ResponsiveValues.spacingXS(context),
          ),
          decoration: BoxDecoration(
            color: AppColors.telegramBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusFull(context),
            ),
          ),
          child: Text(
            eyebrow,
            style: AppTextStyles.labelSmall(context).copyWith(
              color: AppColors.telegramBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    final items = [
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
    ];

    return AppCard.solid(
      hasShadow: false,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
      ),
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
    return SizedBox(
      height: 60,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingL(context),
          vertical: ResponsiveValues.spacingXS(context),
        ),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.listItemIconContainerSize(context),
              height: ResponsiveValues.listItemIconContainerSize(context),
              decoration: BoxDecoration(
                color: AppColors.telegramBlue.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: ResponsiveValues.listItemIconSize(context),
                color: AppColors.telegramBlue,
              ),
            ),
            SizedBox(width: ResponsiveValues.spacingM(context)),
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
    return AppCard.solid(
      hasShadow: false,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: ResponsiveValues.spacingXS(context),
        ),
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

  Future<void> _showAppInfo() async {
    final diagnostics = await NotificationService().getDiagnostics();
    if (!mounted) return;

    final notificationStatus = [
      'Platform: ${diagnostics['platform']}',
      'Push capable: ${diagnostics['push_capable_platform'] == true ? 'Yes' : 'No'}',
      'Notifications enabled: ${diagnostics['notifications_enabled'] == true ? 'Yes' : 'No'}',
      'Online: ${diagnostics['is_online'] == true ? 'Yes' : 'No'}',
      'Signed in: ${diagnostics['is_authenticated'] == true ? 'Yes' : 'No'}',
      'Service ready: ${diagnostics['service_initialized'] == true ? 'Yes' : 'No'}',
      'Firebase ready: ${diagnostics['firebase_initialized'] == true ? 'Yes' : 'No'}',
      'Token present: ${diagnostics['live_fcm_token_present'] == true || diagnostics['cached_fcm_token_present'] == true ? 'Yes' : 'No'}',
      'Token queued: ${diagnostics['pending_fcm_token_present'] == true ? 'Yes' : 'No'}',
      'Token: ${diagnostics['fcm_token_preview']}',
    ].join('\n');

    await AppDialog.show(
      context: context,
      title: AppStrings.familyAcademy,
      message: '',
      customContent: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${AppStrings.version} 1.5.0+1',
            style: AppTextStyles.titleMedium(context)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          Text(
            AppStrings.empoweringStudents,
            style: AppTextStyles.bodyMedium(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          Text(
            'Notification Diagnostics',
            style: AppTextStyles.titleSmall(context)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: ResponsiveValues.spacingS(context)),
          Text(
            notificationStatus,
            style: AppTextStyles.bodySmall(context).copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.45,
            ),
          ),
          SizedBox(height: ResponsiveValues.spacingL(context)),
          Text(
            '© 2026 Family Academy',
            style: AppTextStyles.labelSmall(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return AppCard.glass(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showLogoutConfirmation,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusLarge(context)),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
              vertical: ResponsiveValues.spacingM(context),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: ResponsiveValues.iconSizeS(context),
                  color: AppColors.telegramRed,
                ),
                SizedBox(width: ResponsiveValues.spacingS(context)),
                Text(
                  AppStrings.logout,
                  style: AppTextStyles.labelLarge(context).copyWith(
                    color: AppColors.telegramRed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      return buildErrorWidget(
        _settingsProvider.getProfileLoadErrorMessage(),
        onRetry: onRefresh,
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            Container(
                alignment: Alignment.center, child: _buildProfileHeader()),
            const SizedBox(height: 24),
            _buildSectionTitle('Profile', 'Your details'),
            if (_isEditing) _buildEditProfileForm() else _buildInfoSection(),
            const SizedBox(height: 24),
            _buildSectionTitle('Access', 'Learning and account tools'),
            _buildMenuSection(),
            const SizedBox(height: 24),
            _buildSectionTitle('Preferences', 'Notifications and appearance'),
            _buildSettingsSection(),
            const SizedBox(height: 24),
            _buildSectionTitle('Account', 'Sign out of this device'),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildScreen(content: buildContent(context));
  }
}
