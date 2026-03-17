import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'parent_link_model.g.dart'; // NEW

@HiveType(typeId: 18) // NEW
class ParentLink {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final int userId;

  @HiveField(2)
  final String token;

  @HiveField(3)
  final String? parentTelegramUsername;

  @HiveField(4)
  final int? parentTelegramId;

  @HiveField(5)
  final DateTime tokenExpiresAt;

  @HiveField(6)
  final DateTime? linkedAt;

  @HiveField(7)
  final DateTime? unlinkedAt;

  @HiveField(8)
  final String status;

  @HiveField(9)
  final String? username;

  @HiveField(10)
  final String? accountStatus;

  @HiveField(11)
  final String? parentName;

  @HiveField(12)
  final DateTime? serverTime;

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
    this.serverTime,
  });

  factory ParentLink.fromJson(Map<String, dynamic> json) {
    final expiresAtMs = Parsers.parseInt(json['expires_at_ms']);
    final serverTimeMs = Parsers.parseInt(json['server_time_ms']);

    return ParentLink(
      id: Parsers.parseInt(json['id']),
      userId: Parsers.parseInt(json['user_id']),
      token: json['token']?.toString() ?? '',
      parentTelegramUsername: json['parent_telegram_username']?.toString(),
      parentTelegramId: json['parent_telegram_id'] != null
          ? Parsers.parseInt(json['parent_telegram_id'])
          : null,
      tokenExpiresAt: expiresAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs, isUtc: true)
              .toLocal()
          : (Parsers.parseDate(json['token_expires_at']) ??
              Parsers.parseDate(json['expires_at']) ??
              DateTime.now()),
      linkedAt: Parsers.parseDate(json['linked_at']),
      unlinkedAt: Parsers.parseDate(json['unlinked_at']),
      status: json['status']?.toString() ?? 'pending',
      username: json['username']?.toString(),
      accountStatus: json['account_status']?.toString(),
      parentName: json['parent_name']?.toString() ??
          json['parent_telegram_username']?.toString(),
      serverTime: serverTimeMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(serverTimeMs, isUtc: true)
              .toLocal()
          : Parsers.parseDate(json['server_time']),
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
      'server_time': serverTime?.toUtc().toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isLinked => status == 'linked';
  bool get isUnlinked => status == 'unlinked';
  bool get isExpired => DateTime.now().isAfter(tokenExpiresAt);
  bool get isValid => isPending && !isExpired;
}
