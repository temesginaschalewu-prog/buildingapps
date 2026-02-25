import 'dart:async';
import 'package:familyacademyclient/models/chatbot_model.dart';
import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:familyacademyclient/utils/responsive.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:badges/badges.dart' as badges;
import 'package:familyacademyclient/themes/app_themes.dart';
import '../../providers/chatbot_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_widget.dart' as custom_error;

class ChatbotScreen extends StatefulWidget {
  final int? conversationId;

  const ChatbotScreen({super.key, this.conversationId});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSending = false;
  int _unreadNotifications = 0;
  bool _showConversationList = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _slideController = AnimationController(
      vsync: this,
      duration: AppThemes.animationDurationMedium,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
      _loadNotifications();
      _setupScreenSize();
    });
  }

  void _setupScreenSize() {
    if (ScreenSize.isDesktop(context) || ScreenSize.isTablet(context)) {
      setState(() => _showConversationList = true);
      _slideController.forward();
    }
  }

  Future<void> _initializeChat() async {
    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);

    if (widget.conversationId != null) {
      await chatbotProvider.loadMessages(widget.conversationId!);
    }

    _scrollToBottom();
  }

  Future<void> _loadNotifications() async {
    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.loadNotifications();
      if (mounted) {
        setState(() {
          _unreadNotifications = notificationProvider.unreadCount;
        });
      }
    } catch (e) {
      debugLog('ChatbotScreen', 'Error loading notifications: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppThemes.animationDurationMedium,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);

    if (!chatbotProvider.hasMessagesLeft) {
      _showLimitReachedDialog();
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    final result = await chatbotProvider.sendMessage(
      message,
      conversationId:
          widget.conversationId ?? chatbotProvider.currentConversation?.id,
    );

    setState(() => _isSending = false);

    if (result['success'] == true) {
      _scrollToBottom();

      // If this is a new conversation, update the route
      if (result['conversationId'] != null &&
          widget.conversationId == null &&
          chatbotProvider.currentConversation == null) {
        GoRouter.of(context)
            .replace('/chatbot?conv=${result['conversationId']}');
      }
    } else {
      showTopSnackBar(context, result['error'] ?? 'Failed to send message',
          isError: true);
    }

    _focusNode.requestFocus();
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Daily Limit Reached',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        content: Text(
          'You\'ve used all your daily messages (${Provider.of<ChatbotProvider>(context).dailyLimit}). '
          'The limit resets at midnight. '
          '\n\nYou can still review previous conversations.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.telegramBlue,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        title: Text(
          'Start New Chat',
          style: AppTextStyles.titleMedium,
        ),
        content: Text(
          'This will clear the current conversation and start fresh.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatbotProvider>(context, listen: false)
                  .clearCurrentConversation();
              GoRouter.of(context).go('/chatbot');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.telegramBlue,
            ),
            child: const Text('Start New'),
          ),
        ],
      ),
    );
  }

  void _showConversationsDrawer() {
    if (ScreenSize.isMobile(context)) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      setState(() {
        _showConversationList = !_showConversationList;
        if (_showConversationList) {
          _slideController.forward();
        } else {
          _slideController.reverse();
        }
      });
    }
  }

  Widget _buildMessageBubble(ChatbotMessage message) {
    final isUser = message.isUser;
    final timeStr =
        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: AppThemes.spacingL,
        left: isUser ? AppThemes.spacingXXL : AppThemes.spacingM,
        right: isUser ? AppThemes.spacingM : AppThemes.spacingXXL,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: AppThemes.spacingM),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.blueGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.smart_toy,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: ScreenSize.responsiveValue(
                      context: context,
                      mobile: MediaQuery.of(context).size.width * 0.75,
                      tablet: MediaQuery.of(context).size.width * 0.6,
                      desktop: 500,
                    ),
                  ),
                  padding: const EdgeInsets.all(AppThemes.spacingM),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.telegramBlue
                        : AppColors.getCard(context),
                    borderRadius: BorderRadius.only(
                      topLeft:
                          const Radius.circular(AppThemes.borderRadiusLarge),
                      topRight:
                          const Radius.circular(AppThemes.borderRadiusLarge),
                      bottomLeft: isUser
                          ? const Radius.circular(AppThemes.borderRadiusLarge)
                          : const Radius.circular(AppThemes.borderRadiusSmall),
                      bottomRight: isUser
                          ? const Radius.circular(AppThemes.borderRadiusSmall)
                          : const Radius.circular(AppThemes.borderRadiusLarge),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isUser
                              ? Colors.white
                              : AppColors.getTextPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          timeStr,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isUser
                                ? Colors.white.withOpacity(0.7)
                                : AppColors.getTextSecondary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: AppThemes.spacingM),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.purpleGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.person,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return Consumer<ChatbotProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingConversations && provider.conversations.isEmpty) {
          return const Center(
            child: LoadingIndicator(type: LoadingType.circular),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppThemes.spacingL),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Conversations',
                      style: AppTextStyles.titleSmall,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    onPressed: _showNewChatDialog,
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.conversations.isEmpty
                  ? EmptyState(
                      icon: Icons.chat_outlined,
                      title: 'No Conversations',
                      message: 'Start a new chat to begin learning!',
                    )
                  : ListView.builder(
                      itemCount: provider.conversations.length,
                      itemBuilder: (context, index) {
                        final conv = provider.conversations[index];
                        final isSelected =
                            provider.currentConversation?.id == conv.id;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: isSelected
                                ? AppColors.telegramBlue
                                : AppColors.getSurface(context),
                            child: Icon(
                              Icons.chat_outlined,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.getTextPrimary(context),
                              size: 20,
                            ),
                          ),
                          title: Text(
                            conv.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: conv.lastMessage != null
                              ? Text(
                                  conv.lastMessage!,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Text(
                                  '${conv.messageCount} messages',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                          selected: isSelected,
                          onTap: () {
                            if (conv.id != provider.currentConversation?.id) {
                              provider.loadMessages(conv.id);
                              GoRouter.of(context)
                                  .go('/chatbot?conv=${conv.id}');
                            }
                            if (ScreenSize.isMobile(context)) {
                              Navigator.pop(context);
                            }
                          },
                          trailing: PopupMenuButton(
                            icon: Icon(
                              Icons.more_vert,
                              color: AppColors.getTextPrimary(context),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'rename',
                                child: const Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: AppColors.telegramRed,
                                  ),
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
      },
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
          decoration: const InputDecoration(
            hintText: 'Enter new title',
            border: OutlineInputBorder(),
          ),
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
                final success =
                    await Provider.of<ChatbotProvider>(context, listen: false)
                        .renameConversation(conv.id, controller.text.trim());
                if (success && mounted) {
                  showTopSnackBar(context, 'Conversation renamed');
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
              final success =
                  await Provider.of<ChatbotProvider>(context, listen: false)
                      .deleteConversation(conv.id);
              if (success && mounted) {
                showTopSnackBar(context, 'Conversation deleted');
                if (conv.id ==
                    Provider.of<ChatbotProvider>(context, listen: false)
                        .currentConversation
                        ?.id) {
                  GoRouter.of(context).go('/chatbot');
                }
              }
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.telegramRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickQuestions() {
    final quickQuestions = [
      'Explain algebra equations',
      'How does photosynthesis work?',
      'Tips for exam preparation',
      'Ethiopian history timeline',
      'Help with English grammar',
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: AppThemes.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppThemes.spacingS),
            child: Text(
              'Quick Questions:',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickQuestions.map((question) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppThemes.spacingS),
                  child: GestureDetector(
                    onTap: () {
                      _messageController.text = question;
                      _sendMessage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppThemes.spacingM,
                        vertical: AppThemes.spacingS,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context),
                        borderRadius:
                            BorderRadius.circular(AppThemes.borderRadiusFull),
                        border: Border.all(
                          color: AppColors.getTextSecondary(context)
                              .withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        question,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCounter(ChatbotProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemes.spacingM,
        vertical: AppThemes.spacingXS,
      ),
      decoration: BoxDecoration(
        color: provider.remainingMessages > 0
            ? AppColors.getStatusBackground('active', context)
            : AppColors.getStatusBackground('expired', context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
        border: Border.all(
          color: provider.remainingMessages > 0
              ? AppColors.getStatusColor('active', context)
              : AppColors.getStatusColor('expired', context),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.message,
            size: 14,
            color: provider.remainingMessages > 0
                ? AppColors.getStatusColor('active', context)
                : AppColors.getStatusColor('expired', context),
          ),
          const SizedBox(width: 4),
          Text(
            '${provider.remainingMessages}/${provider.dailyLimit}',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: provider.remainingMessages > 0
                  ? AppColors.getStatusColor('active', context)
                  : AppColors.getStatusColor('expired', context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ChatbotProvider provider) {
    final hasMessagesLeft = provider.hasMessagesLeft;
    final isEnabled = hasMessagesLeft && !_isSending;

    return Container(
      padding: const EdgeInsets.all(AppThemes.spacingL),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border(
          top: BorderSide(
            color: AppColors.getCard(context),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickQuestions(),
          const SizedBox(height: AppThemes.spacingL),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppThemes.spacingM),
                  decoration: BoxDecoration(
                    color: AppColors.getCard(context),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusLarge),
                  ),
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: hasMessagesLeft
                          ? 'Ask about any subject...'
                          : 'Daily limit reached',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: isEnabled
                            ? AppColors.getTextSecondary(context)
                            : AppColors.getTextSecondary(context)
                                .withOpacity(0.4),
                      ),
                      border: InputBorder.none,
                    ),
                    maxLines: 3,
                    minLines: 1,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: isEnabled,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppThemes.spacingS),
              if (_isSending)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isEnabled
                          ? AppColors.blueGradient
                          : [
                              AppColors.getTextSecondary(context)
                                  .withOpacity(0.2),
                              AppColors.getTextSecondary(context)
                                  .withOpacity(0.1),
                            ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isEnabled ? _sendMessage : null,
                    icon: Icon(
                      Icons.send,
                      color: isEnabled
                          ? Colors.white
                          : AppColors.getTextSecondary(context)
                              .withOpacity(0.4),
                      size: 20,
                    ),
                    splashRadius: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Consumer<ChatbotProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingMessages && provider.messages.isEmpty) {
          return const Center(
            child: LoadingIndicator(type: LoadingType.circular),
          );
        }

        if (provider.error != null) {
          return Center(
            child: custom_error.ErrorWidget(
              title: 'Error',
              message: provider.error!,
              onRetry: () => provider.clearError(),
            ),
          );
        }

        if (provider.messages.isEmpty) {
          return EmptyState(
            icon: Icons.smart_toy,
            title: 'Start Learning Conversation',
            message:
                'Ask questions about any subject or request study help. You have ${provider.remainingMessages}/${provider.dailyLimit} messages left today.',
            centerContent: true,
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppThemes.spacingL),
          itemCount: provider.messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(provider.messages[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatbotProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.getBackground(context),
          drawer: ScreenSize.isMobile(context)
              ? Drawer(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: _buildConversationList(),
                )
              : null,
          body: Row(
            children: [
              if (ScreenSize.isDesktop(context) && _showConversationList)
                AnimatedContainer(
                  duration: AppThemes.animationDurationMedium,
                  width: 320,
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    border: Border(
                      right: BorderSide(
                        color: AppColors.getCard(context),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildConversationList(),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top,
                        left: AppThemes.spacingL,
                        right: AppThemes.spacingL,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.getBackground(context),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.getCard(context),
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: Row(
                          children: [
                            if (ScreenSize.isMobile(context) ||
                                !_showConversationList)
                              IconButton(
                                icon: const Icon(Icons.menu),
                                onPressed: _showConversationsDrawer,
                                tooltip: 'Conversations',
                              ),
                            if (ScreenSize.isDesktop(context) &&
                                !_showConversationList)
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _showConversationsDrawer,
                                tooltip: 'Show conversations',
                              ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    provider.currentConversation?.title ??
                                        'AI Tutor',
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Your personal learning assistant',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color:
                                          AppColors.getTextSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildMessageCounter(provider),
                            const SizedBox(width: AppThemes.spacingM),
                            Consumer<ThemeProvider>(
                              builder: (context, themeProvider, child) {
                                return IconButton(
                                  icon: Icon(
                                    themeProvider.themeMode == ThemeMode.dark
                                        ? Icons.light_mode_outlined
                                        : Icons.dark_mode_outlined,
                                  ),
                                  onPressed: themeProvider.toggleTheme,
                                  tooltip: 'Toggle theme',
                                );
                              },
                            ),
                            const SizedBox(width: AppThemes.spacingS),
                            GestureDetector(
                              onTap: () =>
                                  GoRouter.of(context).push('/notifications'),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.getSurface(context),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: _unreadNotifications > 0
                                      ? badges.Badge(
                                          position: badges.BadgePosition.topEnd(
                                              top: -4, end: -4),
                                          badgeContent: Text(
                                            _unreadNotifications > 9
                                                ? '9+'
                                                : _unreadNotifications
                                                    .toString(),
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          badgeStyle: badges.BadgeStyle(
                                            badgeColor: AppColors.telegramRed,
                                            padding: const EdgeInsets.all(4),
                                            borderRadius: BorderRadius.circular(
                                              AppThemes.borderRadiusFull,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.notifications_outlined,
                                            size: 22,
                                            color: AppColors.getTextPrimary(
                                                context),
                                          ),
                                        )
                                      : Icon(
                                          Icons.notifications_outlined,
                                          size: 22,
                                          color:
                                              AppColors.getTextPrimary(context),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildChatArea(),
                    ),
                    _buildInputArea(provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
