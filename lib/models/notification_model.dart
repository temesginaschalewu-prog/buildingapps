class Notification {
  final int logId;
  final int? notificationId;
  final String title;
  final String message;
  final String deliveryStatus;
  final bool isRead;
  final DateTime receivedAt;
  final DateTime? sentAt;
  final DateTime? readAt;
  final DateTime? deliveredAt;
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
    print('Parsing notification JSON: $json');

    return Notification(
      logId: int.tryParse(json['log_id']?.toString() ?? '0') ?? 0,
      notificationId: json['notification_id'] != null
          ? int.tryParse(json['notification_id'].toString())
          : null,
      title: json['title']?.toString() ?? 'No Title',
      message: json['message']?.toString() ?? '',
      deliveryStatus: json['delivery_status']?.toString() ?? 'pending',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      receivedAt: json['received_at'] != null
          ? DateTime.parse(json['received_at'].toString()).toLocal()
          : (json['created_at'] != null
              ? DateTime.parse(json['created_at'].toString()).toLocal()
              : DateTime.now()),
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'].toString()).toLocal()
          : null,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'].toString()).toLocal()
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'].toString()).toLocal()
          : null,
      sentBy: json['sent_by'] != null
          ? int.tryParse(json['sent_by'].toString())
          : null,
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
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
