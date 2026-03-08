import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import '../../models/chatbot_model.dart';
import '../../providers/chatbot_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/connectivity_service.dart';
import '../../services/snackbar_service.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../widgets/common/app_bar.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_shimmer.dart';

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

  @override
  void initState() {
    super.initState();

    _slideController =
        AnimationController(vsync: this, duration: AppThemes.animationMedium);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setGreeting();
      _setupConnectivityListener();
      _initializeChat();
      _loadNotifications();
      _setupScreenSize();
      _getCurrentUserId();
      _checkPendingMessages();
    });
  }

  void _setupConnectivityListener() {
    final connectivityService = context.read<ConnectivityService>();
    _connectivitySubscription =
        connectivityService.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() {
          _isOffline = !isOnline;
          _pendingCount = connectivityService.pendingActionsCount;
        });
      }
    });
  }

  Future<void> _getCurrentUserId() async {
    Provider.of<AuthProvider>(context, listen: false);
  }

  Future<void> _checkPendingMessages() async {
    final connectivity = ConnectivityService();
    setState(() => _pendingCount = connectivity.pendingActionsCount);
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
      if (ScreenSize.isTablet(context) || ScreenSize.isDesktop(context)) {
        setState(() => _showConversationList = true);
        _slideController.forward();
      } else {
        setState(() => _showConversationList = false);
      }
    });
  }

  Future<void> _initializeChat() async {
    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);

    if (widget.conversationId != null) {
      await chatbotProvider.loadMessages(widget.conversationId!);
      if (!mounted) return;
    }

    _scrollToBottom();
  }

  Future<void> _loadNotifications() async {
    try {
      final notificationProvider =
          Provider.of<NotificationProvider>(context, listen: false);
      await notificationProvider.loadNotifications();
      if (!mounted) return;
    } catch (e) {
      debugLog('ChatbotScreen', 'Error loading notifications: $e');
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      setState(() {
        _isRefreshing = false;
        _isOffline = true;
      });
      _refreshController.refreshFailed();
      SnackbarService().showOffline(context, action: 'refresh');
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final chatbotProvider =
          Provider.of<ChatbotProvider>(context, listen: false);
      await chatbotProvider.loadConversations(forceRefresh: true);
      if (!mounted) return;

      if (widget.conversationId != null) {
        await chatbotProvider.loadMessages(widget.conversationId!,
            forceRefresh: true);
      }
      setState(() => _isOffline = false);
      SnackbarService().showSuccess(context, 'Chat updated');
    } catch (e) {
      setState(() => _isOffline = true);
      SnackbarService().showError(context, 'Failed to refresh');
    } finally {
      setState(() {
        _isRefreshing = false;
      });
      _refreshController.refreshCompleted();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setGreeting();
      _checkPendingMessages();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _slideController.dispose();
    _refreshController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    final connectivity = ConnectivityService();
    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);

    if (!connectivity.isOnline) {
      setState(() => _isSending = true);
      _messageController.clear();

      try {
        await chatbotProvider.sendMessage(
          message,
          conversationId:
              widget.conversationId ?? chatbotProvider.currentConversation?.id,
        );
        SnackbarService().showQueued(context, action: 'Message');
        _scrollToBottom();
        await _checkPendingMessages();
        if (!mounted) return;
      } catch (e) {
        SnackbarService().showError(context, 'Failed to queue message');
      } finally {
        setState(() => _isSending = false);
      }
      return;
    }

    if (!chatbotProvider.hasMessagesLeft) {
      _showLimitReachedDialog();
      return;
    }

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final result = await chatbotProvider.sendMessage(
        message,
        conversationId:
            widget.conversationId ?? chatbotProvider.currentConversation?.id,
      );

      if (result['success'] == true) {
        _scrollToBottom();

        if (result['conversationId'] != null &&
            widget.conversationId == null &&
            chatbotProvider.currentConversation == null) {
          await GoRouter.of(context)
              .replace('/chatbot?conv=${result['conversationId']}');
        }
      } else {
        SnackbarService()
            .showError(context, result['error'] ?? 'Failed to send message');
      }
    } catch (e) {
      SnackbarService().showError(context, formatErrorMessage(e));
    } finally {
      setState(() => _isSending = false);
    }

    _focusNode.requestFocus();
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXXL(context),
                  height: ResponsiveValues.iconSizeXXL(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramYellow.withValues(alpha: 0.2),
                        AppColors.telegramYellow.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_outline_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.telegramYellow),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Text(
                  'Daily Limit Reached',
                  style: AppTextStyles.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Text(
                  'You\'ve used all your daily messages (${Provider.of<ChatbotProvider>(context).dailyLimit}). The limit resets at midnight.\n\nYou can still review previous conversations.',
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                            gradient:
                                LinearGradient(colors: AppColors.blueGradient)),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                                vertical: ResponsiveValues.spacingM(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusMedium(context)),
                            ),
                          ),
                          child: const Text('OK'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXXL(context),
                  height: ResponsiveValues.iconSizeXXL(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chat_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.telegramBlue),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Text(
                  'Start New Chat',
                  style: AppTextStyles.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Text(
                  'This will clear the current conversation and start fresh.',
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context)),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                            gradient:
                                LinearGradient(colors: AppColors.blueGradient)),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Provider.of<ChatbotProvider>(context, listen: false)
                                .clearCurrentConversation();
                            GoRouter.of(context).go('/chatbot');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                                vertical: ResponsiveValues.spacingM(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusMedium(context)),
                            ),
                          ),
                          child: const Text('Start New'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSidebar() {
    setState(() {
      _showConversationList = !_showConversationList;
      if (_showConversationList) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    });
  }

  void _showConversationsDrawer() {
    if (ScreenSize.isMobile(context)) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      _toggleSidebar();
    }
  }

  Widget _buildMessageBubble(ChatbotMessage message) {
    final isUser = message.isUser;
    final timeStr =
        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveValues.spacingM(context),
        left: isUser
            ? ResponsiveValues.spacingXXL(context)
            : ResponsiveValues.spacingM(context),
        right: isUser
            ? ResponsiveValues.spacingM(context)
            : ResponsiveValues.spacingXXL(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding:
                  EdgeInsets.only(right: ResponsiveValues.spacingS(context)),
              child: Container(
                width: ResponsiveValues.iconSizeL(context),
                height: ResponsiveValues.iconSizeL(context),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.blueGradient),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.smart_toy,
                      size: ResponsiveValues.iconSizeXS(context),
                      color: Colors.white),
                ),
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: ResponsiveValues.chatBubbleMaxWidth(context)),
              child: Container(
                padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.telegramBlue
                      : AppColors.getCard(context),
                  borderRadius: BorderRadius.circular(
                      ResponsiveValues.radiusLarge(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: ResponsiveValues.spacingXS(context),
                      offset: Offset(0, ResponsiveValues.spacingXXS(context)),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      message.content.replaceAll('*', ''),
                      style: isUser
                          ? AppTextStyles.bodyMedium(context)
                              .copyWith(color: Colors.white)
                          : AppTextStyles.bodyMedium(context),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXS(context)),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        timeStr,
                        style: AppTextStyles.labelSmall(context).copyWith(
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isUser)
            Padding(
              padding:
                  EdgeInsets.only(left: ResponsiveValues.spacingS(context)),
              child: Container(
                width: ResponsiveValues.iconSizeL(context),
                height: ResponsiveValues.iconSizeL(context),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.purpleGradient),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(Icons.person,
                      size: ResponsiveValues.iconSizeXS(context),
                      color: Colors.white),
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
          return ListView.builder(
            padding: ResponsiveValues.screenPadding(context),
            itemCount: 5,
            itemBuilder: (context, index) => Padding(
              padding:
                  EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
              child: const AppShimmer(
                  type: ShimmerType.textLine, customHeight: 60),
            ),
          );
        }

        return Column(
          children: [
            AppCard.glass(
              child: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top +
                      ResponsiveValues.spacingL(context),
                  left: ResponsiveValues.spacingL(context),
                  right: ResponsiveValues.spacingL(context),
                  bottom: ResponsiveValues.spacingM(context),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Conversations',
                        style: AppTextStyles.titleSmall(context)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined,
                          color: AppColors.telegramBlue),
                      onPressed: _isOffline ? null : _showNewChatDialog,
                      tooltip: 'New Chat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (ScreenSize.isDesktop(context) ||
                        ScreenSize.isTablet(context))
                      IconButton(
                        icon: Icon(Icons.close,
                            color: AppColors.getTextSecondary(context)),
                        onPressed: _toggleSidebar,
                        tooltip: 'Close',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: provider.conversations.isEmpty
                  ? const AppEmptyState(
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

                        return Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: ResponsiveValues.spacingXS(context),
                            vertical: ResponsiveValues.conversationCardMargin(
                                context),
                          ),
                          child: AppCard.glass(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (conv.id !=
                                      provider.currentConversation?.id) {
                                    provider.loadMessages(conv.id);
                                    GoRouter.of(context)
                                        .go('/chatbot?conv=${conv.id}');
                                  }
                                  if (ScreenSize.isMobile(context)) {
                                    Navigator.pop(context);
                                  }
                                },
                                borderRadius: BorderRadius.circular(
                                    ResponsiveValues.conversationCardRadius(
                                        context)),
                                child: Padding(
                                  padding: EdgeInsets.all(
                                      ResponsiveValues.conversationCardPadding(
                                          context)),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: ResponsiveValues
                                            .conversationCardIconSize(context),
                                        height: ResponsiveValues
                                            .conversationCardIconSize(context),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors:
                                                      AppColors.blueGradient)
                                              : LinearGradient(
                                                  colors: [
                                                    AppColors.getSurface(
                                                            context)
                                                        .withValues(alpha: 0.3),
                                                    AppColors.getSurface(
                                                            context)
                                                        .withValues(alpha: 0.1),
                                                  ],
                                                ),
                                          borderRadius: BorderRadius.circular(
                                              ResponsiveValues.radiusSmall(
                                                  context)),
                                        ),
                                        child: Icon(
                                          Icons.chat_outlined,
                                          size: ResponsiveValues.iconSizeXS(
                                              context),
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.getTextPrimary(
                                                  context),
                                        ),
                                      ),
                                      SizedBox(
                                          width: ResponsiveValues.spacingS(
                                              context)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              conv.title,
                                              style: TextStyle(
                                                fontSize: ResponsiveValues
                                                    .conversationCardTitleSize(
                                                        context),
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: isSelected
                                                    ? AppColors.telegramBlue
                                                    : AppColors.getTextPrimary(
                                                        context),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (conv.lastMessage != null)
                                              Text(
                                                conv.lastMessage!
                                                    .replaceAll('*', ''),
                                                style: TextStyle(
                                                  fontSize: ResponsiveValues
                                                      .conversationCardSubtitleSize(
                                                          context),
                                                  color: isSelected
                                                      ? AppColors.telegramBlue
                                                          .withValues(
                                                              alpha: 0.8)
                                                      : AppColors
                                                          .getTextSecondary(
                                                              context),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              )
                                            else
                                              Text(
                                                '${conv.messageCount} messages',
                                                style: TextStyle(
                                                  fontSize: ResponsiveValues
                                                      .conversationCardSubtitleSize(
                                                          context),
                                                  color: isSelected
                                                      ? AppColors.telegramBlue
                                                          .withValues(
                                                              alpha: 0.8)
                                                      : AppColors
                                                          .getTextSecondary(
                                                              context),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton(
                                        icon: Icon(
                                          Icons.more_vert,
                                          size: ResponsiveValues.iconSizeXS(
                                              context),
                                          color: isSelected
                                              ? AppColors.telegramBlue
                                              : AppColors.getTextSecondary(
                                                  context),
                                        ),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              ResponsiveValues.radiusMedium(
                                                  context)),
                                        ),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                              value: 'rename',
                                              child: Text('Rename')),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete',
                                                style: TextStyle(
                                                    color:
                                                        AppColors.telegramRed)),
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
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rename Conversation',
                  style: AppTextStyles.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                AppCard.glass(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Enter new title',
                      hintStyle: AppTextStyles.bodyMedium(context).copyWith(
                        color: AppColors.getTextSecondary(context)
                            .withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: ResponsiveValues.listItemPadding(context),
                    ),
                    style: AppTextStyles.bodyMedium(context),
                    autofocus: true,
                  ),
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context)),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                            gradient:
                                LinearGradient(colors: AppColors.blueGradient)),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (controller.text.trim().isNotEmpty) {
                              final success =
                                  await Provider.of<ChatbotProvider>(context,
                                          listen: false)
                                      .renameConversation(
                                conv.id,
                                controller.text.trim(),
                              );
                              if (success && mounted) {
                                SnackbarService().showSuccess(
                                    context, 'Conversation renamed');
                              }
                              if (mounted) Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                                vertical: ResponsiveValues.spacingM(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusMedium(context)),
                            ),
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, ChatbotConversation conv) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: AppCard.glass(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: ResponsiveValues.iconSizeXXL(context),
                  height: ResponsiveValues.iconSizeXXL(context),
                  padding: EdgeInsets.all(ResponsiveValues.spacingM(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1)
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      size: ResponsiveValues.iconSizeXL(context),
                      color: AppColors.telegramRed),
                ),
                SizedBox(height: ResponsiveValues.spacingL(context)),
                Text(
                  'Delete Conversation',
                  style: AppTextStyles.titleLarge(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: ResponsiveValues.spacingM(context)),
                Text(
                  'Are you sure you want to delete "${conv.title}"?',
                  style: AppTextStyles.bodyMedium(context)
                      .copyWith(color: AppColors.getTextSecondary(context)),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: ResponsiveValues.spacingXL(context)),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context)),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    SizedBox(width: ResponsiveValues.spacingM(context)),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                            gradient:
                                LinearGradient(colors: AppColors.pinkGradient)),
                        child: ElevatedButton(
                          onPressed: () async {
                            final success = await Provider.of<ChatbotProvider>(
                                    context,
                                    listen: false)
                                .deleteConversation(conv.id);
                            if (success && mounted) {
                              SnackbarService()
                                  .showSuccess(context, 'Conversation deleted');
                              if (conv.id ==
                                  Provider.of<ChatbotProvider>(context,
                                          listen: false)
                                      .currentConversation
                                      ?.id) {
                                GoRouter.of(context).go('/chatbot');
                              }
                            }
                            if (mounted) Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                                vertical: ResponsiveValues.spacingM(context)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  ResponsiveValues.radiusMedium(context)),
                            ),
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickQuestions() {
    const quickQuestions = [
      'Help with math',
      'Tell me about Ethiopia',
      'Study tips',
      'Teach me Amharic'
    ];

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
                left: ResponsiveValues.spacingS(context),
                bottom: ResponsiveValues.spacingS(context)),
            child: Text(
              'Quick Questions:',
              style: AppTextStyles.labelMedium(context).copyWith(
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
                  padding: EdgeInsets.only(
                      right: ResponsiveValues.spacingS(context)),
                  child: GestureDetector(
                    onTap: () {
                      _messageController.text = question;
                      _sendMessage();
                    },
                    child: AppCard.glass(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        child: Text(
                          question,
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: AppColors.telegramBlue,
                            fontWeight: FontWeight.w500,
                          ),
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
    return AppCard.glass(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingM(context),
          vertical: ResponsiveValues.spacingXS(context),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.message,
              size: ResponsiveValues.iconSizeS(context),
              color: _isOffline
                  ? AppColors.warning
                  : (provider.remainingMessages > 0
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed),
            ),
            SizedBox(width: ResponsiveValues.spacingXS(context)),
            Text(
              _isOffline
                  ? 'Offline'
                  : '${provider.remainingMessages}/${provider.dailyLimit}',
              style: AppTextStyles.labelSmall(context).copyWith(
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
      ),
    );
  }

  Widget _buildInputArea(ChatbotProvider provider) {
    final hasMessagesLeft = provider.hasMessagesLeft;
    final isEnabled = !_isSending;

    return AppCard.glass(
      child: Container(
        padding: ResponsiveValues.cardPadding(context),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isOffline) _buildQuickQuestions(),
            SizedBox(height: ResponsiveValues.spacingM(context)),
            Row(
              children: [
                Expanded(
                  child: AppCard.glass(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: _isOffline
                            ? 'You are offline (messages queued)'
                            : (hasMessagesLeft
                                ? 'Ask about any subject...'
                                : 'Daily limit reached'),
                        hintStyle: AppTextStyles.bodyMedium(context).copyWith(
                          color: isEnabled
                              ? AppColors.getTextSecondary(context)
                              : AppColors.getTextSecondary(context)
                                  .withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingL(context),
                          vertical: ResponsiveValues.spacingM(context),
                        ),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      onSubmitted: (_) => _sendMessage(),
                      enabled: isEnabled,
                      style: AppTextStyles.bodyMedium(context).copyWith(
                        color: isEnabled
                            ? AppColors.getTextPrimary(context)
                            : AppColors.getTextSecondary(context)
                                .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveValues.spacingS(context)),
                if (_isSending)
                  SizedBox(
                    width: ResponsiveValues.iconSizeXL(context),
                    height: ResponsiveValues.iconSizeXL(context),
                    child: Center(
                      child: SizedBox(
                        width: ResponsiveValues.iconSizeM(context),
                        height: ResponsiveValues.iconSizeM(context),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _sendMessage,
                    child: AppCard.glass(
                      child: SizedBox(
                        width: ResponsiveValues.iconSizeXL(context),
                        height: ResponsiveValues.iconSizeXL(context),
                        child: Center(
                          child: Icon(
                            _isOffline ? Icons.schedule_rounded : Icons.send,
                            size: ResponsiveValues.iconSizeS(context),
                            color: _isOffline
                                ? AppColors.warning
                                : AppColors.telegramBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_isOffline && _pendingCount > 0)
              Padding(
                padding:
                    EdgeInsets.only(top: ResponsiveValues.spacingS(context)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: ResponsiveValues.iconSizeXXS(context),
                      color: AppColors.info,
                    ),
                    SizedBox(width: ResponsiveValues.spacingXXS(context)),
                    Text(
                      '$_pendingCount message${_pendingCount > 1 ? 's' : ''} queued',
                      style: AppTextStyles.queuedAction(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea() {
    return Consumer<ChatbotProvider>(
      builder: (context, provider, child) {
        if (provider.isLoadingMessages && provider.messages.isEmpty) {
          return ListView.builder(
            padding: ResponsiveValues.screenPadding(context),
            itemCount: 5,
            itemBuilder: (context, index) => Padding(
              padding:
                  EdgeInsets.only(bottom: ResponsiveValues.spacingL(context)),
              child: const AppShimmer(
                  type: ShimmerType.textLine, customHeight: 60),
            ),
          );
        }

        if (provider.error != null && provider.messages.isEmpty) {
          return Center(
            child: AppEmptyState.error(
              title: 'Error',
              message: provider.error!,
              onRetry: () => provider.clearError(),
            ),
          );
        }

        if (provider.messages.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
                horizontal: ResponsiveValues.spacingXL(context)),
            child: AppEmptyState(
              icon: Icons.smart_toy,
              title: 'AI Learning Assistant',
              message: _isOffline
                  ? 'You are offline. Messages will be queued and sent when online.'
                  : 'Ask me about mathematics, sciences, Amharic, Ethiopian history, or get study tips. You have ${provider.remainingMessages}/${provider.dailyLimit} messages left today.',
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: ResponsiveValues.cardPadding(context),
          itemCount: provider.messages.length,
          itemBuilder: (context, index) =>
              _buildMessageBubble(provider.messages[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context);
    final chatbotProvider = Provider.of<ChatbotProvider>(context);
    final connectivity = Provider.of<ConnectivityService>(context);

    if (_isOffline &&
        chatbotProvider.messages.isEmpty &&
        chatbotProvider.conversations.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: const CustomAppBar(title: 'AI Tutor', subtitle: 'Offline Mode'),
        body: Center(
          child: AppEmptyState.offline(
            dataType: 'chat',
            message:
                'You are offline. Messages will be queued and sent when online.',
            onRetry: () {
              setState(() => _isOffline = false);
            },
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
              child: AppCard.glass(child: _buildConversationList()),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: Column(
          children: [
            CustomAppBar(
              title: chatbotProvider.currentConversation?.title ?? 'AI Tutor',
              subtitle: _isRefreshing
                  ? 'Refreshing...'
                  : (_isOffline ? 'Offline Mode' : _greeting),
              leading: ScreenSize.isMobile(context)
                  ? IconButton(
                      icon: Icon(Icons.menu,
                          color: AppColors.getTextPrimary(context)),
                      onPressed: _showConversationsDrawer,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : null,
              customTrailing: _buildMessageCounter(chatbotProvider),
            ),
            Expanded(
              child: Row(
                children: [
                  if ((ScreenSize.isDesktop(context) ||
                          ScreenSize.isTablet(context)) &&
                      _showConversationList)
                    AnimatedContainer(
                      duration: AppThemes.animationMedium,
                      width: ScreenSize.isTablet(context)
                          ? ResponsiveValues.tabletSidebarWidth(context)
                          : ResponsiveValues.desktopSidebarWidth(context),
                      margin: EdgeInsets.only(
                          right: ResponsiveValues.spacingS(context)),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: AppCard.glass(child: _buildConversationList()),
                      ),
                    ),
                  Expanded(child: _buildChatArea()),
                ],
              ),
            ),
            _buildInputArea(chatbotProvider),
          ],
        ),
      ),
    );
  }
}
