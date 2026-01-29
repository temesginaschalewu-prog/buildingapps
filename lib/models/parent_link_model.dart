class ParentLink {
  final int id;
  final int userId;
  final String token;
  final String? parentTelegramUsername;
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
    required this.tokenExpiresAt,
    this.linkedAt,
    this.unlinkedAt,
    required this.status,
    this.username,
    this.accountStatus,
    this.parentName,
  });

  factory ParentLink.fromJson(Map<String, dynamic> json) {
    return ParentLink(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      token: json['token'] ?? '',
      parentTelegramUsername: json['parent_telegram_username'],
      tokenExpiresAt: DateTime.parse(
          json['token_expires_at'] ?? DateTime.now().toIso8601String()),
      linkedAt:
          json['linked_at'] != null ? DateTime.parse(json['linked_at']) : null,
      unlinkedAt: json['unlinked_at'] != null
          ? DateTime.parse(json['unlinked_at'])
          : null,
      status: json['status'] ?? 'pending',
      username: json['username'],
      accountStatus: json['account_status'],
      parentName: json['parent_name'] ?? json['parent_telegram_username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'token': token,
      'parent_telegram_username': parentTelegramUsername,
      'token_expires_at': tokenExpiresAt.toIso8601String(),
      'linked_at': linkedAt?.toIso8601String(),
      'unlinked_at': unlinkedAt?.toIso8601String(),
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
