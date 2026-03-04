import 'dart:io';
import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/models/user_model.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/services/user_session.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/widgets/common/app_bar.dart';
import 'package:familyacademyclient/widgets/common/empty_state.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:familyacademyclient/utils/responsive_values.dart';
import 'package:familyacademyclient/providers/auth_provider.dart';
import 'package:familyacademyclient/providers/user_provider.dart';
import 'package:familyacademyclient/providers/theme_provider.dart';
import 'package:familyacademyclient/providers/school_provider.dart';
import 'package:familyacademyclient/themes/app_themes.dart';
import 'package:familyacademyclient/services/api_service.dart';
import 'package:familyacademyclient/services/device_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:familyacademyclient/widgets/common/responsive_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
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

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusXLarge(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
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
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() {
        _isOffline = true;
        _isFirstLoad = false;
      });
      return;
    }

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
          if (user.schoolId != null) {
            await _loadSchoolName(user.schoolId, forceRefresh: true);
          }
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
    if (_isRefreshing || _isOffline) return;
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

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'You are offline. Using cached data.',
          isError: true);
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

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
        if (user.schoolId != null) {
          await _loadSchoolName(user.schoolId, forceRefresh: true);
        }
        await _saveToCache(user);
      }

      showTopSnackBar(context, 'Profile updated');
    } catch (e) {
      setState(() => _isOffline = true);
      showTopSnackBar(context, 'Refresh failed, using cached data',
          isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
      });
    }
  }

  Future<void> _saveToCache(User user) async {
    try {
      final deviceService = Provider.of<DeviceService>(context, listen: false);
      await deviceService.saveCacheItem('user_profile', user,
          ttl: const Duration(hours: 24), isUserSpecific: true);
    } catch (e) {}
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && !_isEditing && !_isSaving && !_isOffline) {
        _refreshInBackground();
      }
    });
  }

  void _setupStreamListeners() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final schoolProvider = Provider.of<SchoolProvider>(context, listen: false);

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
      final schoolProvider =
          Provider.of<SchoolProvider>(context, listen: false);
      if (forceRefresh || schoolProvider.schools.isEmpty) {
        await schoolProvider.loadSchools(
            forceRefresh: forceRefresh && !_isOffline);
      }
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
    if (!_isEditing || _isOffline) return;

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
          if (compressedFile != imageFile) {
            setState(() => _profileImageFile = compressedFile);
          }
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
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showTopSnackBar(context, 'You are offline. Cannot upload image.',
          isError: true);
      setState(() => _profileImageFile = null);
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.uploadImage(imageFile);

      if (response.success && response.data != null) {
        final imageUrl = response.data!;

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.updateProfile(profileImage: imageUrl);

        showTopSnackBar(context, 'Profile image updated');
        setState(() {
          _profileImageFile = null;
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

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showTopSnackBar(context, 'You are offline. Cannot update profile.',
          isError: true);
      return;
    }

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
      final String errorMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.telegramRed,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveValues.radiusMedium(context),
            ),
          ),
        ),
      );
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

// FIXED: Edit button now matches theme/notification buttons exactly
  Widget _buildEditButton() {
    return GestureDetector(
      onTap: _isOffline
          ? null
          : (_isEditing ? null : () => setState(() => _isEditing = true)),
      child: Container(
        width: ResponsiveValues.appBarButtonSize(context),
        height: ResponsiveValues.appBarButtonSize(context),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isOffline
                  ? null
                  : (_isEditing
                      ? null
                      : () => setState(() => _isEditing = true)),
              splashColor: AppColors.telegramBlue.withValues(alpha: 0.2),
              highlightColor: Colors.transparent,
              child: Center(
                child: Icon(
                  _isOffline ? Icons.wifi_off_rounded : Icons.edit_rounded,
                  size: ResponsiveValues.appBarIconSize(context),
                  color: _isOffline
                      ? AppColors.telegramGray
                      : AppColors.telegramBlue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

// FIXED: Save button matches the same style
  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _saveProfile,
      child: Container(
        width: ResponsiveValues.appBarButtonSize(context),
        height: ResponsiveValues.appBarButtonSize(context),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context).withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSaving ? null : _saveProfile,
              splashColor: AppColors.telegramBlue.withValues(alpha: 0.2),
              highlightColor: Colors.transparent,
              child: Center(
                child: _isSaving
                    ? SizedBox(
                        width: ResponsiveValues.appBarIconSize(context),
                        height: ResponsiveValues.appBarIconSize(context),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.telegramBlue,
                        ),
                      )
                    : Icon(
                        Icons.save_rounded,
                        size: ResponsiveValues.appBarIconSize(context),
                        color: AppColors.telegramBlue,
                      ),
              ),
            ),
          ),
        ),
      ),
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
                    color: ResponsiveValues.profileAvatarBorderColor(context),
                    width: ResponsiveValues.profileAvatarBorderWidth(context),
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
                        colors: AppColors.blueGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
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
        ResponsiveSizedBox(height: AppSpacing.l),
        Text(
          user.username,
          style: AppTextStyles.headlineSmall(context).copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        if (_schoolName != null) ...[
          ResponsiveSizedBox(height: AppSpacing.xs),
          Text(
            _schoolName!,
            style: AppTextStyles.bodySmall(context).copyWith(
              color: AppColors.getTextSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
        ResponsiveSizedBox(height: AppSpacing.m),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.statusBadgePadding(context),
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
              fontSize: ResponsiveValues.statusBadgeFontSize(context),
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
                  color: AppColors.telegramYellow.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 12,
                    color: AppColors.telegramYellow,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInitialsAvatar(String username, double size) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.purpleGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
    return _buildGlassContainer(
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'email@example.com',
                  prefixIcon: ResponsiveIcon(
                    Icons.email_outlined,
                    size: ResponsiveValues.iconSizeS(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.getSurface(context),
                ),
                keyboardType: TextInputType.emailAddress,
                style: AppTextStyles.bodyMedium(context),
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
              ResponsiveSizedBox(height: AppSpacing.l),
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '+1 (123) 456-7890',
                  prefixIcon: ResponsiveIcon(
                    Icons.phone_outlined,
                    size: ResponsiveValues.iconSizeS(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusMedium(context),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.getSurface(context),
                ),
                keyboardType: TextInputType.phone,
                style: AppTextStyles.bodyMedium(context),
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
              ResponsiveSizedBox(height: AppSpacing.xl),
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
                          AppColors.telegramYellow.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusMedium(context),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            color: AppColors.telegramYellow, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'You are offline. Connect to update profile.',
                            style: AppTextStyles.bodySmall(context).copyWith(
                              color: AppColors.telegramYellow,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => setState(() => _isEditing = false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextPrimary(context),
                        side: BorderSide(
                          color: AppColors.getTextSecondary(context),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveValues.spacingM(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  ResponsiveSizedBox(width: AppSpacing.m),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _isOffline
                            ? null
                            : const LinearGradient(
                                colors: AppColors.blueGradient,
                              ),
                        color: _isOffline
                            ? AppColors.telegramGray.withValues(alpha: 0.3)
                            : null,
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                        boxShadow: _isOffline
                            ? null
                            : [
                                BoxShadow(
                                  color: AppColors.telegramBlue
                                      .withValues(alpha: 0.3),
                                  blurRadius:
                                      ResponsiveValues.spacingS(context),
                                  offset: Offset(
                                      0, ResponsiveValues.spacingXS(context)),
                                ),
                              ],
                      ),
                      child: ElevatedButton(
                        onPressed:
                            _isSaving || _isOffline ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: _isOffline
                              ? AppColors.getTextSecondary(context)
                              : Colors.white,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: ResponsiveValues.iconSizeM(context),
                                height: ResponsiveValues.iconSizeM(context),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(_isOffline ? 'Offline' : 'Save'),
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
      child: Padding(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInfoItem(
              Icons.email_outlined,
              'Email',
              user.email ?? 'Not set',
            ),
            const Divider(height: 1),
            _buildInfoItem(
              Icons.phone_outlined,
              'Phone',
              user.phone ?? 'Not set',
            ),
            const Divider(height: 1),
            _buildInfoItem(
              Icons.school_outlined,
              'School',
              _schoolName ?? 'Not selected',
            ),
          ],
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveValues.infoSectionVerticalPadding(context),
      ),
      child: SizedBox(
        height: ResponsiveValues.infoSectionItemHeight(context),
        child: Row(
          children: [
            Container(
              width: ResponsiveValues.menuIconContainerSize(context),
              height: ResponsiveValues.menuIconContainerSize(context),
              decoration: BoxDecoration(
                color: ResponsiveValues.infoIconBackgroundColor(context),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: ResponsiveValues.infoSectionIconSize(context),
                color: ResponsiveValues.infoIconColor(context),
              ),
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
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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

  // FIXED: Menu cards now have consistent padding and no extra margin
  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      height: ResponsiveValues.menuCardHeight(context),
      margin: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
              ResponsiveValues.menuCardBorderRadius(context)),
          child: Container(
            padding: ResponsiveValues.menuCardPadding(context),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ResponsiveValues.menuCardGradientStart(context),
                  ResponsiveValues.menuCardGradientEnd(context),
                ],
              ),
              borderRadius: BorderRadius.circular(
                  ResponsiveValues.menuCardBorderRadius(context)),
              border: Border.all(
                color: ResponsiveValues.menuCardBorderColor(context),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: ResponsiveValues.menuIconContainerSize(context),
                  height: ResponsiveValues.menuIconContainerSize(context),
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
                  child: Icon(
                    icon,
                    size: ResponsiveValues.menuIconSize(context),
                    color: iconColor ?? AppColors.telegramBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: ResponsiveValues.iconSizeS(context),
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

  // FIXED: Setting cards now have proper spacing and no extra margin
  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required bool value,
    required Function(bool)? onChanged,
  }) {
    return Container(
      height: ResponsiveValues.settingCardHeight(context),
      margin: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onChanged != null ? () => onChanged(!value) : null,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Row(
            children: [
              Container(
                width: ResponsiveValues.settingIconContainerSize(context),
                height: ResponsiveValues.settingIconContainerSize(context),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.telegramBlue.withValues(alpha: 0.2),
                      AppColors.telegramPurple.withValues(alpha: 0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: ResponsiveValues.settingIconSize(context),
                  color: AppColors.telegramBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
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
      ),
    );
  }

  Widget _buildSettingsSection() {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return _buildGlassContainer(
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: ResponsiveValues.iconSizeXL(context),
                      height: ResponsiveValues.iconSizeXL(context),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: AppColors.blueGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.info_outline,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Family Academy',
                        style: AppTextStyles.titleMedium(context).copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Version 1.4.0+1',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Empowering students with quality education through modern technology.',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '© 2024 Family Academy',
                  style: AppTextStyles.caption(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.telegramBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // FIXED: Logout dialog with proper text visibility in both light/dark modes
  Widget _buildLogoutButton() {
    return Container(
      padding: ResponsiveValues.cardPadding(context),
      margin: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _showLogoutConfirmation,
          borderRadius:
              BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.pinkGradient,
              ),
              borderRadius:
                  BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.telegramRed.withValues(alpha: 0.3),
                  blurRadius: ResponsiveValues.spacingS(context),
                  offset: Offset(0, ResponsiveValues.spacingXS(context)),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(
              vertical: ResponsiveValues.spacingM(context),
            ),
            child: Center(
              child: Text(
                'Logout',
                style: AppTextStyles.buttonMedium(context).copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 0.1, end: 0).fadeIn();
  }

  // FIXED: Logout dialog with theme-aware colors for text visibility
  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ResponsiveValues.logoutDialogIconSize(context),
                  height: ResponsiveValues.logoutDialogIconSize(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 32,
                    color: AppColors.telegramRed.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Logout',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to logout?',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.getTextPrimary(context),
                        side: BorderSide(
                          color: AppColors.getDivider(context),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: ResponsiveValues.spacingM(context),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // In _showLogoutConfirmation dialog, around line 1515
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors
                              .pinkGradient, // Use gradient here, not in button
                        ),
                        borderRadius: BorderRadius.circular(
                          ResponsiveValues.radiusMedium(context),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.telegramRed.withValues(alpha: 0.3),
                            blurRadius: ResponsiveValues.spacingS(context),
                            offset:
                                Offset(0, ResponsiveValues.spacingXS(context)),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.transparent, // Make button transparent
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                        ),
                        child: const Text('Logout'),
                      ),
                    ),
                  ),
                ]),
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
          const SliverToBoxAdapter(
            child: CustomAppBar(
              title: 'Profile',
              subtitle: 'Loading profile...',
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Container(
                padding: ResponsiveValues.screenPadding(context),
                child: Column(
                  children: [
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                      highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                      child: Container(
                        width: ResponsiveValues.avatarSizeLarge(context),
                        height: ResponsiveValues.avatarSizeLarge(context),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Shimmer.fromColors(
                      baseColor: Colors.grey[300]!.withValues(alpha: 0.3),
                      highlightColor: Colors.grey[100]!.withValues(alpha: 0.6),
                      child: Container(
                        width: 150,
                        height: 24,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              _buildGlassContainer(
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
                        child: Row(
                          children: [
                            Shimmer.fromColors(
                              baseColor:
                                  Colors.grey[300]!.withValues(alpha: 0.3),
                              highlightColor:
                                  Colors.grey[100]!.withValues(alpha: 0.6),
                              child: Container(
                                width: ResponsiveValues.iconSizeXL(context),
                                height: ResponsiveValues.iconSizeXL(context),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!
                                        .withValues(alpha: 0.3),
                                    highlightColor: Colors.grey[100]!
                                        .withValues(alpha: 0.6),
                                    child: Container(
                                      width: 100,
                                      height: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!
                                        .withValues(alpha: 0.3),
                                    highlightColor: Colors.grey[100]!
                                        .withValues(alpha: 0.6),
                                    child: Container(
                                      width: double.infinity,
                                      height: 20,
                                      color: Colors.white,
                                    ),
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
              alignment: Alignment.center,
              child: _buildProfileHeader(user),
            ),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            if (_isEditing)
              _buildEditProfileForm()
            else
              _buildInfoSection(user),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            _buildMenuSection(),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            _buildSettingsSection(),
            ResponsiveSizedBox(height: AppSpacing.xxl),
            _buildLogoutButton(),
            ResponsiveSizedBox(height: AppSpacing.xxxl),
          ]),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
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
            actionText: 'Retry',
            onAction: _manualRefresh,
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

  Widget _buildTabletLayout() {
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return _buildMobileLayout();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFirstLoad && !_hasCachedData) return _buildSkeletonLoader();

    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}
