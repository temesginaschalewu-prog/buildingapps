import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../utils/helpers.dart';

class ChatbotService {
  static const String _openRouterApiKey =
      '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'; // Free tier key
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  // Educational models (free tier)
  static const List<String> _availableModels = [
    'google/gemma-7b-it:free',
    'mistralai/mistral-7b-instruct:free',
    'huggingfaceh4/zephyr-7b-beta:free',
    'meta-llama/llama-2-7b-chat:free',
  ];

  // Cache for recent messages
  final Map<String, String> _responseCache = {};
  final List<Map<String, String>> _conversationHistory = [];
  static const int _maxHistory = 10;
  static const int _dailyLimit = 50;
  int _messagesToday = 0;
  DateTime? _lastResetDate;

  Future<String> sendMessage(String message) async {
    try {
      _checkAndResetDailyCounter();

      if (_messagesToday >= _dailyLimit) {
        return "You've reached the daily limit of $_dailyLimit messages. Please try again tomorrow.";
      }

      // Check cache first
      final cachedResponse = _responseCache[message.toLowerCase()];
      if (cachedResponse != null) {
        debugLog('ChatbotService', 'Returning cached response');
        return cachedResponse;
      }

      // Add to conversation history
      _conversationHistory.add({'role': 'user', 'content': message});
      if (_conversationHistory.length > _maxHistory) {
        _conversationHistory.removeAt(0);
      }

      // Select random model (load balancing)
      final random = Random();
      final model = _availableModels[random.nextInt(_availableModels.length)];

      debugLog('ChatbotService', 'Using model: $model');

      // Prepare messages for API
      final messages = [
        {
          'role': 'system',
          'content': _getSystemPrompt(),
        },
        ..._conversationHistory,
      ];

      // Call API
      final response = await _callOpenRouterAPI(messages, model);

      if (response.isNotEmpty) {
        // Cache the response
        _responseCache[message.toLowerCase()] = response;

        // Add to conversation history
        _conversationHistory.add({'role': 'assistant', 'content': response});
        if (_conversationHistory.length > _maxHistory) {
          _conversationHistory.removeAt(0);
        }

        _messagesToday++;
        return response;
      } else {
        // Fallback to educational responses
        return _getEducationalFallback(message);
      }
    } catch (e) {
      debugLog('ChatbotService', 'Error: $e');
      return _getEducationalFallback(message);
    }
  }

  Future<String> _callOpenRouterAPI(
      List<Map<String, String>> messages, String model) async {
    try {
      final headers = {
        'Authorization': 'Bearer $_openRouterApiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://familyacademy.com', // Your app URL
        'X-Title': 'Family Academy',
      };

      final body = {
        'model': model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 300,
        'top_p': 0.9,
        'frequency_penalty': 0.3,
        'presence_penalty': 0.3,
      };

      final response = await http
          .post(
            Uri.parse(_openRouterUrl),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          return choices[0]['message']['content'].toString().trim();
        }
      } else {
        debugLog('ChatbotService',
            'API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugLog('ChatbotService', 'API Exception: $e');
    }

    return '';
  }

  String _getSystemPrompt() {
    return '''You are an educational AI assistant for Family Academy, an Ethiopian educational platform. Your role is to help students with:

SUBJECT HELP:
- Mathematics (Algebra, Geometry, Calculus, Statistics)
- Science (Physics, Chemistry, Biology, Earth Science)
- Languages (English, Amharic, Grammar, Writing)
- Social Studies (History, Geography, Civics, Economics)
- Computer Science (Programming, Digital Literacy)

TEACHING APPROACH:
1. Provide clear, step-by-step explanations
2. Use examples relevant to Ethiopian context
3. Break down complex concepts
4. Suggest study techniques and resources
5. Encourage critical thinking

RULES:
- Stay focused on educational topics
- Be encouraging and supportive
- Use appropriate language for students
- If you don't know something, admit it and suggest resources
- Never provide harmful or inappropriate content
- Help with homework but don't give direct answers
- Explain concepts instead of just giving answers

FORMAT:
- Use clear, simple language
- Use bullet points for steps
- Add examples where helpful
- End with a summary or key takeaway''';
  }

  String _getEducationalFallback(String message) {
    final lowerMessage = message.toLowerCase();

    // Subject detection
    if (lowerMessage.contains('math') ||
        lowerMessage.contains('calculate') ||
        lowerMessage.contains('equation')) {
      return '''Mathematics is about understanding patterns and relationships. 

For help with ${message.contains('algebra') ? 'algebra' : message.contains('geometry') ? 'geometry' : 'mathematics'}:

1. **Identify the problem type**
2. **Write down what you know**
3. **Use relevant formulas**
4. **Check your work step by step**

Example: For equation solving, isolate the variable by doing the same operation on both sides. Practice with simple problems first, then gradually increase difficulty.''';
    } else if (lowerMessage.contains('science') ||
        lowerMessage.contains('physics') ||
        lowerMessage.contains('chemistry') ||
        lowerMessage.contains('biology')) {
      return '''Science helps us understand the natural world. 

For ${message.contains('physics') ? 'physics' : message.contains('chemistry') ? 'chemistry' : message.contains('biology') ? 'biology' : 'science'} studies:

1. **Observe carefully** - What do you see?
2. **Ask questions** - Why does this happen?
3. **Form a hypothesis** - What might explain it?
4. **Test your ideas** - Experiment or research
5. **Draw conclusions** - What did you learn?

Remember: Science is about curiosity and evidence. Always look for reliable sources.''';
    } else if (lowerMessage.contains('english') ||
        lowerMessage.contains('grammar') ||
        lowerMessage.contains('write') ||
        lowerMessage.contains('language')) {
      return '''Language skills develop with practice. 

For English improvement:

📚 **Reading**: Read daily - books, articles, anything interesting
✍️ **Writing**: Write about your day, thoughts, or stories
🎧 **Listening**: Watch English shows or listen to podcasts
🗣️ **Speaking**: Practice conversations, even with yourself

Grammar Tip: Focus on one rule at a time. Today, practice ${message.contains('tense') ? 'verb tenses' : 'subject-verb agreement'}.''';
    } else if (lowerMessage.contains('history') ||
        lowerMessage.contains('geography') ||
        lowerMessage.contains('social')) {
      return '''Social studies connects us to our world. 

Key areas to explore:

🏛️ **History**: Learn from the past to understand the present
🗺️ **Geography**: Study places and their relationships
👥 **Civics**: Understand rights, responsibilities, and government
💰 **Economics**: Learn about resources and choices

Study Tip: Create timelines for history, maps for geography, and diagrams for systems.''';
    } else if (lowerMessage.contains('study') ||
        lowerMessage.contains('learn') ||
        lowerMessage.contains('exam') ||
        lowerMessage.contains('test')) {
      return '''Effective studying requires good strategies:

🎯 **Active Learning**:
- Summarize in your own words
- Teach the material to someone else
- Create flashcards or mind maps

⏰ **Time Management**:
- Study in 25-minute blocks with 5-minute breaks
- Review regularly, not just before exams
- Start with difficult subjects when fresh

📝 **Exam Preparation**:
- Understand the format and topics
- Practice with past papers
- Get enough sleep before exams

Remember: Consistent, focused study beats last-minute cramming.''';
    } else {
      return '''Hello! I'm here to help with your educational journey. 

I can assist with:
• Mathematics problems and concepts
• Science explanations and experiments
• Language learning and writing skills
• History and social studies topics
• Study techniques and exam preparation
• Computer science and programming basics

Please ask a specific question about what you're learning, and I'll do my best to help! 

Tip: The more specific your question, the better I can assist you.''';
    }
  }

  void _checkAndResetDailyCounter() {
    final now = DateTime.now();
    if (_lastResetDate == null ||
        _lastResetDate!.day != now.day ||
        _lastResetDate!.month != now.month ||
        _lastResetDate!.year != now.year) {
      _messagesToday = 0;
      _lastResetDate = now;
    }
  }

  int get messagesUsedToday => _messagesToday;
  int get remainingMessages => max(0, _dailyLimit - _messagesToday);
  bool get hasMessagesLeft => _messagesToday < _dailyLimit;

  void clearHistory() {
    _conversationHistory.clear();
    _responseCache.clear();
  }

  List<Map<String, String>> get conversationHistory =>
      List.from(_conversationHistory);
}
