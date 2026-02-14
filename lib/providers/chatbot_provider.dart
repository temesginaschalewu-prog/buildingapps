import 'dart:math';

import 'package:flutter/material.dart';
import '../services/chatbot_service.dart';
import '../utils/helpers.dart';

class ChatbotProvider with ChangeNotifier {
  final ChatbotService _chatbotService = ChatbotService();

  bool _isLoading = false;
  String? _error;
  final List<Map<String, dynamic>> _messages = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get messages => _messages;
  int get messagesUsedToday => _chatbotService.messagesUsedToday;
  int get remainingMessages => _chatbotService.remainingMessages;
  bool get hasMessagesLeft => _chatbotService.hasMessagesLeft;

  Future<String> sendMessage(String message) async {
    if (message.trim().isEmpty) {
      return 'Please enter a message';
    }

    if (!hasMessagesLeft) {
      return 'Daily message limit reached. You can send more messages tomorrow.';
    }

    _isLoading = true;
    _error = null;

    _addUserMessage(message);
    notifyListeners();

    try {
      debugLog('ChatbotProvider',
          'Sending message: ${message.substring(0, min(50, message.length))}...');

      final response = await _chatbotService.sendMessage(message);

      _addAiMessage(response);
      _isLoading = false;
      notifyListeners();

      return response;
    } catch (e) {
      _error = 'Failed to get response: $e';
      debugLog('ChatbotProvider', 'Error: $e');

      final fallbackResponse = _getFallbackResponse(message);
      _addAiMessage(fallbackResponse);

      _isLoading = false;
      notifyListeners();

      return fallbackResponse;
    }
  }

  void _addUserMessage(String message) {
    _messages.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'text': message.trim(),
      'isUser': true,
      'timestamp': DateTime.now(),
      'status': 'sent',
    });
  }

  void _addAiMessage(String message) {
    _messages.add({
      'id': DateTime.now().millisecondsSinceEpoch + 1,
      'text': message.trim(),
      'isUser': false,
      'timestamp': DateTime.now(),
      'status': 'received',
    });
  }

  String _getFallbackResponse(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('hello') ||
        lowerMessage.contains('hi') ||
        lowerMessage.contains('hey')) {
      return 'Hello! I\'m your educational assistant. How can I help with your studies today?';
    } else if (lowerMessage.contains('thank')) {
      return 'You\'re welcome! Keep up the great work with your studies.';
    } else if (lowerMessage.contains('help') ||
        lowerMessage.contains('support')) {
      return 'I\'m here to help with educational topics. Please ask about specific subjects or study techniques.';
    } else if (lowerMessage.contains('name')) {
      return 'I\'m your Family Academy AI Tutor, here to help you learn and understand various subjects.';
    } else if (lowerMessage.contains('subject') ||
        lowerMessage.contains('topic')) {
      return 'I can help with Mathematics, Science, Languages, Social Studies, and Computer Science. Which subject would you like to learn about?';
    } else {
      return '''Thanks for your message! I specialize in educational topics including:

📚 **Core Subjects**: Math, Science, English, Social Studies
💡 **Study Help**: Exam prep, homework assistance, learning techniques
🎯 **Skill Building**: Critical thinking, problem-solving, research skills

Please ask a specific question about what you\'re studying, and I\'ll provide detailed guidance.''';
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearConversation() {
    _messages.clear();
    _chatbotService.clearHistory();
    notifyListeners();
  }

  void addTestMessage(String message, bool isUser) {
    _messages.add({
      'id': DateTime.now().millisecondsSinceEpoch,
      'text': message,
      'isUser': isUser,
      'timestamp': DateTime.now(),
      'status': isUser ? 'sent' : 'received',
    });
    notifyListeners();
  }

  int get userMessageCount {
    return _messages.where((msg) => msg['isUser'] == true).length;
  }

  int get aiMessageCount {
    return _messages.where((msg) => msg['isUser'] == false).length;
  }

  bool get lastMessageFromUser {
    if (_messages.isEmpty) return false;
    return _messages.last['isUser'] == true;
  }

  Duration get conversationDuration {
    if (_messages.isEmpty) return Duration.zero;

    final firstMessageTime = _messages.first['timestamp'] as DateTime;
    final lastMessageTime = _messages.last['timestamp'] as DateTime;

    return lastMessageTime.difference(firstMessageTime);
  }
}
