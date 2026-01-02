class Notification {
  final int id;
  final String title;
  final String message;
  final String deliveryStatus; // 'delivered', 'failed', 'pending'
  final DateTime receivedAt;
  final DateTime? sentAt;

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.deliveryStatus,
    required this.receivedAt,
    this.sentAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'],
      title: json['title'],
      message: json['message'],
      deliveryStatus: json['delivery_status'],
      receivedAt: DateTime.parse(json['received_at']),
      sentAt: json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'delivery_status': deliveryStatus,
      'received_at': receivedAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
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
