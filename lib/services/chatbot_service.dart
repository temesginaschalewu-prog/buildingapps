import 'dart:convert';
import 'package:familyacademyclient/services/api_service.dart';
import '../utils/helpers.dart';

class ChatbotService {
  final ApiService apiService;

  final Map<String, String> _responseCache = {};
  final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistory = 10;

  ChatbotService({required this.apiService});

  Future<ChatbotResponse> sendMessage(String message) async {
    try {
      final cachedResponse = _responseCache[message.toLowerCase()];
      if (cachedResponse != null) {
        return ChatbotResponse(
          reply: cachedResponse,
          fromCache: true,
        );
      }

      final history = _conversationHistory.map((msg) {
        return {'role': msg['role'], 'content': msg['content']};
      }).toList();

      final response = await apiService.dio.post(
        '/chatbot/chat',
        data: {
          'message': message,
          'history': history,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final reply = response.data['data']['reply'];
        final remaining = response.data['data']['remaining'];

        _conversationHistory.add({'role': 'user', 'content': message});
        _conversationHistory.add({'role': 'assistant', 'content': reply});

        if (_conversationHistory.length > _maxHistory * 2) {
          _conversationHistory.removeRange(0, 2);
        }

        _responseCache[message.toLowerCase()] = reply;

        return ChatbotResponse(
          reply: reply,
          remainingMessages: remaining,
          fromCache: false,
        );
      }

      return ChatbotResponse(
        reply: _getEducationalFallback(message),
        fromCache: false,
      );
    } catch (e) {
      debugLog('ChatbotService', 'Error: $e');
      return ChatbotResponse(
        reply: _getEducationalFallback(message),
        fromCache: false,
        error: e.toString(),
      );
    }
  }

  Future<int> getRemainingMessages() async {
    try {
      final response = await apiService.dio.get('/chatbot/limits');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data']['remaining'] ?? 50;
      }
    } catch (e) {}
    return 50;
  }

  String _getEducationalFallback(String message) {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('math') || lowerMessage.contains('calculate')) {
      return 'Mathematics is about understanding patterns...';
    } else if (lowerMessage.contains('science')) {
      return 'Science helps us understand the natural world...';
    } else {
      return "I'm here to help with your educational journey...";
    }
  }

  void clearHistory() {
    _conversationHistory.clear();
    _responseCache.clear();
  }

  List<Map<String, String>> get conversationHistory =>
      List.from(_conversationHistory);
}

class ChatbotResponse {
  final String reply;
  final int? remainingMessages;
  final bool fromCache;
  final String? error;

  ChatbotResponse({
    required this.reply,
    this.remainingMessages,
    this.fromCache = false,
    this.error,
  });
}
