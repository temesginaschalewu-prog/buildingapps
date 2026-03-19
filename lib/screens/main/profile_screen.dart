// lib/screens/main/profile_screen.dart
// COMPLETE PRODUCTION-READY FINAL VERSION - FIXED PENDING COUNT

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
import '../../services/device_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../themes/app_themes.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../widgets/common/app_empty_state.dart';
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
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
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

  User? _cachedUser;
  int _pendingCount = 0;

  Timer? _refreshTimer;
  StreamSubscription? _connectivitySubscription;

  late AnimationController _headerAnimationController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.addObserver(this);

    _headerAnimationController = AnimationController(
      vsync: this,
      duration: AppThemes.animationMedium,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _refreshTimer?.cancel();
    _emailController.dispose();
    _phoneController.dispose();
    _headerAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await _checkConnectivity();
    _setupConnectivityListener();
    _checkPendingCount();
    await _loadData();
    _headerAnimationController.forward();
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (!mounted) return;

      setState(() {
        _isOffline = !isOnline;
        final queueManager = context.read<OfflineQueueManager>();
        _pendingCount = queueManager.pendingCount;
      });

      if (isOnline && !_isRefreshing && _cachedUser != null) {
        unawaited(_refreshInBackground());
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOffline = !connectivityService.isOnline;
      final queueManager = context.read<OfflineQueueManager>();
      _pendingCount = queueManager.pendingCount;
    });
  }

  Future<void> _checkPendingCount() async {
    final queueManager = context.read<OfflineQueueManager>();
    if (mounted) {
      setState(() => _pendingCount = queueManager.pendingCount);
    }
  }

  Future<void> _loadData() async {
    final userProvider = context.read<UserProvider>();
    final authProvider = context.read<AuthProvider>();

    _cachedUser = userProvider.currentUser ?? authProvider.currentUser;

    if (_cachedUser != null) {
      _emailController.text = _cachedUser!.email ?? '';
      _phoneController.text = _cachedUser!.phone ?? '';

      if (_cachedUser!.schoolId != null) {
        await _loadSchoolName(_cachedUser!.schoolId);
      }
    }

    await _loadNotificationSettings();

    if (!_isOffline && userProvider.hasLoadedProfile) {
      unawaited(_refreshInBackground());
    }
  }

  Future<void> _refreshInBackground() async {
    if (_isRefreshing || _isOffline) return;

    final userProvider = context.read<UserProvider>();
    await userProvider.loadUserProfile(forceRefresh: true);

    if (!mounted) return;

    final updatedUser = userProvider.currentUser;
    if (updatedUser != null && !_isEditing) {
      setState(() {
        _cachedUser = updatedUser;
        _emailController.text = updatedUser.email ?? '';
        _phoneController.text = updatedUser.phone ?? '';
      });
      if (updatedUser.schoolId != null) {
        await _loadSchoolName(updatedUser.schoolId);
      }
      await _saveToCache(updatedUser);
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    final connectivity = ConnectivityService();
    if (!connectivity.isOnline) {
      setState(() => _isRefreshing = false);
      if (mounted) {
        SnackbarService().showOffline(context, action: AppStrings.refresh);
      }
      return;
    }

    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.loadUserProfile(
        forceRefresh: true,
        isManualRefresh: true,
      );

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

      if (mounted) {
        SnackbarService().showSuccess(context, AppStrings.profileUpdated);
      }
    } catch (e) {
      if (mounted) {
        SnackbarService().showError(context, AppStrings.refreshFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
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

  Future<void> _loadSchoolName(
    int? schoolId, {
    bool forceRefresh = false,
  }) async {
    if (schoolId == null) {
      setState(() => _schoolName = null);
      return;
    }

    try {
      final schoolProvider = context.read<SchoolProvider>();

      final cachedName = schoolProvider.getSchoolNameById(schoolId);
      if (cachedName != null && !forceRefresh) {
        if (mounted) {
          setState(() => _schoolName = cachedName);
        }
        return;
      }

      if (forceRefresh || schoolProvider.schools.isEmpty) {
        await schoolProvider.loadSchools(
          forceRefresh: forceRefresh && !_isOffline,
        );
      }

      final school = schoolProvider.getSchoolById(schoolId);
      if (mounted) {
        setState(() => _schoolName = school?.name);
      }
    } catch (e) {
      debugLog('ProfileScreen', 'Error loading school name: $e');
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
      if (!mounted) return;

      setState(() => _notificationsEnabled = value);
      SnackbarService().showSuccess(
        context,
        value
            ? AppStrings.notificationsEnabled
            : AppStrings.notificationsDisabled,
      );
    } catch (e) {
      debugLog('ProfileScreen', 'Error toggling notifications: $e');
      SnackbarService().showError(
        context,
        AppStrings.failedToUpdateNotifications,
      );
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
    if (!_isEditing || _isOffline) return;

    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        if (!mounted) return;
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
                'ProfileScreen',
                'Compression failed, using original: $e',
              );
            }
          }

          setState(() => _profileImageFile = fileToUpload);
          await _uploadProfileImage(fileToUpload);
        } catch (e) {
          debugLog('ProfileScreen', 'Error processing image: $e');
          if (mounted) {
            SnackbarService().showError(
              context,
              AppStrings.failedToProcessImage,
            );
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

      if (!mounted) return;

      if (response.success && response.data != null) {
        final imageUrl = response.data!;
        debugPrint('✅ Profile image uploaded: $imageUrl');

        final userProvider = context.read<UserProvider>();
        final updateResponse =
            await userProvider.updateProfile(profileImage: imageUrl);

        if (!mounted) return;

        if (updateResponse.success) {
          await userProvider.loadUserProfile(forceRefresh: true);

          setState(() {
            _cachedUser = userProvider.currentUser;
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
      if (mounted) {
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

        if (!mounted) return;

        SnackbarService().showQueued(context, action: AppStrings.profileUpdate);
        setState(() {
          _isEditing = false;
          _isSaving = false;
          _pendingCount++;
        });
      } catch (e) {
        if (mounted) {
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

      final userProvider = context.read<UserProvider>();

      final response = await userProvider
          .updateProfile(
            email: email.isNotEmpty ? email : null,
            phone: phone.isNotEmpty ? phone : null,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Request timed out'),
          );

      if (!mounted) return;

      if (response.success) {
        await userProvider.loadUserProfile(forceRefresh: true);

        setState(() {
          _cachedUser = userProvider.currentUser;
          _emailController.text = userProvider.currentUser?.email ?? '';
          _phoneController.text = userProvider.currentUser?.phone ?? '';
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
      if (mounted) {
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
              strokeWidth: 2,
              color: AppColors.telegramBlue,
            ),
          ),
        ),
      );
    }
    return AppButton.icon(icon: Icons.save_rounded, onPressed: _saveProfile);
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
                                user.username,
                                avatarSize,
                              ),
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
                      gradient: LinearGradient(
                        colors: AppColors.telegramGradient,
                      ),
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 3),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
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
              style: AppTextStyles.headlineSmall(
                context,
              ).copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            if (_isOffline)
              Padding(
                padding: EdgeInsets.only(
                  left: ResponsiveValues.spacingXS(context),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: ResponsiveValues.iconSizeXS(context),
                  color: AppColors.warning,
                ),
              ),
            if (_pendingCount > 0)
              Padding(
                padding: EdgeInsets.only(
                  left: ResponsiveValues.spacingXS(context),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      _pendingCount > 9 ? '9+' : _pendingCount.toString(),
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
            style: AppTextStyles.bodySmall(
              context,
            ).copyWith(color: AppColors.getTextSecondary(context)),
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
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusFull(context),
            ),
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
        gradient: LinearGradient(colors: AppColors.purpleGradient),
      ),
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
                enabled: !_isOffline,
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
                enabled: !_isOffline,
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
                      label: _isOffline
                          ? AppStrings.queueChanges
                          : AppStrings.save,
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

  Widget _buildInfoSection(User user) {
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
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveValues.spacingXS(context),
      ),
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
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(fontWeight: FontWeight.w500),
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
          borderRadius: BorderRadius.circular(
            ResponsiveValues.radiusMedium(context),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingL(context),
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
                        (iconColor ?? AppColors.telegramBlue).withValues(
                          alpha: 0.2,
                        ),
                        (iconColor ?? AppColors.telegramBlue).withValues(
                          alpha: 0.1,
                        ),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? AppColors.telegramBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium(
                      context,
                    ).copyWith(fontWeight: FontWeight.w500),
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
                style: AppTextStyles.bodyMedium(
                  context,
                ).copyWith(fontWeight: FontWeight.w500),
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
              title: AppStrings.notifications,
              value: _notificationsEnabled,
              onChanged: _isOffline ? null : _toggleNotifications,
            ),
            const Divider(height: 1),
            _buildSettingCard(
              icon: Icons.dark_mode_outlined,
              title: AppStrings.darkMode,
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (value) => themeProvider.setTheme(
                value ? ThemeMode.dark : ThemeMode.light,
              ),
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
          '${AppStrings.version} 1.4.0+1\n\n${AppStrings.empoweringStudents}\n\n© 2024 Family Academy',
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
    final confirmed = await AppDialog.confirm(
      context: context,
      title: AppStrings.logout,
      message: AppStrings.logoutConfirm,
      confirmText: AppStrings.logout,
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
            child: CustomAppBar(
              title: AppStrings.profile,
              subtitle: AppStrings.loadingProfile,
            ),
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
                          vertical: ResponsiveValues.spacingM(context),
                        ),
                        child: const Row(
                          children: [
                            AppShimmer(
                              type: ShimmerType.circle,
                              customWidth: 40,
                              customHeight: 40,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppShimmer(
                                    type: ShimmerType.textLine,
                                    customWidth: 100,
                                  ),
                                  SizedBox(height: 4),
                                  AppShimmer(
                                    type: ShimmerType.textLine,
                                    customWidth: double.infinity,
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
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(User user) {
    final userProvider = context.watch<UserProvider>();
    final isLoading =
        userProvider.isLoadingProfile && !userProvider.hasInitialData;

    if (isLoading) {
      return _buildSkeletonLoader();
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: CustomAppBar(
            title: AppStrings.profile,
            subtitle:
                _isOffline ? AppStrings.offlineMode : AppStrings.manageAccount,
            customTrailing:
                _isEditing ? _buildSaveButton() : _buildEditButton(),
            showOfflineIndicator: _isOffline,
          ),
        ),
        SliverList(
          delegate: SliverChildListDelegate([
            if (_isOffline && _pendingCount > 0)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.info.withValues(alpha: 0.2),
                      AppColors.info.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.info,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_pendingCount pending change${_pendingCount > 1 ? 's' : ''}',
                        style: const TextStyle(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              alignment: Alignment.center,
              child: _buildProfileHeader(user),
            ),
            const SizedBox(height: 24),
            if (_isEditing)
              _buildEditProfileForm()
            else
              _buildInfoSection(user),
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
    super.build(context);

    final authProvider = context.watch<AuthProvider>();
    final userProvider = context.watch<UserProvider>();
    final schoolProvider = context.watch<SchoolProvider>();

    final User? user = userProvider.currentUser ?? authProvider.currentUser;

    if (user?.schoolId != null && _schoolName == null) {
      _schoolName = schoolProvider.getSchoolNameById(user!.schoolId!);
    }

    final bool isLoading =
        userProvider.isLoadingProfile && !userProvider.hasInitialData;

    if (isLoading) {
      return _buildSkeletonLoader();
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: AppStrings.error,
          subtitle: AppStrings.failedToLoadProfile,
          leading: AppButton.icon(
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.pop(),
          ),
          showOfflineIndicator: _isOffline,
        ),
        body: Center(
          child: AppEmptyState.error(
            title: AppStrings.failedToLoadProfile,
            message: _isOffline
                ? AppStrings.noCachedProfile
                : AppStrings.tryAgainLater,
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
    ).animate().fadeIn(duration: AppThemes.animationMedium);
  }
}
