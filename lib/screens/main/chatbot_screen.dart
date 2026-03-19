// lib/screens/main/chatbot_screen.dart
// COMPLETE FIXED VERSION - NULL SAFETY IN INITSTATE

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import '../../models/chatbot_model.dart';
import '../../providers/chatbot_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/offline_queue_manager.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_shimmer.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';

class ChatbotScreen extends StatefulWidget {
  final int? conversationId;

  const ChatbotScreen({super.key, this.conversationId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with
        WidgetsBindingObserver,
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RefreshController _refreshController = RefreshController();

  bool _isSending = false;
  bool _showConversationList = false;
  bool _isRefreshing = false;
  String _greeting = '';
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isOffline = false;
  int _pendingCount = 0;

  StreamSubscription? _connectivitySubscription;
  bool _isMounted = false; // ✅ Track mounted state manually

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    _slideController = AnimationController(
      vsync: this,
      duration: AppThemes.animationMedium,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // ✅ DON'T access context here - use post frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _initialize();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false; // ✅ Mark as unmounted immediately
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _slideController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (!_isMounted) return;

    await _checkConnectivity();
    _setupConnectivityListener();
    _setGreeting();
    _setupScreenSize();
    _scrollToBottom();
  }

  void _setupConnectivityListener() {
    if (!_isMounted) return;

    // ✅ Safe to access context now (after first frame)
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (!_isMounted) return;

      setState(() {
        _isOffline = !isOnline;
        final queueManager = context.read<OfflineQueueManager>();
        _pendingCount = queueManager.pendingCount;
      });
    });
  }

  Future<void> _checkConnectivity() async {
    if (!_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    await connectivityService.checkConnectivity();
    if (!_isMounted) return;

    setState(() {
      _isOffline = !connectivityService.isOnline;
      final queueManager = context.read<OfflineQueueManager>();
      _pendingCount = queueManager.pendingCount;
    });
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  void _setupScreenSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted) return;
      if (ScreenSize.isTablet(context) || ScreenSize.isDesktop(context)) {
        setState(() => _showConversationList = true);
        _slideController.forward();
      } else {
        setState(() => _showConversationList = false);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing || !_isMounted) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      _refreshController.refreshFailed();
      if (_isMounted) {
        SnackbarService().showOffline(context, action: 'refresh');
      }
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      final chatbotProvider = context.read<ChatbotProvider>();
      await chatbotProvider.loadConversations(
        forceRefresh: true,
        isManualRefresh: true,
      );
      if (!_isMounted) return;

      if (widget.conversationId != null) {
        await chatbotProvider.loadMessages(
          widget.conversationId!,
          forceRefresh: true,
          isManualRefresh: true,
        );
      } else if (chatbotProvider.currentConversation != null) {
        await chatbotProvider.loadMessages(
          chatbotProvider.currentConversation!.id,
          forceRefresh: true,
          isManualRefresh: true,
        );
      }

      if (!_isMounted) return;

      setState(() => _isOffline = false);
      SnackbarService().showSuccess(context, 'Chat updated');
      _refreshController.refreshCompleted();
    } catch (e) {
      if (_isMounted) {
        setState(() => _isOffline = true);
        SnackbarService().showError(context, 'Refresh failed');
      }
      _refreshController.refreshFailed();
    } finally {
      if (_isMounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending || !_isMounted) return;

    final chatbotProvider = context.read<ChatbotProvider>();

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final result = await chatbotProvider.sendMessage(
        message,
        conversationId:
            widget.conversationId ?? chatbotProvider.currentConversation?.id,
      );

      if (!_isMounted) return;

      if (result.success) {
        _scrollToBottom();
        if (result.data != null &&
            result.data!['conversationId'] != null &&
            widget.conversationId == null) {
          await GoRouter.of(
            context,
          ).replace('/chatbot?conv=${result.data!['conversationId']}');
        }
      } else {
        SnackbarService().showError(
          context,
          result.message,
        );
      }
    } catch (e) {
      if (_isMounted) {
        SnackbarService().showError(context, getUserFriendlyErrorMessage(e));
      }
    } finally {
      if (_isMounted) setState(() => _isSending = false);
    }

    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final chatbotProvider = Provider.of<ChatbotProvider>(context);
    final bool isLoading = chatbotProvider.isLoadingConversations &&
        !chatbotProvider.hasInitialData;

    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: 'AI Tutor',
          subtitle: 'Loading...',
          showOfflineIndicator: _isOffline,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppColors.telegramBlue),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading conversations...',
                style: AppTextStyles.bodyMedium(context),
              ),
            ],
          ),
        ),
      );
    }

    if (_isOffline &&
        chatbotProvider.conversations.isEmpty &&
        chatbotProvider.messages.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: const CustomAppBar(
          title: 'AI Tutor',
          subtitle: 'Offline Mode',
          showOfflineIndicator: true,
        ),
        body: Center(
          child: AppEmptyState.offline(
            dataType: 'chat',
            message: 'You are offline. Messages will be queued when online.',
            onRetry: _manualRefresh,
            pendingCount: _pendingCount,
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getBackground(context),
      drawer: ScreenSize.isMobile(context)
          ? Drawer(
              width: ResponsiveValues.mobileDrawerWidth(context),
              backgroundColor: Colors.transparent,
              child: AppCard.glass(
                child: _buildConversationList(chatbotProvider),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CustomAppBar(
                title: chatbotProvider.currentConversation?.title ?? 'AI Tutor',
                subtitle: _isOffline ? 'Offline Mode' : _greeting,
                leading: ScreenSize.isMobile(context)
                    ? IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: AppColors.getTextPrimary(context),
                        ),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      )
                    : null,
                customTrailing: _buildMessageCounter(chatbotProvider),
                showOfflineIndicator: _isOffline,
              ),
            ),
            if (_isOffline && _pendingCount > 0)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.info.withValues(alpha: 0.2),
                        AppColors.info.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.info,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$_pendingCount offline message${_pendingCount > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverFillRemaining(
              child: Row(
                children: [
                  if ((ScreenSize.isDesktop(context) ||
                          ScreenSize.isTablet(context)) &&
                      _showConversationList)
                    Container(
                      width: ScreenSize.isTablet(context)
                          ? ResponsiveValues.tabletSidebarWidth(context)
                          : ResponsiveValues.desktopSidebarWidth(context),
                      margin: const EdgeInsets.only(right: 8),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: AppCard.glass(
                          child: _buildConversationList(chatbotProvider),
                        ),
                      ),
                    ),
                  Expanded(child: _buildChatArea(chatbotProvider)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildInputArea(chatbotProvider),
    );
  }

  Widget _buildConversationList(ChatbotProvider provider) {
    if (provider.isLoadingConversations && provider.conversations.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppShimmer(type: ShimmerType.textLine, customHeight: 60),
        ),
      );
    }

    if (provider.conversations.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.chat_outlined,
          title: 'No Conversations',
          message: 'Start a new chat to begin!',
        ),
      );
    }

    return Column(
      children: [
        AppCard.glass(
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 8,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Conversations',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_comment_outlined,
                    color: AppColors.telegramBlue,
                  ),
                  onPressed: _isOffline ? null : _showNewChatDialog,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: provider.conversations.length,
            itemBuilder: (context, index) {
              final conv = provider.conversations[index];
              final isSelected = provider.currentConversation?.id == conv.id;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? AppColors.telegramBlue
                      : AppColors.getSurface(context),
                  child: Icon(
                    Icons.chat_outlined,
                    color: isSelected ? Colors.white : AppColors.telegramBlue,
                  ),
                ),
                title: Text(
                  conv.title,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: conv.lastMessage != null
                    ? Text(
                        conv.lastMessage!.replaceAll('*', ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text('${conv.messageCount} messages'),
                onTap: () {
                  if (conv.id != provider.currentConversation?.id) {
                    provider.loadMessages(conv.id);
                    GoRouter.of(context).go('/chatbot?conv=${conv.id}');
                  }
                  if (ScreenSize.isMobile(context)) {
                    Navigator.pop(context);
                  }
                },
                trailing: PopupMenuButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: isSelected ? AppColors.telegramBlue : null,
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.telegramRed),
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'rename') {
                      _showRenameDialog(context, conv);
                    } else if (value == 'delete') {
                      _showDeleteDialog(context, conv);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, ChatbotConversation conv) {
    final controller = TextEditingController(text: conv.title);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter new title'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final success = await context
                    .read<ChatbotProvider>()
                    .renameConversation(conv.id, controller.text.trim());
                if (success && mounted) {
                  SnackbarService().showSuccess(
                    context,
                    'Conversation renamed',
                  );
                }
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatbotConversation conv) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: Text('Are you sure you want to delete "${conv.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final success = await context
                  .read<ChatbotProvider>()
                  .deleteConversation(conv.id);
              if (success && mounted) {
                SnackbarService().showSuccess(context, 'Conversation deleted');
              }
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start New Chat'),
        content: const Text(
          'This will clear the current conversation and start fresh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatbotProvider>().clearCurrentConversation();
              GoRouter.of(context).go('/chatbot');
            },
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCounter(ChatbotProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _isOffline
            ? AppColors.warning.withValues(alpha: 0.1)
            : (provider.remainingMessages > 0
                ? AppColors.telegramGreen.withValues(alpha: 0.1)
                : AppColors.telegramRed.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.message,
            size: 16,
            color: _isOffline
                ? AppColors.warning
                : (provider.remainingMessages > 0
                    ? AppColors.telegramGreen
                    : AppColors.telegramRed),
          ),
          const SizedBox(width: 4),
          Text(
            _isOffline
                ? 'Offline'
                : '${provider.remainingMessages}/${provider.dailyLimit}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _isOffline
                  ? AppColors.warning
                  : (provider.remainingMessages > 0
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatbotProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getCard(context).withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: _isOffline
                        ? 'Offline - messages queued'
                        : (provider.hasMessagesLeft
                            ? 'Ask about any subject...'
                            : 'Daily limit reached'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              if (_isSending)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                IconButton(
                  icon: Icon(
                    _isOffline ? Icons.schedule_rounded : Icons.send,
                    color:
                        _isOffline ? AppColors.warning : AppColors.telegramBlue,
                  ),
                  onPressed: _sendMessage,
                  iconSize: 28,
                ),
            ],
          ),
          if (_isOffline && _pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$_pendingCount message${_pendingCount > 1 ? 's' : ''} queued',
                style: const TextStyle(color: AppColors.info),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatArea(ChatbotProvider provider) {
    if (provider.isLoadingMessages && provider.messages.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppShimmer(type: ShimmerType.textLine, customHeight: 60),
        ),
      );
    }

    if (provider.errorMessage != null && provider.messages.isEmpty) {
      return Center(
        child: AppEmptyState.error(
          title: 'Error',
          message: provider.errorMessage!,
          onRetry: () => provider.clearError(),
        ),
      );
    }

    if (provider.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AppEmptyState(
            icon: Icons.smart_toy,
            title: 'AI Learning Assistant',
            message: _isOffline
                ? 'You are offline. Messages will be queued and sent when online.'
                : 'Ask me about mathematics, sciences, Amharic, Ethiopian history, or get study tips. You have ${provider.remainingMessages}/${provider.dailyLimit} messages left today.',
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: provider.messages.length,
      itemBuilder: (context, index) {
        final message = provider.messages[index];
        final isUser = message.isUser;

        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.only(
              bottom: 8,
              left: isUser ? 50 : 0,
              right: isUser ? 0 : 50,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isUser ? AppColors.telegramBlue : AppColors.getCard(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.content.replaceAll('*', ''),
                  style: isUser ? const TextStyle(color: Colors.white) : null,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
