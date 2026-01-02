// lib/providers/chatbot_provider.dart - COMPLETELY FREE VERSION
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/helpers.dart';

class ChatbotProvider with ChangeNotifier {
  // List of free public AI APIs (no API keys needed)
  static const List<String> _freeApis = [
    // Option 1: DeepInfra (has free tier, uses public models)
    'https://api.deepinfra.com/v1/openai/chat/completions',

    // Option 2: Hugging Face Inference API (some models are free)
    'https://api-inference.huggingface.co/models/microsoft/DialoGPT-small',

    // Option 3: LocalAI (if you set it up locally)
    'http://localhost:8080/v1/chat/completions',
  ];

  int _messagesUsedToday = 0;
  DateTime? _lastMessageDate;
  bool _isLoading = false;
  String? _error;

  int get messagesUsedToday => _messagesUsedToday;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _checkAndResetCounter() {
    final now = DateTime.now();
    if (_lastMessageDate == null ||
        _lastMessageDate!.day != now.day ||
        _lastMessageDate!.month != now.month ||
        _lastMessageDate!.year != now.year) {
      _messagesUsedToday = 0;
      _lastMessageDate = now;
    }
  }

  bool get hasMessagesLeft {
    _checkAndResetCounter();
    return _messagesUsedToday < 100; // 100 messages per day free limit
  }

  Future<String> sendMessage(String message) async {
    _checkAndResetCounter();

    if (!hasMessagesLeft) {
      return 'Daily message limit reached. Please try again tomorrow.';
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('ChatbotProvider', 'Sending message: $message');

      // If no specific keyword found, use a general response
      final response = _getGeneralResponse(message);
      _incrementCounter();
      return response;
    } catch (e) {
      _error = e.toString();
      debugLog('ChatbotProvider', 'sendMessage error: $e');
      _isLoading = false;
      notifyListeners();

      // Fallback to basic response
      return 'I understand you\'re asking about education. For specific help with school subjects like math, science, or languages, please ask a more specific question.';
    }
  }

  String _getGeneralResponse(String message) {
    if (message.contains('?') ||
        message.contains('how') ||
        message.contains('what') ||
        message.contains('why')) {
      return 'That\'s a good question! For detailed explanations on school subjects, I recommend checking your textbooks or asking your teacher. I can help with general study tips and subject overviews.';
    } else if (message.length < 3) {
      return 'Hello! I\'m here to help with your studies. Please ask me about mathematics, science, languages, history, or study techniques.';
    } else {
      return 'I\'m an educational assistant. I can help you understand school subjects like mathematics, science, English, and history. What specific topic would you like to learn about?';
    }
  }

  void _incrementCounter() {
    _messagesUsedToday++;
    _lastMessageDate = DateTime.now();
    _isLoading = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  void clearError() {
    _error = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  // For testing - reset counter
  void resetCounter() {
    _messagesUsedToday = 0;
    _lastMessageDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (hasListeners) {
        notifyListeners();
      }
    });
  }

  // If you want to add a real AI API later, use this method
  Future<String?> _tryFreeApi(String message, String apiUrl) async {
    try {
      debugLog('ChatbotProvider', 'Trying API: $apiUrl');

      final headers = {
        'Content-Type': 'application/json',
      };

      Map<String, dynamic> body;

      if (apiUrl.contains('deepinfra')) {
        headers['Authorization'] =
            'Bearer '; // Some free endpoints don't need auth
        body = {
          'model': 'meta-llama/Llama-2-70b-chat-hf',
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an educational assistant for Ethiopian students. Help with school subjects only.',
            },
            {
              'role': 'user',
              'content': message,
            }
          ],
          'max_tokens': 200,
        };
      } else if (apiUrl.contains('huggingface')) {
        body = {
          'inputs': message,
        };
      } else {
        body = {
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'user',
              'content': message,
            }
          ],
          'max_tokens': 150,
        };
      }

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String responseText = '';

        if (apiUrl.contains('deepinfra') || apiUrl.contains('localhost')) {
          final choices = data['choices'];
          if (choices != null && choices.isNotEmpty) {
            responseText = choices[0]['message']['content'] ?? '';
          }
        } else if (apiUrl.contains('huggingface')) {
          final generatedText = data[0]['generated_text'];
          if (generatedText != null) {
            responseText = generatedText;
          }
        }

        return responseText.isNotEmpty ? responseText : null;
      }
    } catch (e) {
      debugLog('ChatbotProvider', 'API $apiUrl failed: $e');
    }

    return null;
  }
}
