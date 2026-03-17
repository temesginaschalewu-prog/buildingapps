import '../utils/parsers.dart';
import 'package:hive/hive.dart'; // NEW

part 'notification_model.g.dart'; // NEW

@HiveType(typeId: 11) // NEW
class Notification {
  @HiveField(0)
  final int logId;

  @HiveField(1)
  final int? notificationId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String message;

  @HiveField(4)
  final String deliveryStatus;

  @HiveField(5)
  final bool isRead;

  @HiveField(6)
  final DateTime receivedAt;

  @HiveField(7)
  final DateTime? sentAt;

  @HiveField(8)
  final DateTime? readAt;

  @HiveField(9)
  final DateTime? deliveredAt;

  @HiveField(10)
  final int? sentBy;

  Notification({
    required this.logId,
    this.notificationId,
    required this.title,
    required this.message,
    required this.deliveryStatus,
    required this.isRead,
    required this.receivedAt,
    this.sentAt,
    this.readAt,
    this.deliveredAt,
    this.sentBy,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      logId: Parsers.parseInt(json['log_id']),
      notificationId: json['notification_id'] != null
          ? Parsers.parseInt(json['notification_id'])
          : null,
      title: json['title']?.toString() ?? 'No Title',
      message: json['message']?.toString() ?? '',
      deliveryStatus: json['delivery_status']?.toString() ?? 'pending',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      receivedAt:
          Parsers.parseDate(json['received_at'] ?? json['created_at']) ??
              DateTime.now(),
      sentAt: Parsers.parseDate(json['sent_at']),
      readAt: Parsers.parseDate(json['read_at']),
      deliveredAt: Parsers.parseDate(json['delivered_at']),
      sentBy:
          json['sent_by'] != null ? Parsers.parseInt(json['sent_by']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'notification_id': notificationId,
      'title': title,
      'message': message,
      'delivery_status': deliveryStatus,
      'is_read': isRead,
      'received_at': receivedAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'sent_by': sentBy,
    };
  }

  bool get isDelivered => deliveryStatus == 'delivered';
  bool get isFailed => deliveryStatus == 'failed';
  bool get isPending => deliveryStatus == 'pending';

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(receivedAt);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y ago';
    }
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    }
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
