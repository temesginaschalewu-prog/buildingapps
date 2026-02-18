class ParentLink {
  final int id;
  final int userId;
  final String token;
  final String? parentTelegramUsername;
  final int? parentTelegramId;
  final DateTime tokenExpiresAt;
  final DateTime? linkedAt;
  final DateTime? unlinkedAt;
  final String status;
  final String? username;
  final String? accountStatus;
  final String? parentName;

  ParentLink({
    required this.id,
    required this.userId,
    required this.token,
    this.parentTelegramUsername,
    this.parentTelegramId,
    required this.tokenExpiresAt,
    this.linkedAt,
    this.unlinkedAt,
    required this.status,
    this.username,
    this.accountStatus,
    this.parentName,
  });

  factory ParentLink.fromJson(Map<String, dynamic> json) {
    // FIXED: Proper date parsing for MySQL datetime format
    DateTime parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return DateTime.now();
      try {
        // Try parsing as ISO string
        return DateTime.parse(dateStr).toLocal();
      } catch (e) {
        try {
          // Try parsing MySQL datetime format (YYYY-MM-DD HH:MM:SS)
          if (dateStr.contains(' ')) {
            return DateTime.parse(dateStr.replaceFirst(' ', 'T')).toLocal();
          }
          return DateTime.parse(dateStr).toLocal();
        } catch (e2) {
          print('Error parsing date: $dateStr');
          return DateTime.now();
        }
      }
    }

    return ParentLink(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      token: json['token']?.toString() ?? '',
      parentTelegramUsername: json['parent_telegram_username']?.toString(),
      parentTelegramId: json['parent_telegram_id'] != null
          ? int.tryParse(json['parent_telegram_id'].toString())
          : null,
      tokenExpiresAt: parseDate(json['token_expires_at']?.toString()),
      linkedAt: json['linked_at'] != null
          ? parseDate(json['linked_at']?.toString())
          : null,
      unlinkedAt: json['unlinked_at'] != null
          ? parseDate(json['unlinked_at']?.toString())
          : null,
      status: json['status']?.toString() ?? 'pending',
      username: json['username']?.toString(),
      accountStatus: json['account_status']?.toString(),
      parentName: json['parent_name']?.toString() ??
          json['parent_telegram_username']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'token': token,
      'parent_telegram_username': parentTelegramUsername,
      'parent_telegram_id': parentTelegramId,
      'token_expires_at': tokenExpiresAt.toUtc().toIso8601String(),
      'linked_at': linkedAt?.toUtc().toIso8601String(),
      'unlinked_at': unlinkedAt?.toUtc().toIso8601String(),
      'status': status,
      'username': username,
      'account_status': accountStatus,
      'parent_name': parentName,
    };
  }

  bool get isPending => status == 'pending';
  bool get isLinked => status == 'linked';
  bool get isUnlinked => status == 'unlinked';
  bool get isExpired => DateTime.now().isAfter(tokenExpiresAt);
  bool get isValid => isPending && !isExpired;
}
