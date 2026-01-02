import '../utils/constants.dart';

class User {
  final int id;
  final String username;
  final String? email;
  final String? phone;
  final String? profileImage;
  final int? schoolId;
  final String accountStatus;
  final String? primaryDeviceId;
  final String? tvDeviceId;
  final bool parentLinked;
  final String? parentTelegramUsername;
  final DateTime? parentLinkDate;
  final int streakCount;
  final DateTime? lastStreakDate;
  final int totalStudyTime;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    this.email,
    this.phone,
    this.profileImage,
    this.schoolId,
    required this.accountStatus,
    this.primaryDeviceId,
    this.tvDeviceId,
    required this.parentLinked,
    this.parentTelegramUsername,
    this.parentLinkDate,
    required this.streakCount,
    this.lastStreakDate,
    required this.totalStudyTime,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      profileImage: json['profile_image']?.toString(),
      schoolId: json['school_id']?.toInt(),
      accountStatus: json['account_status']?.toString() ?? 'unpaid',
      primaryDeviceId: json['primary_device_id']?.toString(),
      tvDeviceId: json['tv_device_id']?.toString(),
      parentLinked: json['parent_linked'] == true,
      parentTelegramUsername: json['parent_telegram_username']?.toString(),
      parentLinkDate: json['parent_link_date'] != null
          ? DateTime.parse(json['parent_link_date'].toString())
          : null,
      streakCount: json['streak_count']?.toInt() ?? 0,
      lastStreakDate: json['last_streak_date'] != null
          ? DateTime.parse(json['last_streak_date'].toString())
          : null,
      totalStudyTime: json['total_study_time']?.toInt() ?? 0,
      adminNotes: json['admin_notes']?.toString(),
      createdAt: DateTime.parse(
          json['created_at']?.toString() ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at']?.toString() ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'phone': phone,
      'profile_image': profileImage,
      'school_id': schoolId,
      'account_status': accountStatus,
      'primary_device_id': primaryDeviceId,
      'tv_device_id': tvDeviceId,
      'parent_linked': parentLinked,
      'parent_telegram_username': parentTelegramUsername,
      'parent_link_date': parentLinkDate?.toIso8601String(),
      'streak_count': streakCount,
      'last_streak_date': lastStreakDate?.toIso8601String(),
      'total_study_time': totalStudyTime,
      'admin_notes': adminNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => accountStatus == AppConstants.activeStatus;
  bool get isUnpaid => accountStatus == AppConstants.unpaidStatus;
  bool get isExpired => accountStatus == AppConstants.expiredStatus;

  bool get hasTvDevice => tvDeviceId != null && tvDeviceId!.isNotEmpty;
  bool get hasParentLinked => parentLinked;
  String? get fullProfileImageUrl {
    if (profileImage == null || profileImage!.isEmpty) return null;

    if (profileImage!.startsWith('http')) {
      return profileImage;
    }

    if (profileImage!.startsWith('/')) {
      final path = profileImage!.startsWith('/')
          ? profileImage!.substring(1)
          : profileImage!;

      return '${AppConstants.baseUrl}/$path';
    }

    return '${AppConstants.baseUrl}/uploads/$profileImage';
  }
}
