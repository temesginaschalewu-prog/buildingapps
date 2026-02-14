import 'dart:async';

import 'package:familyacademyclient/providers/subscription_provider.dart';
import 'package:familyacademyclient/themes/app_colors.dart';
import 'package:familyacademyclient/themes/app_text_styles.dart';
import 'package:familyacademyclient/utils/helpers.dart';
import 'package:flutter/material.dart';
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

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  final FocusNode _focusNode = FocusNode();
  Timer? _typingIndicatorTimer;
  bool _showTypingIndicator = false;
  int _unreadNotifications = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      _checkSubscriptionAccess();
      _loadNotifications();
    });
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

  Future<void> _checkSubscriptionAccess() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null && user.accountStatus != 'active') {
        final subscriptionProvider =
            Provider.of<SubscriptionProvider>(context, listen: false);
        await subscriptionProvider.loadSubscriptions();

        if (subscriptionProvider.activeSubscriptions.isNotEmpty) {
          final updatedUser = user.copyWith(accountStatus: 'active');
          await authProvider.updateUser(updatedUser);

          if (mounted) {
            setState(() {});
          }
        }
      }
    } catch (e) {
      debugLog('ChatbotScreen', 'Error checking subscription access: $e');
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
    _typingIndicatorTimer?.cancel();
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

  void _showTyping() {
    if (_typingIndicatorTimer != null) {
      _typingIndicatorTimer!.cancel();
    }

    setState(() => _showTypingIndicator = true);

    _typingIndicatorTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showTypingIndicator = false);
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

    // Show typing indicator
    _showTyping();

    await chatbotProvider.sendMessage(message);

    setState(() => _isSending = false);
    _scrollToBottom();
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
          'You\'ve used all your daily messages. '
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

  void _showClearConversationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
        ),
        backgroundColor: AppColors.getCard(context),
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Clear Conversation',
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.getTextPrimary(context),
          ),
        ),
        content: Text(
          'Are you sure you want to clear all messages?',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.getTextSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.getTextSecondary(context),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<ChatbotProvider>(context, listen: false)
                  .clearConversation();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.telegramRed,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isUser) {
    final timestamp = message['timestamp'] as DateTime? ?? DateTime.now();
    final timeStr =
        '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';

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
                        message['text'].toString(),
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppThemes.spacingM,
        right: AppThemes.spacingXXL,
        bottom: AppThemes.spacingL,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppThemes.spacingL,
              vertical: AppThemes.spacingM,
            ),
            decoration: BoxDecoration(
              color: AppColors.getCard(context),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTypingDot(0),
                _buildTypingDot(1),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: const BoxDecoration(
        color: AppColors.telegramBlue,
        shape: BoxShape.circle,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .scale(
          duration: 600.ms,
          delay: (index * 200).ms,
        )
        .fade(
          begin: 0.3,
          end: 1.0,
          duration: 600.ms,
          delay: (index * 200).ms,
        );
  }

  Widget _buildQuickQuestions() {
    final quickQuestions = [
      'Help with algebra equations',
      'Explain photosynthesis',
      'How to improve English writing?',
      'Study tips for exams',
      'Ethiopian history timeline',
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

  Widget _buildInputArea(ChatbotProvider chatbotProvider) {
    final hasMessagesLeft = chatbotProvider.hasMessagesLeft;
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
                      suffixIcon: _isSending
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.telegramBlue,
                                ),
                              ),
                            )
                          : null,
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
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: isEnabled ? _sendMessage : null,
                  icon: Icon(
                    Icons.send,
                    color: isEnabled
                        ? Colors.white
                        : AppColors.getTextSecondary(context).withOpacity(0.4),
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

  Widget _buildMessageCounter(ChatbotProvider chatbotProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemes.spacingM,
        vertical: AppThemes.spacingXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.getStatusBackground('active', context),
        borderRadius: BorderRadius.circular(AppThemes.borderRadiusFull),
        border: Border.all(
          color: AppColors.getStatusColor('active', context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.message,
            size: 14,
            color: AppColors.getStatusColor('active', context),
          ),
          const SizedBox(width: 4),
          Text(
            '${chatbotProvider.remainingMessages}/50',
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.getStatusColor('active', context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner(AuthProvider authProvider) {
    final user = authProvider.currentUser;
    final isSubscriptionActive = user?.accountStatus == 'active';

    if (isSubscriptionActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppThemes.spacingL,
        vertical: AppThemes.spacingM,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.telegramBlue.withOpacity(0.08),
            AppColors.telegramBlue.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: AppColors.telegramBlue.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.telegramBlue,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.star,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppThemes.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlimited AI Tutor',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.telegramBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Upgrade to premium for unlimited assistance',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: AppThemes.spacingM),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.blueGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppThemes.borderRadiusMedium),
              boxShadow: [
                BoxShadow(
                  color: AppColors.telegramBlue.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextButton(
              onPressed: () {
                // Navigate to subscription page
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Upgrade',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationButton() {
    return GestureDetector(
      onTap: () async {
        try {
          final notificationProvider =
              Provider.of<NotificationProvider>(context, listen: false);
          await notificationProvider.loadNotifications();
          // Navigate to notifications
        } catch (e) {
          showSnackBar(context, 'Failed to load notifications', isError: true);
        }
      },
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
                  position: badges.BadgePosition.topEnd(top: -4, end: -4),
                  badgeContent: Text(
                    _unreadNotifications > 9
                        ? '9+'
                        : _unreadNotifications.toString(),
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: badges.BadgeStyle(
                    badgeColor: AppColors.telegramRed,
                    padding: const EdgeInsets.all(4),
                    borderRadius:
                        BorderRadius.circular(AppThemes.borderRadiusFull),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 22,
                    color: AppColors.getTextPrimary(context),
                  ),
                )
              : Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: AppColors.getTextPrimary(context),
                ),
        ),
      ),
    );
  }

  Widget _buildThemeToggleButton() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return GestureDetector(
          onTap: () {
            themeProvider.toggleTheme();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                themeProvider.themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 22,
                color: AppColors.getTextPrimary(context),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatbotProvider = Provider.of<ChatbotProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: AppColors.getBackground(context),
              foregroundColor: AppColors.getTextPrimary(context),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: 100.0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.telegramBlue.withOpacity(0.05),
                        AppColors.getBackground(context),
                      ],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: AppThemes.spacingL,
                    right: AppThemes.spacingL,
                    top: MediaQuery.of(context).padding.top + 16,
                    bottom: AppThemes.spacingL,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Tutor',
                                style: AppTextStyles.headlineSmall.copyWith(
                                  color: AppColors.getTextPrimary(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppThemes.spacingXS),
                              Text(
                                'Your personal learning assistant',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildThemeToggleButton(),
                              const SizedBox(width: AppThemes.spacingS),
                              _buildNotificationButton(),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(0),
                child: _buildPremiumBanner(authProvider),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            Expanded(
              child: chatbotProvider.messages.isEmpty
                  ? EmptyState(
                      icon: Icons.smart_toy,
                      title: 'Start Learning Conversation',
                      message:
                          'Ask questions about any subject or request study help.',
                      centerContent: true,
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppThemes.spacingL),
                      itemCount: chatbotProvider.messages.length +
                          (_showTypingIndicator ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_showTypingIndicator &&
                            index == chatbotProvider.messages.length) {
                          return _buildTypingIndicator();
                        }
                        final message = chatbotProvider.messages[index];
                        return _buildMessageBubble(
                            message, message['isUser'] == true);
                      },
                    ),
            ),
            _buildInputArea(chatbotProvider),
          ],
        ),
      ),
    );
  }
}
