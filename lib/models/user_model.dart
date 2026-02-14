import 'package:familyacademyclient/utils/constants.dart';

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
  final List<Map<String, dynamic>>? subscriptions; // Add this

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
    this.subscriptions, // Add this
  });

  factory User.fromJson(Map<String, dynamic> json) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        if (value is String) return DateTime.parse(value);
        if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
        return null;
      } catch (e) {
        return null;
      }
    }

    // Parse subscriptions if available
    List<Map<String, dynamic>>? parseSubscriptions(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value.map((item) {
          if (item is Map<String, dynamic>) return item;
          return <String, dynamic>{};
        }).toList();
      }
      return null;
    }

    return User(
      id: parseId(json['id']),
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      profileImage: json['profile_image']?.toString(),
      schoolId: json['school_id'] != null ? parseId(json['school_id']) : null,
      accountStatus: json['account_status']?.toString() ?? 'unpaid',
      primaryDeviceId: json['primary_device_id']?.toString(),
      tvDeviceId: json['tv_device_id']?.toString(),
      parentLinked: json['parent_linked'] == true,
      parentTelegramUsername: json['parent_telegram_username']?.toString(),
      parentLinkDate: parseDate(json['parent_link_date']),
      streakCount: parseId(json['streak_count']),
      lastStreakDate: parseDate(json['last_streak_date']),
      totalStudyTime: parseId(json['total_study_time']),
      adminNotes: json['admin_notes']?.toString(),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseDate(json['updated_at']) ?? DateTime.now(),
      subscriptions: parseSubscriptions(json['subscriptions']), // Add this
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
      'subscriptions': subscriptions, // Add this
    };
  }

  bool get isActive => accountStatus == AppConstants.activeStatus;
  bool get isUnpaid => accountStatus == AppConstants.unpaidStatus;
  bool get isExpired => accountStatus == AppConstants.expiredStatus;

  // Check if user has any active subscription
  bool get hasActiveSubscription {
    if (subscriptions == null || subscriptions!.isEmpty) return false;

    final now = DateTime.now();
    return subscriptions!.any((sub) {
      final status = sub['status']?.toString() ?? '';
      final expiryStr = sub['expiry_date']?.toString();
      if (expiryStr == null) return false;

      try {
        final expiryDate = DateTime.parse(expiryStr);
        return status == 'active' && expiryDate.isAfter(now);
      } catch (e) {
        return false;
      }
    });
  }

  bool get hasTvDevice => tvDeviceId != null && tvDeviceId!.isNotEmpty;
  bool get hasParentLinked => parentLinked;

  String? get fullProfileImageUrl {
    if (profileImage == null || profileImage!.isEmpty) return null;

    if (profileImage!.startsWith('http://') ||
        profileImage!.startsWith('https://')) {
      return profileImage;
    }

    String cleanPath = profileImage!.startsWith('/')
        ? profileImage!.substring(1)
        : profileImage!;

    return '${AppConstants.baseUrl}/$cleanPath';
  }

  bool get needsSchoolSelection => schoolId == null || schoolId == 0;

  User copyWith({
    int? id,
    String? username,
    String? email,
    String? phone,
    String? profileImage,
    int? schoolId,
    String? accountStatus,
    String? primaryDeviceId,
    String? tvDeviceId,
    bool? parentLinked,
    String? parentTelegramUsername,
    DateTime? parentLinkDate,
    int? streakCount,
    DateTime? lastStreakDate,
    int? totalStudyTime,
    String? adminNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? subscriptions,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      schoolId: schoolId ?? this.schoolId,
      accountStatus: accountStatus ?? this.accountStatus,
      primaryDeviceId: primaryDeviceId ?? this.primaryDeviceId,
      tvDeviceId: tvDeviceId ?? this.tvDeviceId,
      parentLinked: parentLinked ?? this.parentLinked,
      parentTelegramUsername:
          parentTelegramUsername ?? this.parentTelegramUsername,
      parentLinkDate: parentLinkDate ?? this.parentLinkDate,
      streakCount: streakCount ?? this.streakCount,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      totalStudyTime: totalStudyTime ?? this.totalStudyTime,
      adminNotes: adminNotes ?? this.adminNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscriptions: subscriptions ?? this.subscriptions,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, schoolId: $schoolId, status: $accountStatus, hasSubscriptions: ${subscriptions != null && subscriptions!.isNotEmpty})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.username == username &&
        other.schoolId == schoolId &&
        other.accountStatus == accountStatus;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      username.hashCode ^
      schoolId.hashCode ^
      accountStatus.hashCode;
}
