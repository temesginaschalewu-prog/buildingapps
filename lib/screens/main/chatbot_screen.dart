import 'dart:async';
import 'dart:ui';
import 'package:familyacademyclient/widgets/common/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/chatbot_model.dart';
import '../../providers/chatbot_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../themes/app_themes.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
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
  String _greeting = '';
  String _timeBasedEmoji = '';
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
      _setGreeting();
      _initializeChat();
      _loadNotifications();
      _setupScreenSize();
    });
  }

  Widget _buildGlassContainer(
      {required Widget child, double? width, double? height}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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
            borderRadius: BorderRadius.circular(16),
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
      _timeBasedEmoji = '🌅';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
      _timeBasedEmoji = '☀️';
    } else {
      _greeting = 'Good Evening';
      _timeBasedEmoji = '🌙';
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
      _setGreeting();
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
          duration: const Duration(milliseconds: 300),
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
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildGlassContainer(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramYellow.withValues(alpha: 0.2),
                        AppColors.telegramYellow.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.telegramYellow, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Daily Limit Reached',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You\'ve used all your daily messages (${Provider.of<ChatbotProvider>(context).dailyLimit}). '
                  'The limit resets at midnight. '
                  '\n\nYou can still review previous conversations.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramBlue.withValues(alpha: 0.2),
                        AppColors.telegramPurple.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_rounded,
                      color: AppColors.telegramBlue, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Start New Chat',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This will clear the current conversation and start fresh.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium),
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

  void _showConversationsDrawer() {
    if (ScreenSize.isMobile(context)) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      setState(() {
        _showConversationList = !_showConversationList;
        if (_showConversationList) {
          _slideController.forward();
          Future.delayed(const Duration(milliseconds: 100), () {
            setState(() {});
          });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 48 : 12,
        right: isUser ? 12 : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.blueGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.smart_toy,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.telegramBlue
                    : (isDark
                        ? AppColors.darkCard.withValues(alpha: 0.6)
                        : AppColors.lightCard),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content.replaceAll('*', ''),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isUser
                          ? Colors.white
                          : AppColors.getTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeStr,
                      style: AppTextStyles.labelSmall.copyWith(
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
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.purpleGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.person,
                    size: 16,
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
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                child: Row(
                  children: [
                    Text(
                      'Conversations',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined,
                          color: AppColors.telegramBlue),
                      onPressed: _showNewChatDialog,
                      tooltip: 'New Chat',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (ScreenSize.isDesktop(context) ||
                        ScreenSize.isTablet(context))
                      IconButton(
                        icon: Icon(Icons.close,
                            color: AppColors.getTextSecondary(context)),
                        onPressed: _showConversationsDrawer,
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
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFF2AABEE),
                                                    Color(0xFF5856D6),
                                                  ],
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
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.chat_outlined,
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.getTextPrimary(
                                                  context),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              conv.title,
                                              style: AppTextStyles.bodyMedium
                                                  .copyWith(
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
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                  color: isSelected
                                                      ? AppColors.telegramBlue
                                                          .withValues(alpha: 0.8)
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
                                                style: AppTextStyles.labelSmall
                                                    .copyWith(
                                                  color: isSelected
                                                      ? AppColors.telegramBlue
                                                          .withValues(alpha: 0.8)
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
                                          size: 20,
                                          color: isSelected
                                              ? AppColors.telegramBlue
                                              : AppColors.getTextSecondary(
                                                  context),
                                        ),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              AppThemes.borderRadiusMedium),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rename Conversation',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _buildGlassContainer(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Enter new title',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context)
                            .withValues(alpha: 0.5),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextPrimary(context),
                    ),
                    autofocus: true,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2AABEE), Color(0xFF5856D6)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (controller.text.trim().isNotEmpty) {
                              final success =
                                  await Provider.of<ChatbotProvider>(context,
                                          listen: false)
                                      .renameConversation(
                                          conv.id, controller.text.trim());
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium),
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
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.telegramRed.withValues(alpha: 0.2),
                        AppColors.telegramRed.withValues(alpha: 0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.telegramRed, size: 32),
                ),
                const SizedBox(height: 16),
                Text(
                  'Delete Conversation',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you sure you want to delete "${conv.title}"?',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.getTextSecondary(context),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                AppThemes.borderRadiusMedium),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF3B30), Color(0xFFE6204A)],
                          ),
                          borderRadius: BorderRadius.circular(
                              AppThemes.borderRadiusMedium),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            final success = await Provider.of<ChatbotProvider>(
                                    context,
                                    listen: false)
                                .deleteConversation(conv.id);
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
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppThemes.borderRadiusMedium),
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
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
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      _messageController.text = question;
                      _sendMessage();
                    },
                    child: _buildGlassContainer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          question,
                          style: AppTextStyles.labelSmall.copyWith(
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
    return _buildGlassContainer(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.message,
              size: 14,
              color: provider.remainingMessages > 0
                  ? AppColors.telegramGreen
                  : AppColors.telegramRed,
            ),
            const SizedBox(width: 4),
            Text(
              '${provider.remainingMessages}/${provider.dailyLimit}',
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
                color: provider.remainingMessages > 0
                    ? AppColors.telegramGreen
                    : AppColors.telegramRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatbotProvider provider) {
    final hasMessagesLeft = provider.hasMessagesLeft;
    final isEnabled = hasMessagesLeft && !_isSending;

    return _buildGlassContainer(
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQuickQuestions(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildGlassContainer(
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
                                  .withValues(alpha: 0.4),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
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
                  GestureDetector(
                    onTap: isEnabled ? _sendMessage : null,
                    child: _buildGlassContainer(
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            Icons.send,
                            color: isEnabled
                                ? AppColors.telegramBlue
                                : AppColors.getTextSecondary(context)
                                    .withValues(alpha: 0.4),
                            size: 20,
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: EmptyState(
              icon: Icons.smart_toy,
              title: 'AI Learning Assistant',
              message:
                  'Ask me about mathematics, sciences, Amharic, Ethiopian history, or get study tips. You have ${provider.remainingMessages}/${provider.dailyLimit} messages left today.',
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
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
    final authProvider = Provider.of<AuthProvider>(context);
    final chatbotProvider = Provider.of<ChatbotProvider>(context);
    final username = authProvider.currentUser?.username ?? 'Student';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.getBackground(context),
      drawer: ScreenSize.isMobile(context)
          ? Drawer(
              width: MediaQuery.of(context).size.width * 0.8,
              backgroundColor: Colors.transparent,
              child: _buildGlassContainer(
                child: _buildConversationList(),
              ),
            )
          : null,
      body: Column(
        children: [
          CustomAppBar(
            title: chatbotProvider.currentConversation?.title ?? 'AI Tutor',
            subtitle: _greeting,
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
                    duration: AppThemes.animationDurationMedium,
                    width: ScreenSize.isTablet(context) ? 280 : 320,
                    margin: const EdgeInsets.only(right: 8),
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
    );
  }
}
