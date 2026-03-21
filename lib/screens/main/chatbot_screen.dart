// lib/screens/main/chatbot_screen.dart
// PRODUCTION STANDARD - WITH PULL-TO-REFRESH & PROPER LOADING

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import '../../models/chatbot_model.dart';
import '../../providers/chatbot_provider.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../services/snackbar_service.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../widgets/common/app_card.dart';
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
    with BaseScreenMixin<ChatbotScreen>, TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final RefreshController _refreshController = RefreshController();

  bool _isSending = false;
  bool _showConversationList = false;
  String _greeting = '';
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _initialLoadDone = false;

  late ChatbotProvider _provider;

  @override
  String get screenTitle => _provider.currentConversation?.title ?? 'AI Tutor';

  @override
  String? get screenSubtitle => _greeting;

  @override
  bool get isLoading =>
      (_provider.isLoadingConversations && !_provider.hasInitialData) ||
      (_provider.isLoadingMessages && !_initialLoadDone);

  @override
  bool get hasCachedData => _provider.hasInitialData;

  @override
  dynamic get errorMessage => _provider.errorMessage;

  // ✅ Shimmer type for chatbot
  @override
  ShimmerType get shimmerType => ShimmerType.textLine;

  @override
  int get shimmerItemCount => 5;

  @override
  Widget? get appBarLeading => ScreenSize.isMobile(context)
      ? IconButton(
          icon: Icon(Icons.menu, color: AppColors.getTextPrimary(context)),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        )
      : null;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      vsync: this,
      duration: AppThemes.animationMedium,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _setGreeting();
    _setupScreenSize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<ChatbotProvider>(context);

    _provider.addListener(_onProviderDataChanged);

    // Mark initial load as done after first data arrives
    if (_provider.hasInitialData) {
      _initialLoadDone = true;
    }
  }

  void _onProviderDataChanged() {
    if (mounted) {
      setState(() {
        if (_provider.hasInitialData) {
          _initialLoadDone = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _slideController.dispose();
    _refreshController.dispose();
    _provider.removeListener(_onProviderDataChanged);
    super.dispose();
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
      if (!isMounted) return;
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
      if (!isMounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ✅ Pull-to-refresh handler
  @override
  Future<void> onRefresh() async {
    try {
      await _provider.loadConversations(
          forceRefresh: true, isManualRefresh: true);
      _refreshController.refreshCompleted();
      setState(() => _initialLoadDone = true);
    } catch (e) {
      _refreshController.refreshFailed();
      rethrow;
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final result = await _provider.sendMessage(
        message,
        conversationId:
            widget.conversationId ?? _provider.currentConversation?.id,
      );

      if (!isMounted) return;

      if (result.success) {
        _scrollToBottom();
        if (result.data != null &&
            result.data!['conversationId'] != null &&
            widget.conversationId == null) {
          await GoRouter.of(context)
              .replace('/chatbot?conv=${result.data!['conversationId']}');
        }
        setState(() => _initialLoadDone = true);
      } else {
        SnackbarService().showError(context, result.message);
      }
    } catch (e) {
      if (isMounted) {
        SnackbarService().showError(context, getUserFriendlyErrorMessage(e));
      }
    } finally {
      if (isMounted) setState(() => _isSending = false);
    }

    _focusNode.requestFocus();
  }

  Widget _buildMessageCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isOffline
            ? AppColors.warning.withValues(alpha: 0.1)
            : (_provider.remainingMessages > 0
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
            color: isOffline
                ? AppColors.warning
                : (_provider.remainingMessages > 0
                    ? AppColors.telegramGreen
                    : AppColors.telegramRed),
          ),
          const SizedBox(width: 4),
          Text(
            isOffline
                ? 'Offline'
                : '${_provider.remainingMessages}/${_provider.dailyLimit}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isOffline
                  ? AppColors.warning
                  : (_provider.remainingMessages > 0
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    // ✅ Show shimmer only if loading AND no conversations AND not loaded yet
    if (_provider.isLoadingConversations &&
        _provider.conversations.isEmpty &&
        !_initialLoadDone) {
      return buildLoadingShimmer();
    }

    if (_provider.conversations.isEmpty) {
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
                  icon: const Icon(Icons.add_comment_outlined,
                      color: AppColors.telegramBlue),
                  onPressed: isOffline ? null : _showNewChatDialog,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _provider.conversations.length,
            itemBuilder: (context, index) {
              final conv = _provider.conversations[index];
              final isSelected = _provider.currentConversation?.id == conv.id;

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
                  if (conv.id != _provider.currentConversation?.id) {
                    _provider.loadMessages(conv.id);
                    GoRouter.of(context).go('/chatbot?conv=${conv.id}');
                    setState(() => _initialLoadDone = false);
                  }
                  if (ScreenSize.isMobile(context)) {
                    Navigator.pop(context);
                  }
                },
                trailing: PopupMenuButton(
                  icon: Icon(Icons.more_vert,
                      color: isSelected ? AppColors.telegramBlue : null),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'rename', child: Text('Rename')),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete',
                          style: TextStyle(color: AppColors.telegramRed)),
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
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final success = await _provider.renameConversation(
                    conv.id, controller.text.trim());
                if (success && mounted) {
                  SnackbarService()
                      .showSuccess(context, 'Conversation renamed');
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
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final success = await _provider.deleteConversation(conv.id);
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
            'This will clear the current conversation and start fresh.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _provider.clearCurrentConversation();
              GoRouter.of(context).go('/chatbot');
              setState(() => _initialLoadDone = false);
            },
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
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
                    hintText: isOffline
                        ? 'Offline - messages queued'
                        : (_provider.hasMessagesLeft
                            ? 'Ask about any subject...'
                            : 'Daily limit reached'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
                    isOffline ? Icons.schedule_rounded : Icons.send,
                    color:
                        isOffline ? AppColors.warning : AppColors.telegramBlue,
                  ),
                  onPressed: _sendMessage,
                  iconSize: 28,
                ),
            ],
          ),
          if (isOffline && pendingCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$pendingCount message${pendingCount > 1 ? 's' : ''} queued',
                style: const TextStyle(color: AppColors.info),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    final hasMessages = _provider.messages.isNotEmpty;

    // ✅ Show shimmer only if loading AND no messages AND not loaded yet
    if (_provider.isLoadingMessages && !hasMessages && !_initialLoadDone) {
      return buildLoadingShimmer();
    }

    // ✅ If we have messages, show them immediately
    if (hasMessages) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _provider.messages.length,
        itemBuilder: (context, index) {
          final message = _provider.messages[index];
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
                color: isUser
                    ? AppColors.telegramBlue
                    : AppColors.getCard(context),
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

    // ✅ Only show empty state if NOT loading and no messages
    if (!_provider.isLoadingMessages && !hasMessages) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: AppEmptyState(
            icon: Icons.smart_toy,
            title: 'AI Learning Assistant',
            message: isOffline
                ? 'You are offline. Messages will be queued and sent when online.'
                : 'Ask me about mathematics, sciences, Amharic, Ethiopian history, or get study tips. You have ${_provider.remainingMessages}/${_provider.dailyLimit} messages left today.',
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: AppEmptyState(
          icon: Icons.smart_toy,
          title: 'AI Learning Assistant',
          message: isOffline
              ? 'You are offline. Messages will be queued and sent when online.'
              : 'Ask me about mathematics, sciences, Amharic, Ethiopian history, or get study tips.',
        ),
      ),
    );
  }

  // ✅ BUILD CONTENT WITH PULL-TO-REFRESH
  @override
  Widget buildContent(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.telegramBlue,
      backgroundColor: AppColors.getSurface(context),
      child: Stack(
        children: [
          Row(
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
                    child: AppCard.glass(child: _buildConversationList()),
                  ),
                ),
              Expanded(child: _buildChatArea()),
            ],
          ),
          if (isOffline && pendingCount > 0)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.info.withValues(alpha: 0.2),
                        AppColors.info.withValues(alpha: 0.1)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$pendingCount offline message${pendingCount > 1 ? 's' : ''}',
                          style: const TextStyle(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getBackground(context),
      drawer: ScreenSize.isMobile(context)
          ? Drawer(
              width: ResponsiveValues.mobileDrawerWidth(context),
              backgroundColor: Colors.transparent,
              child: AppCard.glass(child: _buildConversationList()),
            )
          : null,
      body: buildScreen(
          content: buildContent(context),
          showAppBar: true,
          showRefreshIndicator: false), // RefreshIndicator is inside content
      bottomNavigationBar: _buildInputArea(),
    );
  }
}
