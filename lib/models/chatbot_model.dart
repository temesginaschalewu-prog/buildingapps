import 'dart:convert';
import '../utils/parsers.dart';

class ChatbotConversation {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final String? lastMessageRole;
  final int messageCount;

  ChatbotConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageRole,
    required this.messageCount,
  });

  factory ChatbotConversation.fromJson(Map<String, dynamic> json) {
    return ChatbotConversation(
      id: Parsers.parseInt(json['id']),
      title: json['title']?.toString() ?? 'New Conversation',
      createdAt: Parsers.parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: Parsers.parseDate(json['updated_at']) ?? DateTime.now(),
      lastMessage: json['last_message']?.toString(),
      lastMessageRole: json['last_message_role']?.toString(),
      messageCount: Parsers.parseInt(json['message_count']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_message': lastMessage,
      'last_message_role': lastMessageRole,
      'message_count': messageCount,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}

class ChatbotMessage {
  final int id;
  final String role;
  final String content;
  final DateTime timestamp;

  ChatbotMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatbotMessage.fromJson(Map<String, dynamic> json) {
    return ChatbotMessage(
      id: Parsers.parseInt(json['id']),
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      timestamp: Parsers.parseDate(json['timestamp']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  String toJsonString() => jsonEncode(toJson());

  bool get isUser => role == 'user';
}

class ChatbotUsageStats {
  final int remaining;
  final int limit;
  final int used;
  final int totalMessages;
  final int totalConversations;
  final List<Map<String, dynamic>> weeklyUsage;

  ChatbotUsageStats({
    required this.remaining,
    required this.limit,
    required this.used,
    required this.totalMessages,
    required this.totalConversations,
    required this.weeklyUsage,
  });

  factory ChatbotUsageStats.fromJson(Map<String, dynamic> json) {
    final daily = json['daily'] ?? {};
    return ChatbotUsageStats(
      remaining: Parsers.parseInt(daily['remaining'], 30),
      limit: Parsers.parseInt(daily['limit'], 30),
      used: Parsers.parseInt(daily['used']),
      totalMessages: Parsers.parseInt(json['total_messages']),
      totalConversations: Parsers.parseInt(json['total_conversations']),
      weeklyUsage: List<Map<String, dynamic>>.from(json['weekly_usage'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'daily': {
        'remaining': remaining,
        'limit': limit,
        'used': used,
      },
      'total_messages': totalMessages,
      'total_conversations': totalConversations,
      'weekly_usage': weeklyUsage,
    };
  }

  double get usagePercentage => limit > 0 ? used / limit : 0;
  bool get hasRemaining => remaining > 0;
}
