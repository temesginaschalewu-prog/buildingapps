import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/chatbot_model.dart';
import '../utils/helpers.dart';
import '../utils/api_response.dart';

class ChatbotProvider extends ChangeNotifier {
  final ApiService apiService;

  List<ChatbotMessage> _messages = [];
  List<ChatbotConversation> _conversations = [];
  ChatbotConversation? _currentConversation;

  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;
  String? _error;

  int _remainingMessages = 30;
  int _dailyLimit = 30;
  int _totalMessages = 0;
  int _totalConversations = 0;

  int _currentPage = 1;
  bool _hasMoreConversations = true;
  bool _isLoadingMore = false;

  ChatbotProvider({required this.apiService}) {
    loadConversations();
    loadUsageStats();
  }

  List<ChatbotMessage> get messages => List.unmodifiable(_messages);
  List<ChatbotConversation> get conversations =>
      List.unmodifiable(_conversations);
  ChatbotConversation? get currentConversation => _currentConversation;

  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get error => _error;

  int get remainingMessages => _remainingMessages;
  int get dailyLimit => _dailyLimit;
  bool get hasMessagesLeft => _remainingMessages > 0;
  int get totalMessages => _totalMessages;
  int get totalConversations => _totalConversations;

  bool get hasMoreConversations => _hasMoreConversations;

  Future<void> loadUsageStats() async {
    try {
      final response = await apiService.dio.get('/chatbot/usage');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final stats = ChatbotUsageStats.fromJson(response.data['data']);
        _remainingMessages = stats.remaining;
        _dailyLimit = stats.limit;
        _totalMessages = stats.totalMessages;
        _totalConversations = stats.totalConversations;
        debugLog('ChatbotProvider',
            '📊 Usage stats loaded: $_remainingMessages/$_dailyLimit');
        notifyListeners();
      }
    } catch (e) {
      debugLog('ChatbotProvider', 'Error loading usage stats: $e');
    }
  }

  Future<void> loadConversations({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreConversations = true;
      _conversations.clear();
    }

    if (_isLoadingConversations || !_hasMoreConversations) return;

    _isLoadingConversations = true;
    _isLoadingMore = _currentPage > 1;
    notifyListeners();

    try {
      final response = await apiService.dio.get(
        '/chatbot/conversations',
        queryParameters: {'page': _currentPage, 'limit': 20},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        final newConversations =
            data.map((json) => ChatbotConversation.fromJson(json)).toList();

        if (refresh) {
          _conversations = newConversations;
        } else {
          _conversations.addAll(newConversations);
        }

        final pagination = response.data['pagination'] ?? {};
        final totalPages = pagination['pages'] ?? 1;
        _hasMoreConversations = _currentPage < totalPages;

        if (_hasMoreConversations) {
          _currentPage++;
        }

        debugLog('ChatbotProvider',
            '📋 Loaded ${newConversations.length} conversations');
      }
    } catch (e) {
      _error = 'Failed to load conversations';
      debugLog('ChatbotProvider', 'Error loading conversations: $e');
    } finally {
      _isLoadingConversations = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(int conversationId) async {
    _isLoadingMessages = true;
    _error = null;
    notifyListeners();

    try {
      final response = await apiService.dio.get(
        '/chatbot/conversations/$conversationId/messages',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'];
        _messages = data.map((json) => ChatbotMessage.fromJson(json)).toList();

        _currentConversation = _conversations.firstWhere(
          (c) => c.id == conversationId,
          orElse: () => ChatbotConversation(
            id: conversationId,
            title: 'Conversation',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            messageCount: _messages.length,
          ),
        );

        debugLog('ChatbotProvider', '💬 Loaded ${_messages.length} messages');

        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
    } catch (e) {
      _error = 'Failed to load messages';
      debugLog('ChatbotProvider', 'Error loading messages: $e');
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  List<T> _takeLast<T>(Iterable<T> items, int n) {
    final list = items.toList();
    if (list.isEmpty) return [];
    if (list.length <= n) return list;
    return list.sublist(list.length - n);
  }

  Future<Map<String, dynamic>> sendMessage(
    String message, {
    int? conversationId,
  }) async {
    if (message.trim().isEmpty) {
      return {'success': false, 'error': 'Message cannot be empty'};
    }

    if (!hasMessagesLeft) {
      return {
        'success': false,
        'error': 'Daily message limit reached. Please try again tomorrow.',
      };
    }

    _isLoading = true;
    _error = null;

    final tempUserMessage = ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );
    _messages.add(tempUserMessage);
    notifyListeners();

    try {
      final List<String> history = [];
      if (_messages.length > 1) {
        for (int i = 0; i < _messages.length - 1; i++) {
          if (_messages[i].id < 1000000) {
            history.add(_messages[i].content);
          }
        }

        if (history.length > 10) {
          history.removeRange(0, history.length - 10);
        }
      }

      final response = await apiService.dio.post(
        '/chatbot/chat',
        data: {
          'message': message,
          'conversation_id': conversationId,
          'history': history,
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];

        final aiMessage = ChatbotMessage(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          role: 'assistant',
          content: data['reply'],
          timestamp: DateTime.now(),
        );
        _messages.add(aiMessage);

        if (data['remaining'] != null) {
          _remainingMessages = data['remaining'];
          debugLog(
              'ChatbotProvider', '📊 Updated remaining: $_remainingMessages');
        }

        loadUsageStats();

        if (conversationId == null && data['conversation_id'] != null) {
          await loadConversations(refresh: true);
        }

        notifyListeners();

        return {
          'success': true,
          'reply': data['reply'],
          'conversationId': data['conversation_id'],
          'suggestedQuestions': data['suggested_questions'] ?? [],
        };
      } else {
        throw Exception(response.data['message'] ?? 'Failed to send message');
      }
    } catch (e) {
      _messages.remove(tempUserMessage);

      _error = 'Failed to send message: $e';
      debugLog('ChatbotProvider', 'Error sending message: $e');

      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> renameConversation(int conversationId, String title) async {
    try {
      final response = await apiService.dio.put(
        '/chatbot/conversations/$conversationId',
        data: {'title': title},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final index = _conversations.indexWhere((c) => c.id == conversationId);
        if (index != -1) {
          _conversations[index] = ChatbotConversation(
            id: _conversations[index].id,
            title: title,
            createdAt: _conversations[index].createdAt,
            updatedAt: DateTime.now(),
            lastMessage: _conversations[index].lastMessage,
            lastMessageRole: _conversations[index].lastMessageRole,
            messageCount: _conversations[index].messageCount,
          );
        }

        if (_currentConversation?.id == conversationId) {
          _currentConversation = ChatbotConversation(
            id: _currentConversation!.id,
            title: title,
            createdAt: _currentConversation!.createdAt,
            updatedAt: DateTime.now(),
            lastMessage: _currentConversation!.lastMessage,
            lastMessageRole: _currentConversation!.lastMessageRole,
            messageCount: _currentConversation!.messageCount,
          );
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugLog('ChatbotProvider', 'Error renaming conversation: $e');
      return false;
    }
  }

  Future<bool> deleteConversation(int conversationId) async {
    try {
      final response = await apiService.dio.delete(
        '/chatbot/conversations/$conversationId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _conversations.removeWhere((c) => c.id == conversationId);

        if (_currentConversation?.id == conversationId) {
          _currentConversation = null;
          _messages.clear();
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugLog('ChatbotProvider', 'Error deleting conversation: $e');
      return false;
    }
  }

  void clearCurrentConversation() {
    _messages.clear();
    _currentConversation = null;
    notifyListeners();
  }

  Future<void> loadMoreConversations() async {
    if (!_hasMoreConversations || _isLoadingMore) return;
    await loadConversations();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}
