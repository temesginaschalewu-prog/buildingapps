import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chatbot_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/empty_state.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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

  // In lib/screens/main/chatbot_screen.dart, update the _sendMessage method:

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Add user message
    setState(() {
      _messages.add({
        'text': message,
        'isUser': true,
        'timestamp': DateTime.now(),
      });
    });
    _messageController.clear();
    _scrollToBottom();

    // Get AI response
    final chatbotProvider =
        Provider.of<ChatbotProvider>(context, listen: false);

    try {
      final response = await chatbotProvider.sendMessage(message);

      setState(() {
        _messages.add({
          'text': response,
          'isUser': false,
          'timestamp': DateTime.now(),
        });
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({
          'text':
              'I encountered an error. Please try again or check your connection.',
          'isUser': false,
          'isError': true,
          'timestamp': DateTime.now(),
        });
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final chatbotProvider = Provider.of<ChatbotProvider>(context);

    // Check if user has access to chatbot
    if (authProvider.user?.accountStatus != 'active') {
      return Scaffold(
        appBar: AppBar(title: const Text('Chatbot')),
        body: const EmptyState(
          icon: Icons.chat,
          title: 'Chatbot Unavailable',
          message: 'Chatbot is available for active subscribers only.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${chatbotProvider.messagesUsedToday}/10',
                  style: const TextStyle(fontSize: 12),
                ),
                const Text(
                  'messages today',
                  style: TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'No Messages',
                    message: 'Start a conversation with the chatbot!',
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message['isUser'] == true) const Spacer(),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: message['isUser'] == true
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.1)
                                      : message['isError'] == true
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.grey
                                              .shade100, // Fixed: Changed Colors.grey[100] to Colors.grey.shade100
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: message['isUser'] == true
                                        ? Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.3)
                                        : message['isError'] == true
                                            ? Colors.red.withOpacity(0.3)
                                            : Colors.grey
                                                .shade300, // Fixed: Changed Colors.grey[300] to Colors.grey.shade300
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message['text'],
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${message['timestamp'].hour}:${message['timestamp'].minute.toString().padLeft(2, '0')}', // Fixed: Added padding for minutes
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Colors.grey,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (message['isUser'] != true) const Spacer(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: chatbotProvider.hasMessagesLeft
                          ? 'Ask an educational question...'
                          : 'Daily limit reached',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: chatbotProvider.hasMessagesLeft
                          ? Theme.of(context).colorScheme.surface
                          : Colors.grey.shade200,
                    ),
                    enabled: chatbotProvider.hasMessagesLeft,
                    maxLines: 3,
                    minLines: 1,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      chatbotProvider.hasMessagesLeft ? _sendMessage : null,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
