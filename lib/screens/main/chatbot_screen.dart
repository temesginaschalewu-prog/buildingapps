import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/widgets/common/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;
import '../../models/chatbot_model.dart';
import '../../providers/chatbot_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/error_widget.dart' as custom_error;
import '../../widgets/common/responsive_widgets.dart';

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
  String _refreshSubtitle = '';
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();

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
      _setGreeting();
      _checkConnectivity();
      _initializeChat();
      _loadNotifications();
      _setupScreenSize();
      _getCurrentUserId();
    });
  }

  Future<void> _getCurrentUserId() async {
    Provider.of<AuthProvider>(context, listen: false);
  }

  Future<void> _checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      showOfflineMessage(context);
    }
  }

  Widget _buildGlassContainer(
      {required Widget child, double? width, double? height}) {
    return ClipRRect(
      borderRadius:
          BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.getCard(context).withValues(alpha: 0.4),
                AppColors.getCard(context).withValues(alpha: 0.2),
              ],
            ),
            borderRadius:
                BorderRadius.circular(ResponsiveValues.radiusMedium(context)),
            border: Border.all(
              color: AppColors.telegramBlue.withValues(alpha: 0.2),
            ),
          ),
          child: child,
        ),
      ),
    );
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
        setState(() {
          _showConversationList = true;
        });
        _slideController.forward();
      } else {
        setState(() {
          _showConversationList = false;
        });
      }
    });
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
    } catch (e) {
      debugLog('ChatbotScreen', 'Error loading notifications: $e');
    }
  }

  Future<void> _manualRefresh() async {
    if (_isRefreshing) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      setState(() => _isOffline = true);
      _refreshController.refreshFailed();
      showTopSnackBar(
        context,
        'You are offline. Please check your internet connection.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isRefreshing = true;
      _refreshSubtitle = 'Refreshing...';
    });

    try {
      final chatbotProvider =
          Provider.of<ChatbotProvider>(context, listen: false);

      await chatbotProvider.loadConversations(forceRefresh: true);

      if (widget.conversationId != null) {
        await chatbotProvider.loadMessages(widget.conversationId!,
            forceRefresh: true);
      }

      showTopSnackBar(context, 'Chat refreshed');
    } catch (e) {
      showTopSnackBar(context, 'Refresh failed', isError: true);
    } finally {
      setState(() {
        _isRefreshing = false;
        _refreshSubtitle = '';
      });
      _refreshController.refreshCompleted();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setGreeting();
      _checkConnectivity();
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
    _refreshController.dispose();
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
// ... (keep all existing imports and class definition)

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;

    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      showOfflineError(context, action: 'send messages');
      setState(() => _isOffline = true);
      return;
    }

    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);

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
          GoRouter.of(context)
              .replace('/chatbot?conv=${result['conversationId']}');
        }
      } else {
        showTopSnackBar(context, result['error'] ?? 'Failed to send message',
            isError: true);
      }
    } catch (e) {
      if (isNetworkError(e)) {
        showOfflineError(context, action: 'send messages');
        setState(() => _isOffline = true);
      } else {
        showTopSnackBar(context, formatErrorMessage(e), isError: true);
      }
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
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
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
                        AppColors.telegramYellow.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ResponsiveIcon(
                    Icons.lock_outline_rounded,
                    size: ResponsiveValues.iconSizeXL(context),
                    color: AppColors.telegramYellow,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
                  'Daily Limit Reached',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.m),
                ResponsiveText(
                  'You\'ve used all your daily messages (${Provider.of<ChatbotProvider>(context).dailyLimit}). The limit resets at midnight.\n\nYou can still review previous conversations.',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.blueGradient,
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
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
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
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
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ResponsiveIcon(
                    Icons.chat_rounded,
                    size: ResponsiveValues.iconSizeXL(context),
                    color: AppColors.telegramBlue,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
                  'Start New Chat',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.m),
                ResponsiveText(
                  'This will clear the current conversation and start fresh.',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.blueGradient,
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
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
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
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
              padding: EdgeInsets.only(
                right: ResponsiveValues.spacingS(context),
              ),
              child: Container(
                width: ResponsiveValues.iconSizeL(context),
                height: ResponsiveValues.iconSizeL(context),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.blueGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: ResponsiveIcon(
                    Icons.smart_toy,
                    size: ResponsiveValues.iconSizeXS(context),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: ResponsiveValues.chatBubbleMaxWidth(context),
              ),
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
                child: ResponsiveColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ResponsiveText(
                      message.content.replaceAll('*', ''),
                      style: isUser
                          ? AppTextStyles.bodyMedium(context).copyWith(
                              color: Colors.white,
                            )
                          : AppTextStyles.bodyMedium(context),
                    ),
                    ResponsiveSizedBox(height: AppSpacing.xs),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ResponsiveText(
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
              padding: EdgeInsets.only(
                left: ResponsiveValues.spacingS(context),
              ),
              child: Container(
                width: ResponsiveValues.iconSizeL(context),
                height: ResponsiveValues.iconSizeL(context),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.purpleGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: ResponsiveIcon(
                    Icons.person,
                    size: ResponsiveValues.iconSizeXS(context),
                    color: Colors.white,
                  ),
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
            child: LoadingIndicator(),
          );
        }

        return Column(
          children: [
            _buildGlassContainer(
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
                      child: ResponsiveText(
                        'Conversations',
                        style: AppTextStyles.titleSmall(context).copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: ResponsiveIcon(
                        Icons.add_comment_outlined,
                        color: AppColors.telegramBlue,
                      ),
                      onPressed: _isOffline ? null : _showNewChatDialog,
                      tooltip: 'New Chat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (ScreenSize.isDesktop(context) ||
                        ScreenSize.isTablet(context))
                      IconButton(
                        icon: ResponsiveIcon(
                          Icons.close,
                          color: AppColors.getTextSecondary(context),
                        ),
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
                  ? const EmptyState(
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
                          child: _buildGlassContainer(
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
                                      context),
                                ),
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
                                                      AppColors.blueGradient,
                                                )
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
                                                context),
                                          ),
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
                                      ResponsiveSizedBox(width: AppSpacing.s),
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
                                                context),
                                          ),
                                        ),
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(
                                            value: 'rename',
                                            child: Text('Rename'),
                                          ),
                                          const PopupMenuItem(
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
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
              mainAxisSize: MainAxisSize.min,
              children: [
                ResponsiveText(
                  'Rename Conversation',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                _buildGlassContainer(
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
                ResponsiveSizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.blueGradient,
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (controller.text.trim().isNotEmpty) {
                              final success =
                                  await Provider.of<ChatbotProvider>(
                                context,
                                listen: false,
                              ).renameConversation(
                                conv.id,
                                controller.text.trim(),
                              );
                              if (success && mounted) {
                                showTopSnackBar(
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
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
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
        child: _buildGlassContainer(
          child: Padding(
            padding: ResponsiveValues.dialogPadding(context),
            child: ResponsiveColumn(
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
                        AppColors.telegramRed.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ResponsiveIcon(
                    Icons.delete_outline_rounded,
                    size: ResponsiveValues.iconSizeXL(context),
                    color: AppColors.telegramRed,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.l),
                ResponsiveText(
                  'Delete Conversation',
                  style: AppTextStyles.titleLarge(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ResponsiveSizedBox(height: AppSpacing.m),
                ResponsiveText(
                  'Are you sure you want to delete "${conv.title}"?',
                  style: AppTextStyles.bodyMedium(context).copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                ResponsiveSizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: EdgeInsets.symmetric(
                            vertical: ResponsiveValues.spacingM(context),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveValues.radiusMedium(context),
                            ),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    ResponsiveSizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.pinkGradient,
                          ),
                          borderRadius: BorderRadius.circular(
                            ResponsiveValues.radiusMedium(context),
                          ),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            final success = await Provider.of<ChatbotProvider>(
                              context,
                              listen: false,
                            ).deleteConversation(conv.id);
                            if (success && mounted) {
                              showTopSnackBar(context, 'Conversation deleted');
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
                              vertical: ResponsiveValues.spacingM(context),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                ResponsiveValues.radiusMedium(context),
                              ),
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
    final quickQuestions = [
      'Help with math',
      'Tell me about Ethiopia',
      'Study tips',
      'Teach me Amharic',
    ];

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveValues.spacingM(context),
        vertical: ResponsiveValues.spacingS(context),
      ),
      child: ResponsiveColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveValues.spacingS(context),
              bottom: ResponsiveValues.spacingS(context),
            ),
            child: ResponsiveText(
              'Quick Questions:',
              style: AppTextStyles.labelMedium(context).copyWith(
                color: AppColors.getTextSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ResponsiveRow(
              children: quickQuestions.map((question) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: ResponsiveValues.spacingS(context),
                  ),
                  child: GestureDetector(
                    onTap: _isOffline
                        ? null
                        : () {
                            _messageController.text = question;
                            _sendMessage();
                          },
                    child: _buildGlassContainer(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveValues.spacingM(context),
                          vertical: ResponsiveValues.spacingXS(context),
                        ),
                        child: ResponsiveText(
                          question,
                          style: AppTextStyles.labelSmall(context).copyWith(
                            color: _isOffline
                                ? AppColors.getTextSecondary(context)
                                    .withValues(alpha: 0.3)
                                : AppColors.telegramBlue,
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
          if (_isOffline)
            Padding(
              padding: EdgeInsets.only(
                top: ResponsiveValues.spacingS(context),
                left: ResponsiveValues.spacingS(context),
              ),
              child: ResponsiveText(
                'Connect to internet to send messages',
                style: AppTextStyles.caption(context).copyWith(
                  color: AppColors.telegramYellow,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageCounter(ChatbotProvider provider) {
    return _buildGlassContainer(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingM(context),
          vertical: ResponsiveValues.spacingXS(context),
        ),
        child: ResponsiveRow(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResponsiveIcon(
              Icons.message,
              size: ResponsiveValues.iconSizeS(context),
              color: _isOffline
                  ? AppColors.telegramGray
                  : (provider.remainingMessages > 0
                      ? AppColors.telegramGreen
                      : AppColors.telegramRed),
            ),
            ResponsiveSizedBox(width: AppSpacing.xs),
            ResponsiveText(
              _isOffline
                  ? 'Offline'
                  : '${provider.remainingMessages}/${provider.dailyLimit}',
              style: AppTextStyles.labelSmall(context).copyWith(
                fontWeight: FontWeight.w600,
                color: _isOffline
                    ? AppColors.telegramGray
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
    final isEnabled = hasMessagesLeft && !_isSending && !_isOffline;

    return _buildGlassContainer(
      child: Container(
        padding: ResponsiveValues.cardPadding(context),
        child: ResponsiveColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isOffline) _buildQuickQuestions(),
            ResponsiveSizedBox(height: AppSpacing.m),
            Row(
              children: [
                Expanded(
                  child: _buildGlassContainer(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: _isOffline
                            ? 'You are offline'
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
                ResponsiveSizedBox(width: AppSpacing.s),
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
                    onTap: isEnabled ? _sendMessage : null,
                    child: _buildGlassContainer(
                      child: SizedBox(
                        width: ResponsiveValues.iconSizeXL(context),
                        height: ResponsiveValues.iconSizeXL(context),
                        child: Center(
                          child: ResponsiveIcon(
                            Icons.send,
                            size: ResponsiveValues.iconSizeS(context),
                            color: isEnabled
                                ? AppColors.telegramBlue
                                : AppColors.getTextSecondary(context)
                                    .withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
          return const Center(
            child: LoadingIndicator(),
          );
        }

        if (provider.error != null && provider.messages.isEmpty) {
          return Center(
            child: custom_error.ErrorWidget(
              title: 'Error',
              message: provider.error!,
              onRetry: () => provider.clearError(),
            ),
          );
        }

        if (provider.messages.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveValues.spacingXL(context),
            ),
            child: EmptyState(
              icon: Icons.smart_toy,
              title: 'AI Learning Assistant',
              message: _isOffline
                  ? 'You are offline. Connect to start chatting with the AI assistant.'
                  : 'Ask me about mathematics, sciences, Amharic, Ethiopian history, or get study tips. You have ${provider.remainingMessages}/${provider.dailyLimit} messages left today.',
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: ResponsiveValues.cardPadding(context),
          itemCount: provider.messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(provider.messages[index]);
          },
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    Provider.of<AuthProvider>(context);
    final chatbotProvider = Provider.of<ChatbotProvider>(context);

    if (_isOffline &&
        chatbotProvider.messages.isEmpty &&
        chatbotProvider.conversations.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: CustomAppBar(
          title: 'AI Tutor',
          subtitle: 'Offline Mode',
        ),
        body: Center(
          child: OfflineState(
            dataType: 'chat',
            message:
                'You are offline. Connect to start chatting with the AI assistant.',
            onRetry: () {
              setState(() => _isOffline = false);
              _checkConnectivity();
            },
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
              child: _buildGlassContainer(
                child: _buildConversationList(),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: AppColors.telegramBlue,
        backgroundColor: AppColors.getSurface(context),
        child: ResponsiveColumn(
          children: [
            CustomAppBar(
              title: chatbotProvider.currentConversation?.title ?? 'AI Tutor',
              subtitle: _isRefreshing
                  ? 'Refreshing...'
                  : (_isOffline ? 'Offline Mode' : _greeting),
              leading: ScreenSize.isMobile(context)
                  ? IconButton(
                      icon: ResponsiveIcon(
                        Icons.menu,
                        color: AppColors.getTextPrimary(context),
                      ),
                      onPressed: _showConversationsDrawer,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    )
                  : null,
              customTrailing: _buildMessageCounter(chatbotProvider),
            ),
            Expanded(
              child: ResponsiveRow(
                children: [
                  if ((ScreenSize.isDesktop(context) ||
                          ScreenSize.isTablet(context)) &&
                      _showConversationList)
                    AnimatedContainer(
                      duration: AppThemes.animationDurationMedium,
                      width: ScreenSize.isTablet(context)
                          ? ResponsiveValues.tabletSidebarWidth(context)
                          : ResponsiveValues.desktopSidebarWidth(context),
                      margin: EdgeInsets.only(
                        right: ResponsiveValues.spacingS(context),
                      ),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildGlassContainer(
                          child: _buildConversationList(),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _buildChatArea(),
                  ),
                ],
              ),
            ),
            _buildInputArea(chatbotProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return _buildMobileLayout();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }
}
