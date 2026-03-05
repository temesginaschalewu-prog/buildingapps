import '../utils/constants.dart';
import '../utils/parsers.dart';

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
  final List<Map<String, dynamic>>? subscriptions;

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
    this.subscriptions,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>>? parseSubscriptions(dynamic value) {
      if (value == null) return null;
      if (value is List) {
        return value
            .map((item) =>
                item is Map<String, dynamic> ? item : <String, dynamic>{})
            .toList();
      }
      return null;
    }

    return User(
      id: Parsers.parseInt(json['id']),
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      profileImage: json['profile_image']?.toString(),
      schoolId: json['school_id'] != null
          ? Parsers.parseInt(json['school_id'])
          : null,
      accountStatus: json['account_status']?.toString() ?? 'unpaid',
      primaryDeviceId: json['primary_device_id']?.toString(),
      tvDeviceId: json['tv_device_id']?.toString(),
      parentLinked: Parsers.parseBool(json['parent_linked']),
      parentTelegramUsername: json['parent_telegram_username']?.toString(),
      parentLinkDate: Parsers.parseDate(json['parent_link_date']),
      streakCount: Parsers.parseInt(json['streak_count']),
      lastStreakDate: Parsers.parseDate(json['last_streak_date']),
      totalStudyTime: Parsers.parseInt(json['total_study_time']),
      adminNotes: json['admin_notes']?.toString(),
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: Parsers.parseDate(json['updated_at']) ?? DateTime.now(),
      subscriptions: parseSubscriptions(json['subscriptions']),
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
      'subscriptions': subscriptions,
    };
  }

  bool get isActive => accountStatus == 'active';
  bool get isUnpaid => accountStatus == 'unpaid';
  bool get isExpired => accountStatus == 'expired';
  bool get hasTvDevice => tvDeviceId?.isNotEmpty ?? false;
  bool get hasParentLinked => parentLinked;
  bool get needsSchoolSelection => schoolId == null || schoolId == 0;

  String? get fullProfileImageUrl {
    if (profileImage?.isEmpty ?? true) return null;

    if (profileImage!.startsWith('http://') ||
        profileImage!.startsWith('https://')) {
      return profileImage;
    }

    final cleanPath = profileImage!.startsWith('/')
        ? profileImage!.substring(1)
        : profileImage!;
    return '${AppConstants.baseUrl}/$cleanPath';
  }

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
  String toString() =>
      'User(id: $id, username: $username, schoolId: $schoolId, status: $accountStatus)';

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
