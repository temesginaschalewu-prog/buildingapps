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
      id: json['id'] ?? 0,
      title: json['title'] ?? 'New Conversation',
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
      lastMessage: json['last_message'],
      lastMessageRole: json['last_message_role'],
      messageCount: json['message_count'] ?? 0,
    );
  }
}

class ChatbotMessage {
  final int id;
  final String role; // 'user' or 'assistant'
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
      id: json['id'] ?? 0,
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

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
      remaining: daily['remaining'] ?? 30,
      limit: daily['limit'] ?? 30,
      used: daily['used'] ?? 0,
      totalMessages: json['total_messages'] ?? 0,
      totalConversations: json['total_conversations'] ?? 0,
      weeklyUsage: List<Map<String, dynamic>>.from(json['weekly_usage'] ?? []),
    );
  }
}
