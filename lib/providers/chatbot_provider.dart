// lib/providers/chatbot_provider.dart
// PRODUCTION-READY FINAL VERSION - WITH AUTO LOAD ON OPEN

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../services/offline_queue_manager.dart';
import '../models/chatbot_model.dart';
import '../utils/constants.dart';
import '../utils/parsers.dart';
import '../utils/api_response.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

class ChatbotProvider extends ChangeNotifier
    with BaseProvider<ChatbotProvider>, OfflineAwareProvider<ChatbotProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final HiveService hiveService;
  final OfflineQueueManager offlineQueueManager;

  List<ChatbotMessage> _messages = [];
  List<ChatbotConversation> _conversations = [];
  ChatbotConversation? _currentConversation;

  bool _isLoadingMessages = false;
  bool _isLoadingConversations = false;

  bool _hasLoadedConversations = false;
  bool _hasLoadedMessages = false;
  bool _hasInitialData = false;

  int _apiCallCount = 0;

  static const int _defaultDailyLimit = 20;
  static const Duration _usageFetchCooldown = Duration(seconds: 20);

  int _remainingMessages = _defaultDailyLimit;
  int _dailyLimit = _defaultDailyLimit;
  int _totalMessages = 0;
  int _totalConversations = 0;
  String? _usageDayKey;
  DateTime? _lastUsageFetchAt;
  Completer<void>? _usageStatsCompleter;

  int _currentPage = 1;
  bool _hasMoreConversations = true;
  bool _isLoadingMore = false;

  Box? _messagesBox;
  Box? _conversationsBox;
  Box? _usageBox;

  DateTime? _lastBackgroundRefreshConversations;
  final Map<int, DateTime?> _lastBackgroundRefreshMessages = {};
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  ChatbotProvider({
    required this.apiService,
    required this.connectivityService,
    required this.hiveService,
    required this.offlineQueueManager,
  }) {
    log('ChatbotProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: offlineQueueManager,
    );
    _registerQueueProcessors();
    _init();
  }

  void _registerQueueProcessors() {
    offlineQueueManager.registerProcessor(
      AppConstants.queueActionSendChatMessage,
      _processSendChatMessage,
    );
    log('✅ Registered queue processors');
  }

  Future<bool> _processSendChatMessage(Map<String, dynamic> data) async {
    try {
      log('Processing offline chat message');
      final response = await apiService.sendChatbotMessage(
        data['message'],
        conversationId: data['conversation_id'],
      );
      return response.success;
    } catch (e) {
      log('Error processing chat message: $e');
      return false;
    }
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedData();

    // ✅ CRITICAL: Always load conversations when screen opens
    if (!_hasLoadedConversations && !isOffline) {
      log('🔄 Loading conversations on init');
      await loadConversations();
    }

    // ✅ If we have cached data, notify listeners
    if (_hasInitialData) {
      safeNotify();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (Hive.isBoxOpen(AppConstants.hiveChatbotMessagesBox)) {
        _messagesBox = Hive.box(AppConstants.hiveChatbotMessagesBox);
        log('✅ Using existing messages box');
      } else {
        _messagesBox = await Hive.openBox(AppConstants.hiveChatbotMessagesBox);
        log('✅ Opened messages box');
      }

      if (Hive.isBoxOpen(AppConstants.hiveChatbotConversationsBox)) {
        _conversationsBox = Hive.box(AppConstants.hiveChatbotConversationsBox);
        log('✅ Using existing conversations box');
      } else {
        _conversationsBox =
            await Hive.openBox(AppConstants.hiveChatbotConversationsBox);
        log('✅ Opened conversations box');
      }

      if (Hive.isBoxOpen('chatbot_usage_box')) {
        _usageBox = Hive.box('chatbot_usage_box');
        log('✅ Using existing usage box');
      } else {
        _usageBox = await Hive.openBox('chatbot_usage_box');
        log('✅ Opened usage box');
      }
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  String _todayKey() {
    final now = DateTime.now().toLocal();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _loadCachedData() async {
    log('_loadCachedData() START');

    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) {
        log('No userId, skipping cache load');
        return;
      }

      bool hasAnyData = false;

      // Load conversations from Hive
      if (_conversationsBox != null) {
        final conversationsKey = 'user_${userId}_conversations';
        final cachedConversations = _conversationsBox!.get(conversationsKey);
        if (cachedConversations != null && cachedConversations is List) {
          final List<ChatbotConversation> conversations = [];
          for (final item in cachedConversations) {
            if (item is ChatbotConversation) {
              conversations.add(item);
            } else if (item is Map<String, dynamic>) {
              conversations.add(ChatbotConversation.fromJson(item));
            }
          }
          if (conversations.isNotEmpty) {
            _conversations = conversations;
            _hasLoadedConversations = true;
            hasAnyData = true;
            log('✅ Loaded ${_conversations.length} conversations from Hive');
          }
        }
      }

      // Load current conversation from Hive
      if (_conversationsBox != null) {
        final currentKey = 'user_${userId}_current';
        final currentConv = _conversationsBox!.get(currentKey);
        if (currentConv != null &&
            currentConv is List &&
            currentConv.isNotEmpty) {
          if (currentConv.first is ChatbotConversation) {
            _currentConversation = currentConv.first;
          } else if (currentConv.first is Map<String, dynamic>) {
            _currentConversation =
                ChatbotConversation.fromJson(currentConv.first);
          }
          if (_currentConversation != null) hasAnyData = true;
        }
      }

      // Load messages for current conversation
      if (_currentConversation != null && _messagesBox != null) {
        final messagesKey =
            'user_${userId}_conv_${_currentConversation!.id}_messages';
        final cachedMessages = _messagesBox!.get(messagesKey);
        if (cachedMessages != null && cachedMessages is List) {
          final List<ChatbotMessage> messages = [];
          for (final item in cachedMessages) {
            if (item is ChatbotMessage) {
              messages.add(item);
            } else if (item is Map<String, dynamic>) {
              messages.add(ChatbotMessage.fromJson(item));
            }
          }
          if (messages.isNotEmpty) {
            _messages = messages;
            _hasLoadedMessages = true;
            hasAnyData = true;
            log('✅ Loaded ${_messages.length} messages from Hive');
          }
        }
      }

      // Load usage stats from Hive
      if (_usageBox != null) {
        final usageKey = 'user_${userId}_usage';
        final usageMap = _usageBox!.get(usageKey);
        if (usageMap != null && usageMap is Map) {
          final cachedDay = usageMap['day_key']?.toString();
          final today = _todayKey();
          _usageDayKey = cachedDay;
          _dailyLimit = Parsers.parseInt(
            usageMap['daily_limit'],
            _defaultDailyLimit,
          ).clamp(1, 500);

          if (cachedDay == today) {
            final cachedRemaining = Parsers.parseInt(
              usageMap['remaining'],
              _dailyLimit,
            );
            _remainingMessages = cachedRemaining.clamp(0, _dailyLimit);
          } else {
            _remainingMessages = _dailyLimit;
          }

          _totalMessages = Parsers.parseInt(usageMap['total_messages']);
          _totalConversations =
              Parsers.parseInt(usageMap['total_conversations']);
          hasAnyData = true;
          log('✅ Loaded usage stats from Hive');
        }
      }

      _hasInitialData = hasAnyData;

      if (_hasInitialData) {
        log('✅ hasInitialData set to TRUE');
      } else {
        log('ℹ️ No cached data found');
      }
    } catch (e) {
      log('Error loading cache: $e');
      _hasInitialData = false;
    }
  }

  Future<void> _saveToCache() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      if (_conversationsBox != null) {
        final conversationsKey = 'user_${userId}_conversations';
        await _conversationsBox!.put(conversationsKey, _conversations);
        log('💾 Saved conversations to Hive');
      }

      if (_conversationsBox != null && _currentConversation != null) {
        final currentKey = 'user_${userId}_current';
        await _conversationsBox!.put(currentKey, [_currentConversation!]);
        log('💾 Saved current conversation to Hive');
      }

      if (_currentConversation != null && _messagesBox != null) {
        final messagesKey =
            'user_${userId}_conv_${_currentConversation!.id}_messages';
        await _messagesBox!.put(messagesKey, _messages);
        log('💾 Saved messages to Hive');
      }

      if (_usageBox != null) {
        final usageKey = 'user_${userId}_usage';
        final usage = {
          'remaining': _remainingMessages,
          'daily_limit': _dailyLimit,
          'day_key': _usageDayKey ?? _todayKey(),
          'total_messages': _totalMessages,
          'total_conversations': _totalConversations,
        };
        await _usageBox!.put(usageKey, usage);
        log('💾 Saved usage stats to Hive');
      }
    } catch (e) {
      log('Error saving to cache: $e');
    }
  }

  // ===== GETTERS =====
  List<ChatbotMessage> get messages => List.unmodifiable(_messages);
  List<ChatbotConversation> get conversations =>
      List.unmodifiable(_conversations);
  ChatbotConversation? get currentConversation => _currentConversation;

  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingConversations => _isLoadingConversations;

  bool get hasLoadedConversations => _hasLoadedConversations;
  bool get hasLoadedMessages => _hasLoadedMessages;
  bool get hasInitialData => _hasInitialData;

  int get remainingMessages => _remainingMessages;
  int get dailyLimit => _dailyLimit;
  bool get hasMessagesLeft => _remainingMessages > 0;
  int get totalMessages => _totalMessages;
  int get totalConversations => _totalConversations;

  bool get hasMoreConversations => _hasMoreConversations;
  bool get isLoadingMore => _isLoadingMore;

  // ===== LOAD USAGE STATS =====
  Future<void> loadUsageStats({bool force = false}) async {
    log('loadUsageStats()');

    try {
      if (isOffline) {
        log('Offline, using cached stats');
        return;
      }

      if (!force && _lastUsageFetchAt != null) {
        final elapsed = DateTime.now().difference(_lastUsageFetchAt!);
        if (elapsed < _usageFetchCooldown) {
          log('Skipping usage fetch - too soon');
          return;
        }
      }

      if (_usageStatsCompleter != null) {
        log('Waiting for existing fetch');
        await _usageStatsCompleter!.future;
        return;
      }

      _usageStatsCompleter = Completer<void>();

      log('Fetching usage stats from API');
      final response = await apiService.getChatbotUsage();

      if (response.success && response.data != null) {
        final stats = ChatbotUsageStats.fromJson(response.data!);
        final today = _todayKey();

        if (_usageDayKey != today) {
          _usageDayKey = today;
          _remainingMessages = _dailyLimit;
        }

        _dailyLimit = stats.limit > 0 ? stats.limit.clamp(1, 500) : _dailyLimit;
        final fetched = stats.remaining.clamp(0, _dailyLimit);
        if (fetched < _remainingMessages) {
          log('Updating remaining messages from $_remainingMessages to $fetched via usage stats');
          _remainingMessages = fetched;
        }
        _totalMessages = stats.totalMessages;
        _totalConversations = stats.totalConversations;
        _lastUsageFetchAt = DateTime.now();

        await _saveToCache();
        log('✅ Loaded usage stats from API');
      }
    } catch (e) {
      log('Error loading usage stats: $e');
    } finally {
      _usageStatsCompleter?.complete();
      _usageStatsCompleter = null;
      safeNotify();
    }
  }

  // ===== LOAD CONVERSATIONS =====
  Future<void> loadConversations({
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadConversations() CALL #$callId - forceRefresh: $forceRefresh, isManualRefresh: $isManualRefresh');

    if (isManualRefresh && isOffline) {
      if (_conversations.isNotEmpty) {
        clearError();
        _hasLoadedConversations = true;
        _hasInitialData = true;
        safeNotify();
        return;
      }
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (_hasLoadedConversations && !forceRefresh && !isManualRefresh) {
      log('✅ Already have conversations, returning cached');
      safeNotify();
      return;
    }

    if (_isLoadingConversations && !forceRefresh) {
      log('⏳ Already loading, skipping');
      return;
    }

    _isLoadingConversations = true;
    _isLoadingMore = _currentPage > 1;
    safeNotify();

    try {
      // STEP 1: Try Hive cache first
      if (!forceRefresh && _conversations.isEmpty) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _conversationsBox != null) {
          final cachedConversations =
              _conversationsBox!.get('user_${userId}_conversations');

          if (cachedConversations != null && cachedConversations is List) {
            final List<ChatbotConversation> conversations = [];
            for (final item in cachedConversations) {
              if (item is ChatbotConversation) {
                conversations.add(item);
              } else if (item is Map<String, dynamic>) {
                conversations.add(ChatbotConversation.fromJson(item));
              }
            }
            if (conversations.isNotEmpty) {
              _conversations = conversations;
              _hasLoadedConversations = true;
              _hasInitialData = true;
              _isLoadingConversations = false;
              _isLoadingMore = false;
              log('✅ Loaded ${_conversations.length} conversations from Hive');

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshConversationsInBackground());
              }
              return;
            }
          }
        }
      }

      // STEP 2: Check offline status
      if (isOffline) {
        log('STEP 2: Offline mode');
        _hasLoadedConversations = true;
        _isLoadingConversations = false;
        _isLoadingMore = false;

        if (_conversations.isNotEmpty) {
          clearError();
          safeNotify();
          return;
        }

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      // STEP 3: Fetch from API
      log('STEP 3: Fetching from API');
      final response = await apiService.getChatbotConversations(
        page: _currentPage,
      );

      if (response.success) {
        final newConversations = response.data ?? [];

        if (forceRefresh) {
          _conversations = newConversations;
        } else {
          final existingIds = _conversations.map((c) => c.id).toSet();
          final uniqueNew = newConversations
              .where((c) => !existingIds.contains(c.id))
              .toList();
          _conversations.addAll(uniqueNew);
        }

        _hasMoreConversations = newConversations.length == 20;

        if (_hasMoreConversations) {
          _currentPage++;
        }

        _hasLoadedConversations = true;
        _hasInitialData = true;

        await _saveToCache();
        log('✅ Loaded ${newConversations.length} conversations from API');
      } else {
        if (_conversations.isNotEmpty) {
          clearError();
          log('⚠️ API refresh failed, keeping cached conversations');
          return;
        }
        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      if (_conversations.isNotEmpty) {
        clearError();
      } else {
        setError(getUserFriendlyErrorMessage('Failed to load conversations'));
      }
      log('Error loading conversations: $e');

      _hasLoadedConversations = true;

      if (isManualRefresh && _conversations.isEmpty) {
        rethrow;
      }
    } finally {
      _isLoadingConversations = false;
      _isLoadingMore = false;
      safeNotify();
    }
  }

  Future<void> _refreshConversationsInBackground() async {
    if (isOffline) return;

    if (_lastBackgroundRefreshConversations != null &&
        DateTime.now().difference(_lastBackgroundRefreshConversations!) <
            _minBackgroundInterval) {
      log('⏱️ Conversations background refresh rate limited');
      return;
    }
    _lastBackgroundRefreshConversations = DateTime.now();

    try {
      final response = await apiService.getChatbotConversations();
      if (response.success) {
        final freshConversations = response.data ?? [];

        final existingIds = _conversations.map((c) => c.id).toSet();
        for (final conv in freshConversations) {
          if (!existingIds.contains(conv.id)) {
            _conversations.insert(0, conv);
          } else {
            final index = _conversations.indexWhere((c) => c.id == conv.id);
            if (index != -1) {
              _conversations[index] = conv;
            }
          }
        }

        await _saveToCache();
        safeNotify();
        log('🔄 Background refresh for conversations complete');
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  // ===== LOAD MESSAGES =====
  Future<void> loadMessages(
    int conversationId, {
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadMessages() CALL #$callId for conversation $conversationId');

    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (_hasLoadedMessages &&
        !forceRefresh &&
        !isManualRefresh &&
        _messages.isNotEmpty) {
      log('✅ Already have messages, returning cached');
      safeNotify();
      return;
    }

    _isLoadingMessages = true;
    safeNotify();

    try {
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _messagesBox != null) {
          final messagesKey = 'user_${userId}_conv_${conversationId}_messages';
          final cachedMessages = _messagesBox!.get(messagesKey);

          if (cachedMessages != null && cachedMessages is List) {
            final List<ChatbotMessage> messages = [];
            for (final item in cachedMessages) {
              if (item is ChatbotMessage) {
                messages.add(item);
              } else if (item is Map<String, dynamic>) {
                messages.add(ChatbotMessage.fromJson(item));
              }
            }
            if (messages.isNotEmpty) {
              _messages = messages;
              _hasLoadedMessages = true;
              _hasInitialData = true;
              _isLoadingMessages = false;

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

              log('✅ Loaded ${_messages.length} messages from Hive for conversation $conversationId');

              if (!isOffline && !isManualRefresh) {
                unawaited(_refreshMessagesInBackground(conversationId));
              }
              return;
            }
          }
        }
      }

      if (isOffline) {
        log('STEP 2: Offline mode');
        _hasLoadedMessages = true;
        _isLoadingMessages = false;

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }
        return;
      }

      log('STEP 3: Fetching from API');
      final response =
          await apiService.getChatbotConversationMessages(conversationId);

      if (response.success) {
        _messages = response.data ?? [];
        _hasLoadedMessages = true;
        _hasInitialData = true;

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

        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _messagesBox != null) {
          final messagesKey = 'user_${userId}_conv_${conversationId}_messages';
          await _messagesBox!.put(messagesKey, _messages);
        }

        await _saveToCache();
        log('✅ Loaded ${_messages.length} messages from API');
      } else {
        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      setError(getUserFriendlyErrorMessage('Failed to load messages'));
      log('Error loading messages: $e');

      _hasLoadedMessages = true;

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      _isLoadingMessages = false;
      safeNotify();
    }
  }

  Future<void> _refreshMessagesInBackground(int conversationId) async {
    if (isOffline) return;

    if (_lastBackgroundRefreshMessages[conversationId] != null &&
        DateTime.now()
                .difference(_lastBackgroundRefreshMessages[conversationId]!) <
            _minBackgroundInterval) {
      log('⏱️ Messages background refresh rate limited for conversation $conversationId');
      return;
    }
    _lastBackgroundRefreshMessages[conversationId] = DateTime.now();

    try {
      final response =
          await apiService.getChatbotConversationMessages(conversationId);
      if (response.success) {
        final freshMessages = response.data ?? [];

        if (freshMessages.length != _messages.length) {
          _messages = freshMessages;

          final userId = await UserSession().getCurrentUserId();
          if (userId != null && _messagesBox != null) {
            final messagesKey =
                'user_${userId}_conv_${conversationId}_messages';
            await _messagesBox!.put(messagesKey, _messages);
          }

          safeNotify();
          log('🔄 Background refresh for messages complete');
        }
      }
    } catch (e) {
      log('Background refresh error: $e');
    }
  }

  // ===== SEND MESSAGE =====
  Future<ApiResponse<Map<String, dynamic>>> sendMessage(
    String message, {
    int? conversationId,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('sendMessage() CALL #$callId');

    if (message.trim().isEmpty) {
      return ApiResponse.error(message: 'Message cannot be empty');
    }

    if (!hasMessagesLeft && !isOffline) {
      return ApiResponse.error(
        message: 'Daily message limit reached. Please try again tomorrow.',
      );
    }

    final tempUserMessage = ChatbotMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: message,
      timestamp: DateTime.now(),
    );
    _messages.add(tempUserMessage);
    safeNotify();

    try {
      if (isOffline) {
        log('📝 Offline - queuing message');
        await _queueMessageOffline(message, conversationId);
        return ApiResponse.queued(
          message: 'Message saved offline. Will send when online.',
        );
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

      final response = await apiService.sendChatbotMessage(
        message,
        conversationId: conversationId,
        history: history,
      );

      if (response.success && response.data != null) {
        final aiMessage = ChatbotMessage(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          role: 'assistant',
          content: response.data!['reply'] as String,
          timestamp: DateTime.now(),
        );
        _messages.add(aiMessage);

        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _messagesBox != null) {
          final convId = response.data!['conversation_id'] ?? conversationId;
          if (convId != null) {
            final messagesKey = 'user_${userId}_conv_${convId}_messages';
            await _messagesBox!.put(messagesKey, _messages);
          }
        }

        final decremented = _remainingMessages > 0 ? _remainingMessages - 1 : 0;
        if (response.data!.containsKey('remaining')) {
          final int serverRemaining =
              Parsers.parseInt(response.data!['remaining'])
                  .clamp(0, _dailyLimit);
          _remainingMessages =
              serverRemaining < decremented ? serverRemaining : decremented;
        } else {
          _remainingMessages = decremented;
        }
        _usageDayKey = _todayKey();

        if (conversationId == null &&
            response.data!['conversation_id'] != null) {
          unawaited(loadConversations(forceRefresh: true));
        }

        await _saveToCache();
        log('✅ Message sent successfully');

        return response;
      } else {
        _messages.remove(tempUserMessage);
        return ApiResponse.error(message: response.message);
      }
    } catch (e) {
      _messages.remove(tempUserMessage);
      setError(getUserFriendlyErrorMessage(e));
      log('❌ Error sending message: $e');

      return ApiResponse.error(message: getUserFriendlyErrorMessage(e));
    } finally {
      safeNotify();
    }
  }

  Future<void> _queueMessageOffline(String message, int? conversationId) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null) return;

      offlineQueueManager.addItem(
        type: AppConstants.queueActionSendChatMessage,
        data: {
          'message': message,
          'conversation_id': conversationId,
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      log('📝 Queued message for offline sync');
    } catch (e) {
      log('Error queueing message: $e');
    }
  }

  // ===== RENAME CONVERSATION =====
  Future<bool> renameConversation(int conversationId, String title) async {
    log('renameConversation($conversationId, $title)');

    try {
      if (isOffline) {
        log('❌ Offline - cannot rename');
        return false;
      }

      final response =
          await apiService.renameChatbotConversation(conversationId, title);

      if (response.success) {
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
        safeNotify();
        log('✅ Conversation renamed successfully');
        return true;
      }
      return false;
    } catch (e) {
      log('Error renaming conversation: $e');
      return false;
    }
  }

  // ===== DELETE CONVERSATION =====
  Future<bool> deleteConversation(int conversationId) async {
    log('deleteConversation($conversationId)');

    try {
      if (isOffline) {
        log('❌ Offline - cannot delete');
        return false;
      }

      final response =
          await apiService.deleteChatbotConversation(conversationId);

      if (response.success) {
        _conversations.removeWhere((c) => c.id == conversationId);

        if (_currentConversation?.id == conversationId) {
          _currentConversation = null;
          _messages.clear();
          _hasLoadedMessages = false;

          final userId = await UserSession().getCurrentUserId();
          if (userId != null && _messagesBox != null) {
            final messagesKey =
                'user_${userId}_conv_${conversationId}_messages';
            await _messagesBox!.delete(messagesKey);
          }
        }

        await _saveToCache();
        safeNotify();
        log('✅ Conversation deleted successfully');
        return true;
      }
      return false;
    } catch (e) {
      log('Error deleting conversation: $e');
      return false;
    }
  }

  void clearCurrentConversation() {
    log('clearCurrentConversation()');
    _messages.clear();
    _currentConversation = null;
    _hasLoadedMessages = false;
    safeNotify();
    _saveToCache();
  }

  Future<void> loadMoreConversations() async {
    if (!_hasMoreConversations || _isLoadingMore) return;
    await loadConversations();
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing chatbot');
    if (_hasLoadedConversations) {
      await loadConversations(forceRefresh: true);
    }
    await loadUsageStats();
  }

  @override
  void dispose() {
    _messagesBox?.close();
    _conversationsBox?.close();
    _usageBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
