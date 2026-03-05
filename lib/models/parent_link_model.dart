import '../utils/parsers.dart';

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
    return ParentLink(
      id: Parsers.parseInt(json['id']),
      userId: Parsers.parseInt(json['user_id']),
      token: json['token']?.toString() ?? '',
      parentTelegramUsername: json['parent_telegram_username']?.toString(),
      parentTelegramId: json['parent_telegram_id'] != null
          ? Parsers.parseInt(json['parent_telegram_id'])
          : null,
      tokenExpiresAt:
          Parsers.parseDate(json['token_expires_at']) ?? DateTime.now(),
      linkedAt: Parsers.parseDate(json['linked_at']),
      unlinkedAt: Parsers.parseDate(json['unlinked_at']),
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
