import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../models/chatbot_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/parsers.dart';

class ChatbotProvider with ChangeNotifier {
  final ApiService apiService;
  final ConnectivityService connectivityService;

  List<ChatbotMessage> _messages = [];
  List<ChatbotConversation> _conversations = [];
  ChatbotConversation? _currentConversation;

  bool _isLoading = false;
  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;
  String? _error;
  bool _isOffline = false;

  int _remainingMessages = 30;
  int _dailyLimit = 30;
  int _totalMessages = 0;
  int _totalConversations = 0;

  int _currentPage = 1;
  bool _hasMoreConversations = true;
  bool _isLoadingMore = false;

  ChatbotProvider({
    required this.apiService,
    required this.connectivityService,
  }) {
    _loadCachedData();
    loadConversations();
    loadUsageStats();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    connectivityService.onConnectivityChanged.listen((isOnline) {
      if (_isOffline != !isOnline) {
        _isOffline = !isOnline;
        if (!_isOffline) {
          syncPendingMessages();
        }
        notifyListeners();
      }
    });
  }

  List<ChatbotMessage> get messages => List.unmodifiable(_messages);
  List<ChatbotConversation> get conversations =>
      List.unmodifiable(_conversations);
  ChatbotConversation? get currentConversation => _currentConversation;

  bool get isLoading => _isLoading;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingConversations => _isLoadingConversations;
  String? get error => _error;
  bool get isOffline => _isOffline;

  int get remainingMessages => _remainingMessages;
  int get dailyLimit => _dailyLimit;
  bool get hasMessagesLeft => _remainingMessages > 0;
  int get totalMessages => _totalMessages;
  int get totalConversations => _totalConversations;

  bool get hasMoreConversations => _hasMoreConversations;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> _loadCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      final messagesKey = 'chatbot_messages_$userId';
      final conversationsKey = 'chatbot_conversations_$userId';
      final currentConvKey = 'chatbot_current_$userId';
      final usageKey = 'chatbot_usage_$userId';

      final messagesJson = prefs.getString(messagesKey);
      if (messagesJson != null) {
        final List<dynamic> messagesList =
            jsonDecode(messagesJson) as List<dynamic>;
        _messages = messagesList
            .map((m) => ChatbotMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }

      final conversationsJson = prefs.getString(conversationsKey);
      if (conversationsJson != null) {
        final List<dynamic> convList =
            jsonDecode(conversationsJson) as List<dynamic>;
        _conversations = convList
            .map((c) => ChatbotConversation.fromJson(c as Map<String, dynamic>))
            .toList();
      }

      final currentConvJson = prefs.getString(currentConvKey);
      if (currentConvJson != null) {
        final Map<String, dynamic> convMap =
            jsonDecode(currentConvJson) as Map<String, dynamic>;
        _currentConversation = ChatbotConversation.fromJson(convMap);
      }

      final usageJson = prefs.getString(usageKey);
      if (usageJson != null) {
        final Map<String, dynamic> usageMap =
            jsonDecode(usageJson) as Map<String, dynamic>;
        _remainingMessages = Parsers.parseInt(usageMap['remaining'], 30);
        _dailyLimit = Parsers.parseInt(usageMap['daily_limit'], 30);
        _totalMessages = Parsers.parseInt(usageMap['total_messages']);
        _totalConversations = Parsers.parseInt(usageMap['total_conversations']);
      }

      debugLog('ChatbotProvider', '📦 Loaded cached data for user $userId');
    } catch (e) {
      debugLog('ChatbotProvider', 'Error loading cache: $e');
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      final messagesKey = 'chatbot_messages_$userId';
      final conversationsKey = 'chatbot_conversations_$userId';
      final currentConvKey = 'chatbot_current_$userId';
      final usageKey = 'chatbot_usage_$userId';

      await prefs.setString(
          messagesKey, jsonEncode(_messages.map((m) => m.toJson()).toList()));
      await prefs.setString(conversationsKey,
          jsonEncode(_conversations.map((c) => c.toJson()).toList()));

      if (_currentConversation != null) {
        await prefs.setString(
            currentConvKey, jsonEncode(_currentConversation!.toJson()));
      }

      final usage = {
        'remaining': _remainingMessages,
        'daily_limit': _dailyLimit,
        'total_messages': _totalMessages,
        'total_conversations': _totalConversations,
      };
      await prefs.setString(usageKey, jsonEncode(usage));

      debugLog('ChatbotProvider', '💾 Saved chatbot data to cache');
    } catch (e) {
      debugLog('ChatbotProvider', 'Error saving to cache: $e');
    }
  }

  Future<void> loadUsageStats() async {
    try {
      if (_isOffline) return;

      final response = await apiService.dio.get('/chatbot/usage');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final stats = ChatbotUsageStats.fromJson(
            response.data['data'] as Map<String, dynamic>);
        _remainingMessages = stats.remaining;
        _dailyLimit = stats.limit;
        _totalMessages = stats.totalMessages;
        _totalConversations = stats.totalConversations;
        debugLog('ChatbotProvider',
            '📊 Usage stats loaded: $_remainingMessages/$_dailyLimit');
        notifyListeners();
        await _saveToCache();
      }
    } catch (e) {
      debugLog('ChatbotProvider', 'Error loading usage stats: $e');
    }
  }

  Future<void> loadConversations(
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    if (forceRefresh) {
      _currentPage = 1;
      _hasMoreConversations = true;
      _conversations.clear();
    }

    if (_isLoadingConversations || !_hasMoreConversations) return;

    _isLoadingConversations = true;
    _isLoadingMore = _currentPage > 1;
    notifyListeners();

    try {
      if (_isOffline) {
        _isLoadingConversations = false;
        _isLoadingMore = false;
        notifyListeners();

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      final response = await apiService.dio.get(
        '/chatbot/conversations',
        queryParameters: {'page': _currentPage, 'limit': 20},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] as List<dynamic>;
        final newConversations = data
            .map((json) =>
                ChatbotConversation.fromJson(json as Map<String, dynamic>))
            .toList();

        if (forceRefresh) {
          _conversations = newConversations;
        } else {
          _conversations.addAll(newConversations);
        }

        final pagination =
            response.data['pagination'] as Map<String, dynamic>? ?? {};
        final totalPages = Parsers.parseInt(pagination['pages'], 1);
        _hasMoreConversations = _currentPage < totalPages;

        if (_hasMoreConversations) {
          _currentPage++;
        }

        debugLog('ChatbotProvider',
            '📋 Loaded ${newConversations.length} conversations');
        await _saveToCache();
      } else {
        if (isManualRefresh) {
          throw Exception(
              response.data['message'] ?? 'Failed to load conversations');
        }
      }
    } catch (e) {
      _error = 'Failed to load conversations';
      debugLog('ChatbotProvider', 'Error loading conversations: $e');

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoadingConversations = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMessages(int conversationId,
      {bool forceRefresh = false, bool isManualRefresh = false}) async {
    _isLoadingMessages = true;
    _error = null;
    notifyListeners();

    try {
      if (_isOffline) {
        _isLoadingMessages = false;
        notifyListeners();

        if (isManualRefresh) {
          throw Exception(
              'Network error. Please check your internet connection.');
        }
        return;
      }

      final response = await apiService.dio.get(
        '/chatbot/conversations/$conversationId/messages',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] as List<dynamic>;
        _messages = data
            .map(
                (json) => ChatbotMessage.fromJson(json as Map<String, dynamic>))
            .toList();

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
        await _saveToCache();
      } else {
        if (isManualRefresh) {
          throw Exception(
              response.data['message'] ?? 'Failed to load messages');
        }
      }
    } catch (e) {
      _error = 'Failed to load messages';
      debugLog('ChatbotProvider', 'Error loading messages: $e');

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoadingMessages = false;
      notifyListeners();
    }
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
      if (_isOffline) {
        // Queue message for offline sync
        await _queueMessageOffline(message, conversationId);
        _isLoading = false;
        notifyListeners();
        return {
          'success': true,
          'queued': true,
          'message': 'Message saved offline. Will send when online.'
        };
      }

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
        final Map<String, dynamic> data =
            response.data['data'] as Map<String, dynamic>;

        final aiMessage = ChatbotMessage(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          role: 'assistant',
          content: data['reply'] as String,
          timestamp: DateTime.now(),
        );
        _messages.add(aiMessage);

        if (data['remaining'] != null) {
          _remainingMessages = Parsers.parseInt(data['remaining']);
          debugLog(
              'ChatbotProvider', ' Updated remaining: $_remainingMessages');
        }

        await loadUsageStats();

        if (conversationId == null && data['conversation_id'] != null) {
          await loadConversations(forceRefresh: true);
        }

        await _saveToCache();
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
      notifyListeners();

      return {'success': false, 'error': _error};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _queueMessageOffline(String message, int? conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_chat_messages';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);
      List<Map<String, dynamic>> pendingMessages = [];

      if (existingJson != null) {
        try {
          pendingMessages =
              List<Map<String, dynamic>>.from(jsonDecode(existingJson));
        } catch (e) {
          debugLog('ChatbotProvider', 'Error parsing pending messages: $e');
        }
      }

      pendingMessages.add({
        'message': message,
        'conversation_id': conversationId,
        'timestamp': DateTime.now().toIso8601String(),
        'retry_count': 0,
      });

      await prefs.setString(userPendingKey, jsonEncode(pendingMessages));
      debugLog('ChatbotProvider', '📝 Queued message for offline sync');
    } catch (e) {
      debugLog('ChatbotProvider', 'Error queueing message: $e');
    }
  }

  Future<void> syncPendingMessages() async {
    if (_isOffline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserSession().getCurrentUserId();

      if (userId == null) return;

      const pendingKey = 'pending_chat_messages';
      final userPendingKey = '${pendingKey}_$userId';
      final existingJson = prefs.getString(userPendingKey);

      if (existingJson == null) return;

      List<Map<String, dynamic>> pendingMessages = [];
      try {
        pendingMessages =
            List<Map<String, dynamic>>.from(jsonDecode(existingJson));
      } catch (e) {
        debugLog('ChatbotProvider', 'Error parsing pending messages: $e');
        await prefs.remove(userPendingKey);
        return;
      }

      if (pendingMessages.isEmpty) return;

      debugLog('ChatbotProvider',
          '🔄 Syncing ${pendingMessages.length} pending messages');

      final List<Map<String, dynamic>> failedMessages = [];

      for (final msg in pendingMessages) {
        try {
          await sendMessage(
            msg['message'],
            conversationId: msg['conversation_id'],
          );
          debugLog('ChatbotProvider', '✅ Synced message');
        } catch (e) {
          debugLog('ChatbotProvider', '❌ Failed to sync message: $e');

          final retryCount = (msg['retry_count'] ?? 0) + 1;
          if (retryCount <= 3) {
            msg['retry_count'] = retryCount;
            failedMessages.add(msg);
          }
        }
      }

      if (failedMessages.isEmpty) {
        await prefs.remove(userPendingKey);
        debugLog('ChatbotProvider', '✅ All pending messages synced');
      } else {
        await prefs.setString(userPendingKey, jsonEncode(failedMessages));
        debugLog('ChatbotProvider',
            '⚠️ ${failedMessages.length} messages still pending');
      }
    } catch (e) {
      debugLog('ChatbotProvider', 'Error syncing pending messages: $e');
    }
  }

  Future<bool> renameConversation(int conversationId, String title) async {
    try {
      if (_isOffline) {
        return false;
      }

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

        await _saveToCache();
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
      if (_isOffline) {
        return false;
      }

      final response = await apiService.dio.delete(
        '/chatbot/conversations/$conversationId',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        _conversations.removeWhere((c) => c.id == conversationId);

        if (_currentConversation?.id == conversationId) {
          _currentConversation = null;
          _messages.clear();
        }

        await _saveToCache();
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
    _saveToCache();
  }

  Future<void> loadMoreConversations() async {
    if (!_hasMoreConversations || _isLoadingMore) return;
    await loadConversations();
  }

  Future<void> clearUserData() async {
    debugLog(
        'ChatbotProvider', '🔍 Checking if chatbot data should be cleared');

    final session = UserSession();
    final currentUserId = await session.getCurrentUserId();
    final lastUserId = await session.getLastUserId();
    final isDifferentUser = currentUserId != lastUserId;
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('ChatbotProvider', '✅ Same user - preserving chatbot cache');
      return;
    }

    debugLog(
        'ChatbotProvider', '🔄 Different user logout - clearing chatbot data');

    // Clear pending messages
    if (lastUserId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_chat_messages_$lastUserId');
    }

    _messages.clear();
    _conversations.clear();
    _currentConversation = null;
    _remainingMessages = 30;
    _totalMessages = 0;
    _totalConversations = 0;
    _currentPage = 1;
    _hasMoreConversations = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (lastUserId != null) {
        final keysToRemove = prefs
            .getKeys()
            .where(
                (key) => key.startsWith('chatbot_') && key.contains(lastUserId))
            .toList();

        for (final key in keysToRemove) {
          await prefs.remove(key);
        }
        debugLog(
            'ChatbotProvider', '🧹 Cleared cache for old user $lastUserId');
      }
    } catch (e) {
      debugLog('ChatbotProvider', 'Error clearing cache: $e');
    }

    notifyListeners();
  }

  Future<bool> _isLoggingOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
