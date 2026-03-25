import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart' hide RefreshIndicator;

import '../../models/chatbot_model.dart';
import '../../providers/chatbot_provider.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/base_screen_mixin.dart';
import '../../widgets/common/app_dialog.dart';
import '../../services/snackbar_service.dart';
import '../../utils/helpers.dart';
import '../../utils/responsive.dart';
import '../../utils/responsive_values.dart';
import '../../widgets/common/app_card.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_themes.dart';
import '../../themes/app_text_styles.dart';

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
  String get screenTitle =>
      _provider.currentConversation?.title ?? 'Learning assistant';

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
  List<Widget>? get appBarActions => [_buildMessageCounter()];

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

    if (_hasCompletedCurrentViewLoad()) {
      _initialLoadDone = true;
    }
  }

  void _onProviderDataChanged() {
    if (mounted) {
      setState(() {
        if (_hasCompletedCurrentViewLoad()) {
          _initialLoadDone = true;
        }
      });
    }
  }

  bool _isViewingConversationMessages() {
    return widget.conversationId != null || _provider.currentConversation != null;
  }

  bool _hasCompletedCurrentViewLoad() {
    if (_isViewingConversationMessages()) {
      return _provider.hasLoadedMessages ||
          _provider.messages.isNotEmpty ||
          _provider.isOffline;
    }

    return _provider.hasLoadedConversations ||
        _provider.conversations.isNotEmpty ||
        _provider.isOffline;
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
      _greeting = 'Good morning';
    } else if (hour < 17) {
      _greeting = 'Good afternoon';
    } else {
      _greeting = 'Good evening';
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
      if (isMounted) {
        SnackbarService().showInfo(
          context,
          isOffline
              ? 'You are offline. Showing your saved conversations.'
              : 'We could not refresh conversations just now.',
        );
      }
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
      padding: ResponsiveValues.mediaOverlayChipPadding(context),
      decoration: BoxDecoration(
        color: isOffline
            ? AppColors.telegramBlue.withValues(alpha: 0.10)
            : (_provider.remainingMessages > 0
                ? AppColors.telegramGreen.withValues(alpha: 0.10)
                : AppColors.telegramRed.withValues(alpha: 0.10)),
        borderRadius: BorderRadius.circular(
          ResponsiveValues.radiusFull(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.message,
            size: 16,
            color: isOffline
                ? AppColors.telegramBlue
                : (_provider.remainingMessages > 0
                    ? AppColors.telegramGreen
                    : AppColors.telegramRed),
          ),
          SizedBox(width: ResponsiveValues.spacingXXS(context)),
          Text(
            isOffline
                ? 'Offline'
                : '${_provider.remainingMessages}/${_provider.dailyLimit}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isOffline
                  ? AppColors.telegramBlue
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
          title: 'No conversations yet',
          message: 'Start a new chat whenever you want help studying.',
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            ResponsiveValues.spacingL(context),
            MediaQuery.of(context).padding.top + ResponsiveValues.spacingM(context),
            ResponsiveValues.spacingL(context),
            ResponsiveValues.spacingS(context),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conversations',
                      style: AppTextStyles.titleMedium(context).copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: ResponsiveValues.spacingXXS(context)),
                    Text(
                      'Pick up where you left off or start a new study chat.',
                      style: AppTextStyles.bodySmall(context).copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_comment_outlined,
                  color: AppColors.telegramBlue,
                ),
                onPressed: isOffline ? null : _showNewChatDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _provider.conversations.length,
            itemBuilder: (context, index) {
              final conv = _provider.conversations[index];
              final isSelected = _provider.currentConversation?.id == conv.id;
              final isCompactSidebar =
                  ScreenSize.isTablet(context) || ScreenSize.isDesktop(context);

              return ListTile(
                dense: isCompactSidebar,
                visualDensity: isCompactSidebar
                    ? const VisualDensity(horizontal: -1, vertical: -2)
                    : VisualDensity.standard,
                minLeadingWidth: isCompactSidebar ? 36 : 40,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isCompactSidebar ? 12 : 16,
                  vertical: isCompactSidebar ? 2 : 6,
                ),
                leading: CircleAvatar(
                  radius: isCompactSidebar ? 18 : 20,
                  backgroundColor: isSelected
                      ? AppColors.telegramBlue
                      : AppColors.getSurface(context),
                  child: Icon(
                    Icons.chat_outlined,
                    size: isCompactSidebar ? 18 : 20,
                    color: isSelected ? Colors.white : AppColors.telegramBlue,
                  ),
                ),
                title: Text(
                  conv.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                        style: AppTextStyles.caption(context),
                      )
                    : Text(
                        '${conv.messageCount} messages',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption(context),
                      ),
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
    AppDialog.input(
      context: context,
      title: 'Rename conversation',
      initialValue: conv.title,
      hintText: 'Enter a new title',
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a title';
        }
        return null;
      },
    ).then((value) async {
      final newTitle = value?.trim();
      if (newTitle == null || newTitle.isEmpty || newTitle == conv.title) {
        return;
      }
      final success = await _provider.renameConversation(conv.id, newTitle);
      if (success && mounted) {
        SnackbarService().showSuccess(context, 'Conversation renamed');
      }
    });
  }

  void _showDeleteDialog(BuildContext context, ChatbotConversation conv) {
    AppDialog.delete(
      context: context,
      title: 'Delete conversation',
      message: 'Delete "${conv.title}"? This cannot be undone.',
    ).then((confirmed) async {
      if (confirmed == true) {
        final success = await _provider.deleteConversation(conv.id);
        if (success && mounted) {
          SnackbarService().showSuccess(context, 'Conversation deleted');
        }
      }
    });
  }

  void _showNewChatDialog() {
    AppDialog.confirm(
      context: context,
      title: 'Start a new chat',
      message: 'This will clear the current conversation and start fresh.',
      confirmText: 'Start new',
    ).then((confirmed) {
      if (confirmed == true) {
        _provider.clearCurrentConversation();
        GoRouter.of(context).go('/chatbot');
        setState(() => _initialLoadDone = false);
      }
    });
  }

  Widget _buildInputArea() {
    return Container(
      padding: ResponsiveValues.modalHeaderPadding(context),
      decoration: BoxDecoration(
        color: AppColors.getCard(context).withValues(alpha: 0.8),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ResponsiveValues.radiusXXLarge(context)),
        ),
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
                      borderRadius: BorderRadius.circular(
                        ResponsiveValues.radiusLarge(context),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveValues.spacingL(context),
                      vertical: ResponsiveValues.spacingM(context),
                    ),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              SizedBox(width: ResponsiveValues.spacingS(context)),
              if (_isSending)
                SizedBox(
                  width: ResponsiveValues.selectionSheetLeadingSize(context),
                  height: ResponsiveValues.selectionSheetLeadingSize(context),
                  child: Center(
                    child: SizedBox(
                      width: ResponsiveValues.iconSizeL(context),
                      height: ResponsiveValues.iconSizeL(context),
                      child: const CircularProgressIndicator(strokeWidth: 2),
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
        padding: ResponsiveValues.modalHeaderPadding(context),
        itemCount: _provider.messages.length,
        itemBuilder: (context, index) {
          final message = _provider.messages[index];
          final isUser = message.isUser;

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: EdgeInsets.only(
                bottom: ResponsiveValues.spacingS(context),
                left: isUser ? ResponsiveValues.spacingXXXXL(context) : 0,
                right: isUser ? 0 : ResponsiveValues.spacingXXXXL(context),
              ),
              padding: ResponsiveValues.cardPadding(context),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.telegramBlue
                    : AppColors.getCard(context),
                borderRadius: BorderRadius.circular(
                  ResponsiveValues.radiusXLarge(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content.replaceAll('*', ''),
                    style: isUser ? const TextStyle(color: Colors.white) : null,
                  ),
                  SizedBox(height: ResponsiveValues.spacingXXS(context)),
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
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveValues.spacingXXXXL(context),
          ),
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
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveValues.spacingXXXXL(context),
        ),
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
      onRefresh: handleRefresh,
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
                  margin: EdgeInsets.only(
                    right: ResponsiveValues.spacingS(context),
                  ),
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: AppCard.solid(
                      padding: EdgeInsets.zero,
                      backgroundColor:
                          AppColors.getCard(context).withValues(alpha: 0.62),
                      borderColor: AppColors.getDivider(context)
                          .withValues(alpha: 0.28),
                      child: _buildConversationList(),
                    ),
                  ),
                ),
              Expanded(child: _buildChatArea()),
            ],
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
              child: AppCard.solid(
                padding: EdgeInsets.zero,
                backgroundColor:
                    AppColors.getCard(context).withValues(alpha: 0.62),
                borderColor:
                    AppColors.getDivider(context).withValues(alpha: 0.28),
                child: _buildConversationList(),
              ),
            )
          : null,
      body: buildScreen(
          content: buildContent(context),
          showRefreshIndicator: false), // RefreshIndicator is inside content
      bottomNavigationBar: _buildInputArea(),
    );
  }
}
