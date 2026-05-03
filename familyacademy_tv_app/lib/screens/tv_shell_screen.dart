import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/tv_session_controller.dart';
import '../models/content_models.dart';
import '../services/tv_api_service.dart';
import '../widgets/tv_focus_card.dart';
import 'course_screen.dart';
import 'exam_session_screen.dart';

enum TvShellSection {
  library,
  notifications,
  chatbot,
  progress,
  subscriptions,
  parentLink,
  support,
  profile,
}

class TvShellScreen extends StatefulWidget {
  const TvShellScreen({super.key});

  @override
  State<TvShellScreen> createState() => _TvShellScreenState();
}

class _TvShellScreenState extends State<TvShellScreen> {
  TvShellSection _section = TvShellSection.library;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<TvSessionController>();

    return Scaffold(
      backgroundColor: const Color(0xFF09111F),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 280,
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1B31),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Family Academy TV',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    session.currentUser?.username ?? '',
                    style: const TextStyle(
                      color: Color(0xFF9FB3D7),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final item in _navItems)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _NavTile(
                              item: item,
                              selected: _section == item.section,
                              autofocus: item.section == _section,
                              onPressed: () => setState(() => _section = item.section),
                            ),
                          ),
                      ],
                    ),
                  ),
                  TvFocusCard(
                    onPressed: () => session.resetPairing(unpairServer: true),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: const Row(
                      children: [
                        Icon(Icons.link_off_rounded, color: Color(0xFFFFB4B4)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Unlink TV',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 20, 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_section),
                    child: _buildSection(_section),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(TvShellSection section) {
    switch (section) {
      case TvShellSection.library:
        return const _LibrarySection();
      case TvShellSection.notifications:
        return const TvNotificationsScreen();
      case TvShellSection.chatbot:
        return const TvChatbotScreen();
      case TvShellSection.progress:
        return const TvProgressScreen();
      case TvShellSection.subscriptions:
        return const TvSubscriptionsScreen();
      case TvShellSection.parentLink:
        return const TvParentLinkScreen();
      case TvShellSection.support:
        return const TvSupportScreen();
      case TvShellSection.profile:
        return const TvProfileScreen();
    }
  }
}

class _NavEntry {
  const _NavEntry(this.section, this.icon, this.label);

  final TvShellSection section;
  final IconData icon;
  final String label;
}

const List<_NavEntry> _navItems = [
  _NavEntry(TvShellSection.library, Icons.dashboard_rounded, 'Library'),
  _NavEntry(TvShellSection.notifications, Icons.notifications_rounded, 'Notifications'),
  _NavEntry(TvShellSection.chatbot, Icons.smart_toy_rounded, 'Chatbot'),
  _NavEntry(TvShellSection.progress, Icons.trending_up_rounded, 'Progress'),
  _NavEntry(TvShellSection.subscriptions, Icons.workspace_premium_rounded, 'Subscriptions'),
  _NavEntry(TvShellSection.parentLink, Icons.family_restroom_rounded, 'Parent Link'),
  _NavEntry(TvShellSection.support, Icons.support_agent_rounded, 'Support'),
  _NavEntry(TvShellSection.profile, Icons.person_rounded, 'Profile'),
];

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onPressed,
    this.autofocus = false,
  });

  final _NavEntry item;
  final bool selected;
  final bool autofocus;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TvFocusCard(
      autofocus: autofocus,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(
            item.icon,
            color: selected ? const Color(0xFF8FC8FF) : Colors.white70,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionPane extends StatelessWidget {
  const _SectionPane({
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D1830),
            Color(0xFF12213F),
          ],
        ),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFADC1E6),
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                actions ?? const SizedBox.shrink(),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _LibrarySection extends StatefulWidget {
  const _LibrarySection();

  @override
  State<_LibrarySection> createState() => _LibrarySectionState();
}

class _LibrarySectionState extends State<_LibrarySection> {
  late Future<_LibraryPayload> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadLibrary();
  }

  Future<_LibraryPayload> _loadLibrary() async {
    final api = context.read<TvApiService>();
    final results = await Future.wait([
      api.getCategories(),
      api.getMySubscriptions(),
    ]);
    return _LibraryPayload(
      categories: results[0] as List<CategoryItem>,
      subscriptions: results[1] as List<SubscriptionItem>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Library',
      subtitle: 'Browse your categories, courses, chapters, videos, notes, and practice content with the TV remote.',
      child: FutureBuilder<_LibraryPayload>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: 'Could not load categories.\n${snapshot.error}');
          }
          final payload = snapshot.data;
          final categories = (payload?.categories ?? const <CategoryItem>[])
              .where((item) => !item.isComingSoon)
              .toList();
          final activeCategoryIds = (payload?.subscriptions ?? const <SubscriptionItem>[])
              .where((item) => item.isActive)
              .map((item) => item.categoryId)
              .whereType<int>()
              .toSet();
          if (categories.isEmpty) {
            return const _EmptyState(
              title: 'No categories yet',
              message: 'Your categories will appear here once content is ready.',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.only(bottom: 6),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 0.82,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              final hasFullAccess = item.hasAccess == true || activeCategoryIds.contains(item.id);
              return TvFocusCard(
                autofocus: index == 0,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CourseScreen(category: item)),
                  );
                },
                padding: EdgeInsets.zero,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: item.imageUrl?.isNotEmpty == true
                          ? CachedNetworkImage(
                              imageUrl: item.imageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => _LetterFallback(text: item.name),
                            )
                          : _LetterFallback(text: item.name),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x11000000), Color(0xDF11192A)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Wrap(
                              direction: Axis.vertical,
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              children: [
                                _Badge(
                                  label: hasFullAccess
                                      ? 'Unlocked'
                                      : item.price == null || item.price == 0
                                          ? 'Free'
                                          : '${item.price!.toStringAsFixed(0)} ETB',
                                  compact: true,
                                ),
                                if (!hasFullAccess)
                                  const _Badge(
                                    label: 'Need plan',
                                    compact: true,
                                  ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LibraryPayload {
  const _LibraryPayload({
    required this.categories,
    required this.subscriptions,
  });

  final List<CategoryItem> categories;
  final List<SubscriptionItem> subscriptions;
}

class TvNotificationsScreen extends StatefulWidget {
  const TvNotificationsScreen({super.key});

  @override
  State<TvNotificationsScreen> createState() => _TvNotificationsScreenState();
}

class _TvNotificationsScreenState extends State<TvNotificationsScreen> {
  List<NotificationItem> _items = const [];
  int _unreadCount = 0;
  bool _loading = true;
  bool _markingAll = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<TvApiService>();
      final items = await api.getNotifications();
      final unread = await api.getUnreadNotificationCount();
      if (!mounted) return;
      setState(() {
        _items = items;
        _unreadCount = unread;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await context.read<TvApiService>().markAllNotificationsAsRead();
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (item) => NotificationItem(
                id: item.id,
                title: item.title,
                message: item.message,
                isRead: true,
                type: item.type,
                createdAt: item.createdAt,
              ),
            )
            .toList();
        _unreadCount = 0;
        _markingAll = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _markingAll = false;
      });
    }
  }

  Future<void> _markOneRead(NotificationItem item) async {
    if (item.isRead) return;
    try {
      await context.read<TvApiService>().markNotificationAsRead(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (entry) => entry.id == item.id
                  ? NotificationItem(
                      id: entry.id,
                      title: entry.title,
                      message: entry.message,
                      isRead: true,
                      type: entry.type,
                      createdAt: entry.createdAt,
                    )
                  : entry,
            )
            .toList();
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Notifications',
      subtitle: 'See your latest Family Academy updates on the TV and clear unread items without reaching for the phone.',
      actions: _Badge(label: 'Unread $_unreadCount'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!)
              : Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 240,
                          child: TvFocusCard(
                            onPressed: _markingAll ? () {} : _markAllRead,
                            child: Center(
                              child: Text(
                                _markingAll ? 'Working...' : 'Mark All Read',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 180,
                          child: TvFocusCard(
                            onPressed: _load,
                            child: const Center(
                              child: Text(
                                'Refresh',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _items.isEmpty
                          ? const _EmptyState(
                              title: 'No notifications yet',
                              message: 'When new updates arrive, they will appear here.',
                            )
                          : ListView.separated(
                              itemCount: _items.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return TvFocusCard(
                                  autofocus: index == 0,
                                  onPressed: () => _markOneRead(item),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 14,
                                        height: 14,
                                        margin: const EdgeInsets.only(top: 8),
                                        decoration: BoxDecoration(
                                          color: item.isRead
                                              ? Colors.transparent
                                              : const Color(0xFF77B7FF),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: item.isRead
                                                ? Colors.white24
                                                : const Color(0xFF77B7FF),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: item.isRead
                                                    ? FontWeight.w700
                                                    : FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              item.message,
                                              style: const TextStyle(
                                                color: Color(0xFFD6E1F6),
                                                fontSize: 15,
                                                height: 1.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          _Badge(label: item.isRead ? 'Read' : 'Unread'),
                                          if (item.createdAt != null) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              _formatDate(item.createdAt!),
                                              style: const TextStyle(
                                                color: Color(0xFF9EB3D8),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}

class TvExamsScreen extends StatefulWidget {
  const TvExamsScreen({super.key});

  @override
  State<TvExamsScreen> createState() => _TvExamsScreenState();
}

class _TvExamsScreenState extends State<TvExamsScreen> {
  late Future<List<ExamItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TvApiService>().getAvailableExams();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Exams',
      subtitle: 'See every available exam from your active learning path and open the related course content from the TV.',
      child: FutureBuilder<List<ExamItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: 'Could not load exams.\n${snapshot.error}');
          }
          final exams = snapshot.data ?? const <ExamItem>[];
          if (exams.isEmpty) {
            return const _EmptyState(
              title: 'No exams available',
              message: 'When exams are released for your courses, they will appear here.',
            );
          }
          return ListView.separated(
            itemCount: exams.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final exam = exams[index];
              return TvFocusCard(
                autofocus: index == 0,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExamSessionScreen(exam: exam),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: const Color(0xFF17385D),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 34),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              if (exam.courseName?.isNotEmpty == true) exam.courseName!,
                              if (exam.categoryName?.isNotEmpty == true) exam.categoryName!,
                            ].join(' • '),
                            style: const TextStyle(
                              color: Color(0xFFB7C6E3),
                              fontSize: 15,
                            ),
                          ),
                          if (exam.description?.isNotEmpty == true) ...[
                            const SizedBox(height: 8),
                            Text(
                              exam.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFF9DB1D7)),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _Badge(label: '${exam.questionCount} questions'),
                        const SizedBox(height: 10),
                        _Badge(label: '${exam.durationMinutes} min'),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TvChatbotScreen extends StatefulWidget {
  const TvChatbotScreen({super.key});

  @override
  State<TvChatbotScreen> createState() => _TvChatbotScreenState();
}

class _TvChatbotScreenState extends State<TvChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  List<ChatbotConversationItem> _conversations = const [];
  List<ChatbotMessageItem> _messages = const [];
  Map<String, dynamic> _usage = const {};
  int? _selectedConversationId;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<TvApiService>();
      final usage = await api.getChatbotUsage();
      final conversations = await api.getChatbotConversations();
      List<ChatbotMessageItem> messages = const [];
      int? conversationId;
      if (conversations.isNotEmpty) {
        conversationId = conversations.first.id;
        messages = await api.getChatbotConversationMessages(conversationId);
      }
      if (!mounted) return;
      setState(() {
        _usage = usage;
        _conversations = conversations;
        _selectedConversationId = conversationId;
        _messages = messages;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openConversation(int conversationId) async {
    setState(() {
      _selectedConversationId = conversationId;
      _loading = true;
    });
    try {
      final messages = await context.read<TvApiService>().getChatbotConversationMessages(conversationId);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final optimistic = ChatbotMessageItem(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: text,
    );

    setState(() {
      _sending = true;
      _messages = [..._messages, optimistic];
      _error = null;
    });

    try {
      final api = context.read<TvApiService>();
      final data = await api.sendChatbotMessage(
            text,
            conversationId: _selectedConversationId,
          );
      _controller.clear();
      final conversationId = (data['conversation_id'] as num?)?.toInt() ??
          (data['conversation']?['id'] as num?)?.toInt();
      final assistantText = data['message']?.toString() ??
          data['reply']?.toString() ??
          data['assistant_message']?.toString() ??
          '';

      final refreshedConversations = await api.getChatbotConversations();

      if (!mounted) return;
      setState(() {
        _conversations = refreshedConversations;
        if (conversationId != null) {
          _selectedConversationId = conversationId;
        }
        if (assistantText.isNotEmpty) {
          _messages = [
            ..._messages,
            ChatbotMessageItem(
              id: DateTime.now().millisecondsSinceEpoch + 1,
              role: 'assistant',
              content: assistantText,
            ),
          ];
        }
        _sending = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to process this message.';
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Family Academy AI',
      subtitle: 'Ask quick learning questions, revise topics, and continue your saved conversations from the TV.',
      actions: _usage.isEmpty
          ? null
          : _Badge(
              label:
                  'Used ${( _usage['used_today'] ?? _usage['messages_used'] ?? 0).toString()} / ${( _usage['daily_limit'] ?? 0).toString()} today',
            ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _messages.isEmpty && _conversations.isEmpty
              ? _ErrorState(message: _error!)
              : Row(
                  children: [
                    SizedBox(
                      width: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Conversations',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: _conversations.isEmpty
                                ? const _EmptyState(
                                    title: 'No conversations yet',
                                    message: 'Start a new message on the right and the chat will be saved here.',
                                  )
                                : ListView.separated(
                                    itemCount: _conversations.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final item = _conversations[index];
                                      return TvFocusCard(
                                        autofocus: index == 0,
                                        onPressed: () => _openConversation(item.id),
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: _selectedConversationId == item.id
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                            if (item.updatedAt != null) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                _formatDateTime(item.updatedAt!),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFF8EA3C7),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A152A),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: _messages.isEmpty
                                  ? const _EmptyState(
                                      title: 'Start asking',
                                      message: 'Use the message field below to ask Family Academy AI something useful.',
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.all(20),
                                      itemCount: _messages.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final message = _messages[index];
                                        final align = message.isUser
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start;
                                        final bubbleColor = message.isUser
                                            ? const Color(0xFF1B5DBA)
                                            : const Color(0xFF1A2439);
                                        return Column(
                                          crossAxisAlignment: align,
                                          children: [
                                            Container(
                                              constraints: const BoxConstraints(maxWidth: 860),
                                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                              decoration: BoxDecoration(
                                                color: bubbleColor,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                message.content,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  height: 1.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _inputFocusNode,
                                  onSubmitted: (_) => _sendMessage(),
                                  style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.45),
                                  minLines: 2,
                                  maxLines: 4,
                                  decoration: InputDecoration(
                                    hintText: 'Ask anything...',
                                    hintStyle: const TextStyle(color: Color(0xFF8EA3C7)),
                                    filled: true,
                                    fillColor: const Color(0xFF101C34),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 150,
                                child: TvFocusCard(
                                  onPressed: _sendMessage,
                                  child: Center(
                                    child: Text(
                                      _sending ? 'Sending...' : 'Send',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Color(0xFFFFB8B8)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class TvProgressScreen extends StatefulWidget {
  const TvProgressScreen({super.key});

  @override
  State<TvProgressScreen> createState() => _TvProgressScreenState();
}

class _TvProgressScreenState extends State<TvProgressScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TvApiService>().getOverallProgress();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Progress',
      subtitle: 'Keep an eye on chapters, questions, study time, and overall learning momentum.',
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: 'Could not load progress.\n${snapshot.error}');
          }
          final data = snapshot.data ?? const <String, dynamic>{};
          final statsData = Map<String, dynamic>.from(
            (data['stats'] as Map?)?.cast<dynamic, dynamic>() ?? const <dynamic, dynamic>{},
          );
          final stats = <_StatItem>[
            _StatItem(
              'Completion',
              _formatPercent(
                statsData['overall_completion_percentage'] ??
                    statsData['completion_percentage'] ??
                    data['overall_completion_percentage'],
              ),
            ),
            _StatItem('Chapters done', '${_asInt(statsData['chapters_completed'])}'),
            _StatItem('Videos watched', '${_asInt(statsData['videos_completed'])}'),
            _StatItem('Notes viewed', '${_asInt(statsData['total_notes_viewed'])}'),
            _StatItem('Questions attempted', '${_asInt(statsData['total_questions_attempted'])}'),
            _StatItem('Study time', _formatHours(statsData['study_time_hours'])),
          ];
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1200 ? 3 : 2;

              return ListView(
                padding: const EdgeInsets.only(bottom: 8),
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: crossAxisCount == 3 ? 1.55 : 1.75,
                    ),
                    itemCount: stats.length,
                    itemBuilder: (context, index) {
                      final item = stats[index];
                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111D35),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9CB1D8),
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              item.value,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (statsData.isNotEmpty || data.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111D35),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Text(
                        'This progress is shared with the main student app, so your videos, notes, practice, and other learning activity should stay in sync.',
                        style: const TextStyle(
                          color: Color(0xFFD3DEF4),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class TvSubscriptionsScreen extends StatefulWidget {
  const TvSubscriptionsScreen({super.key});

  @override
  State<TvSubscriptionsScreen> createState() => _TvSubscriptionsScreenState();
}

class _TvSubscriptionsScreenState extends State<TvSubscriptionsScreen> {
  late Future<List<SubscriptionItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TvApiService>().getMySubscriptions();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Subscriptions',
      subtitle: 'Review active and expired access on the TV without going back to the phone.',
      child: FutureBuilder<List<SubscriptionItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: 'Could not load subscriptions.\n${snapshot.error}');
          }
          final items = snapshot.data ?? const <SubscriptionItem>[];
          if (items.isEmpty) {
            return const _EmptyState(
              title: 'No subscriptions yet',
              message: 'Your category access and renewal status will appear here.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF111D35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: item.isActive ? const Color(0xFF184B35) : const Color(0xFF4A2727),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        item.isActive ? Icons.verified_rounded : Icons.history_toggle_off_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.categoryName ?? 'Subscription',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            [
                              item.billingCycle ?? '',
                              if (item.startDate != null) 'Started ${_formatDate(item.startDate!)}',
                              if (item.endDate != null) 'Ends ${_formatDate(item.endDate!)}',
                            ].where((part) => part.isNotEmpty).join(' • '),
                            style: const TextStyle(color: Color(0xFFABC0E4), fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    _Badge(label: item.status.toUpperCase()),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TvParentLinkScreen extends StatefulWidget {
  const TvParentLinkScreen({super.key});

  @override
  State<TvParentLinkScreen> createState() => _TvParentLinkScreenState();
}

class _TvParentLinkScreenState extends State<TvParentLinkScreen> {
  ParentLinkItem? _status;
  Map<String, String> _settings = const {};
  bool _loading = true;
  bool _busy = false;
  String? _generatedToken;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<TvApiService>();
      final status = await api.getParentLinkStatus();
      final settings = await api.getPublicSettings();
      if (!mounted) return;
      setState(() {
        _status = status;
        _settings = settings;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final data = await context.read<TvApiService>().generateParentToken();
      if (!mounted) return;
      setState(() {
        _generatedToken = data['token']?.toString() ?? data['parent_token']?.toString();
        _busy = false;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  Future<void> _unlink() async {
    setState(() => _busy = true);
    try {
      await context.read<TvApiService>().unlinkParent();
      if (!mounted) return;
      setState(() {
        _generatedToken = null;
        _busy = false;
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Parent Link',
      subtitle: 'Generate and manage the parent connection from the TV without opening the TV pairing flow.',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!)
              : ListView(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111D35),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _settings['parent_link_title'] ?? 'Bring a parent into the journey',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _settings['parent_link_description'] ??
                                'Generate a secure code and connect your parent to the Family Academy Telegram assistant.',
                            style: const TextStyle(color: Color(0xFFD4DEF3), fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                          if (_status?.isLinked == true)
                            _Badge(label: _settings['parent_link_live_badge'] ?? 'Live')
                          else
                            const _Badge(label: 'Not linked'),
                          if (_status?.isLinked == true &&
                              (_status?.parentName?.isNotEmpty == true ||
                                  _status?.parentTelegramUsername?.isNotEmpty == true)) ...[
                            const SizedBox(height: 14),
                            Text(
                              [
                                if (_status?.parentName?.isNotEmpty == true) _status!.parentName!,
                                if (_status?.parentTelegramUsername?.isNotEmpty == true)
                                  '@${_status!.parentTelegramUsername!}',
                              ].join(' • '),
                              style: const TextStyle(
                                color: Color(0xFFD4DEF3),
                                fontSize: 15,
                              ),
                            ),
                          ],
                          if (_generatedToken?.isNotEmpty == true) ...[
                            const SizedBox(height: 16),
                            SelectableText(
                              _generatedToken!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                          if (_status?.token?.isNotEmpty == true && _generatedToken == null) ...[
                            const SizedBox(height: 16),
                            SelectableText(
                              _status!.token!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                          if ((_generatedToken?.isNotEmpty == true ||
                                  _status?.token?.isNotEmpty == true) &&
                              _status?.expiresAt != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Code expires ${_formatDateTime(_status!.expiresAt!)}',
                              style: const TextStyle(
                                color: Color(0xFF9FB3D7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: TvFocusCard(
                            onPressed: _busy ? () {} : _generate,
                            child: Center(
                              child: Text(
                                _busy ? 'Working...' : 'Generate Code',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 220,
                          child: TvFocusCard(
                            onPressed: _busy || _status?.isLinked != true ? () {} : _unlink,
                            backgroundColor: _status?.isLinked == true
                                ? const Color(0xFF142039)
                                : const Color(0xFF0C1424),
                            child: Center(
                              child: Text(
                                'Unlink Parent',
                                style: TextStyle(
                                  color: _status?.isLinked == true
                                      ? Colors.white
                                      : Colors.white38,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111D35),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _settings['parent_link_bot_title'] ?? 'Parent Telegram assistant',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _settings['parent_link_bot_description'] ??
                                'Once linked, parents can open the bot anytime to view a polished child snapshot, recent activity, exams, and payment access updates.',
                            style: const TextStyle(color: Color(0xFFD4DEF3), fontSize: 15, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            _settings['parent_telegram_bot_url'] ??
                                _settings['support_telegram_url'] ??
                                'https://t.me/FamilyAcademy_notify_Bot',
                            style: const TextStyle(color: Color(0xFF8FC8FF), fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

class TvSupportScreen extends StatefulWidget {
  const TvSupportScreen({super.key});

  @override
  State<TvSupportScreen> createState() => _TvSupportScreenState();
}

class _TvSupportScreenState extends State<TvSupportScreen> {
  late Future<Map<String, String>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TvApiService>().getPublicSettings();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Support',
      subtitle: 'TV-friendly support details and FAQ pulled from your live settings.',
      child: FutureBuilder<Map<String, String>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: 'Could not load support info.\n${snapshot.error}');
          }
          final settings = snapshot.data ?? const <String, String>{};
          final faqs = <MapEntry<String, String>>[
            MapEntry(
              'Account access help',
              settings['support_faq_password_answer'] ??
                  'If you need help with account access, please contact support so an administrator can assist you.',
            ),
            MapEntry(
              'Payment methods',
              settings['support_faq_payment_methods_answer'] ??
                  'We accept Telebirr, bank transfer, and other enabled local payment methods.',
            ),
            MapEntry(
              'Offline access',
              settings['support_faq_offline_access_answer'] ??
                  'Videos and notes can be available offline, and your progress syncs later.',
            ),
          ];
          return ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111D35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings['support_screen_title'] ?? 'Support',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      settings['support_screen_subtitle'] ??
                          'Reach support and browse common answers without leaving the TV.',
                      style: const TextStyle(color: Color(0xFFD4DEF3), fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 14),
                    SelectableText(
                      settings['support_telegram_url'] ?? 'https://t.me/FamilyAcademySupport',
                      style: const TextStyle(color: Color(0xFF8FC8FF), fontSize: 17),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...faqs.map(
                (faq) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111D35),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          faq.key,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          faq.value,
                          style: const TextStyle(color: Color(0xFFD4DEF3), fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TvProfileScreen extends StatefulWidget {
  const TvProfileScreen({super.key});

  @override
  State<TvProfileScreen> createState() => _TvProfileScreenState();
}

class _TvProfileScreenState extends State<TvProfileScreen> {
  late Future<TvUser> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<TvApiService>().getMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionPane(
      title: 'Profile',
      subtitle: 'Your current student profile, available on the TV without editing account auth screens.',
      child: FutureBuilder<TvUser>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: 'Could not load profile.\n${snapshot.error}');
          }
          final user = snapshot.data;
          if (user == null) {
            return const _EmptyState(
              title: 'No profile data',
              message: 'Profile information is not available right now.',
            );
          }
          return Row(
            children: [
              Container(
                width: 220,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111D35),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF1C355A),
                      backgroundImage: user.profileImage?.isNotEmpty == true
                          ? NetworkImage(user.profileImage!)
                          : null,
                      child: user.profileImage?.isNotEmpty == true
                          ? null
                          : Text(
                              user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                            ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      user.username,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: ListView(
                  children: [
                    _ProfileInfoCard(label: 'Username', value: user.username),
                    const SizedBox(height: 14),
                    _ProfileInfoCard(label: 'Email', value: user.email?.isNotEmpty == true ? user.email! : 'Not set'),
                    const SizedBox(height: 14),
                    _ProfileInfoCard(label: 'Account status', value: user.accountStatus),
                    const SizedBox(height: 14),
                    _ProfileInfoCard(label: 'School ID', value: user.schoolId?.toString() ?? 'Not set'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111D35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 180,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF9CB1D8), fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12 : 14,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_rounded, color: Color(0xFF88A4D1), size: 72),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB7C8E5), fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 18, height: 1.5),
        ),
      ),
    );
  }
}

class _LetterFallback extends StatelessWidget {
  const _LetterFallback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF16304F),
      alignment: Alignment.center,
      child: Text(
        text.isNotEmpty ? text.substring(0, 1).toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatItem {
  const _StatItem(this.label, this.value);

  final String label;
  final String value;
}

String _formatPercent(dynamic value) {
  final number = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
  if (number <= 1) {
    return '${(number * 100).toStringAsFixed(0)}%';
  }
  return '${number.toStringAsFixed(0)}%';
}

String _formatHours(dynamic value) {
  final hours = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;
  if (hours <= 0) return '0 h';
  if (hours < 1) {
    return '${(hours * 60).round()} min';
  }
  if (hours == hours.roundToDouble()) {
    return '${hours.toStringAsFixed(0)} h';
  }
  return '${hours.toStringAsFixed(1)} h';
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatDateTime(DateTime date) {
  final minute = date.minute.toString().padLeft(2, '0');
  final hour = date.hour.toString().padLeft(2, '0');
  return '${_formatDate(date)} $hour:$minute';
}
