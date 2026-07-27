import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/conversation.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/message_bubble.dart';
import 'package:flutter/services.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final chat = context.read<ChatProvider>();

      if (chat.conversations.isEmpty) {
        chat.loadConversations();
      }

      if (chat.activeConversation == null && !_hasInitialized) {
        _hasInitialized = true;
        chat.createNewConversation();
      }
    });
  }

  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     final chat = context.read<ChatProvider>();
  //     chat.loadConversations();
  //     if (chat.activeConversation == null && !_hasInitialized) {
  //       _hasInitialized = true;
  //       chat.createNewConversation();
  //     }
  //   });
  // }
  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();

    super.dispose();
  }
  // @override
  // void dispose() {
  //   _scrollController.dispose();
  //   _inputController.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final showWelcome =
        !chat.isLoadingConversation &&
        chat.activeConversation != null &&
        !_hasUserMessages(chat.activeConversation);

    // WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    if (chat.activeConversation?.messages.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }

    final drawer = ConversationDrawer(
      conversations: chat.conversations,
      isLoading: chat.isLoadingConversations,
      selectedConversationId: chat.activeConversation?.id,
      onNewChat: () async {
        await chat.createNewConversation();
        if (!context.mounted) return;
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      // onSelect: (id) {
      //   chat.selectConversation(id);
      //   if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      // },
      onSelect: (id) async {
        await chat.selectConversation(id);

        if (!context.mounted) return;

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      onDelete: (id) async {
        await chat.deleteConversation(id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Conversation removed')));
      },
      onLogout: () async {
        await auth.logout();
        if (!context.mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      },
    );

    // return Scaffold(
    //   backgroundColor: AppTheme.deepBackground,
    //   appBar: AppBar(
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.deepBackground,
        appBar: AppBar(
          toolbarHeight: 68,
          title: const _BrandTitle(),
          // actions: [
          //   Builder(
          //     builder: (context) => IconButton(
          //       tooltip: 'Conversations',
          //       onPressed: () => Scaffold.of(context).openDrawer(),
          //       icon: const Icon(Icons.menu_rounded),
          //     ),
          //   ),
          //   const SizedBox(width: 8),
          // ],
        ),
        drawer: drawer,
        body: SafeArea(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF8FAFC), Color(0xFFEEF4FF)],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1050;
                return Row(
                  children: [
                    if (isDesktop)
                      SizedBox(
                        width: 280,
                        child: _DesktopSidebar(child: drawer),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 380),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                              child: showWelcome
                                  ? _WelcomeView(
                                      key: const ValueKey('welcome'),
                                      controller: _inputController,
                                      chat: chat,
                                      onSend: () => _sendMessage(chat),
                                    )
                                  : _ConversationView(
                                      key: const ValueKey('conversation'),
                                      controller: _scrollController,
                                      chat: chat,
                                    ),
                            ),
                          ),
                          if (!showWelcome)
                            ChatInputBar(
                              controller: _inputController,
                              isStreaming: chat.isStreaming,
                              onChanged: chat.setDraft,
                              onSend: () => _sendMessage(chat),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // Future<void> _sendMessage(ChatProvider chat) async {
  //   if (_inputController.text.trim().isEmpty) return;
  //   chat.setDraft(_inputController.text);
  //   _inputController.clear();
  //   await chat.sendMessage();
  // }
  Future<void> _sendMessage(ChatProvider chat) async {
    final text = _inputController.text.trim();

    if (text.isEmpty || chat.isStreaming) return;

    _inputController.clear();

    chat.setDraft(text);

    await chat.sendMessage();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  bool _hasUserMessages(Conversation? conversation) =>
      conversation?.messages.any((message) => message.role == 'user') ?? false;
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final showSubtitle = MediaQuery.of(context).size.width > 360;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            'assets/images/nova_logo.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nova AI',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (showSubtitle) ...[
              const SizedBox(height: 1),
              const Text(
                'Powered by Groq',
                style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// class _BrandTitle extends StatelessWidget {
//   const _BrandTitle();

//   @override
//   Widget build(BuildContext context) => Row(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//       ClipRRect(
//         borderRadius: BorderRadius.circular(8),
//         child: Image.asset(
//           'assets/images/nova_logo.png',
//           width: 34,
//           height: 34,
//           fit: BoxFit.cover,
//         ),
//       ),
//       const SizedBox(width: 10),
//       const Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             'Nova AI',
//             style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
//           ),
//           SizedBox(height: 1),
//           Text(
//             'Powered by Groq',
//             style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
//           ),
//         ],
//       ),
//     ],
//   );
// }
//       DecoratedBox(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: [Color(0xFF6576E8), Color(0xFF9A83DD)],
//           ),
//           shape: BoxShape.circle,
//         ),
//         child: SizedBox(
//           width: 30,
//           height: 30,
//           child: Icon(
//             Icons.auto_awesome_rounded,
//             color: Colors.white,
//             size: 16,
//           ),
//         ),
//       ),
//       SizedBox(width: 10),
//       Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             'Nova AI',
//             style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
//           ),
//           SizedBox(height: 1),
//           Text(
//             'Powered by Groq',
//             style: TextStyle(fontSize: 11, color: AppTheme.mutedText),
//           ),
//         ],
//       ),
//     ],
//   );
// }

class _DesktopSidebar extends StatelessWidget {
  final Widget child;
  const _DesktopSidebar({required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(right: BorderSide(color: AppTheme.border)),
    ),
    child: child,
  );
}

class _WelcomeView extends StatelessWidget {
  final TextEditingController controller;
  final ChatProvider chat;
  final VoidCallback onSend;

  const _WelcomeView({
    super.key,
    required this.controller,
    required this.chat,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final username =
        context.read<AuthProvider>().user?['username']?.toString() ?? 'there';
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          constraints.maxWidth < 380 ? 14 : 24,
          constraints.maxHeight > 680 ? 48 : 28,
          constraints.maxWidth < 380 ? 14 : 24,
          36,
        ),
        // padding: EdgeInsets.fromLTRB(
        //   24,
        //   constraints.maxHeight > 680 ? 48 : 28,
        //   24,
        //   36,
        // ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: [
                _Greeting(username: username),
                const SizedBox(height: 32),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ChatInputBar(
                    controller: controller,
                    isStreaming: chat.isStreaming,
                    onChanged: chat.setDraft,
                    onSend: onSend,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 38),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Explore ideas',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _SuggestionGrid(
                  onSelected: (prompt) {
                    controller.text = prompt;
                    chat.setDraft(prompt);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String username;
  const _Greeting({required this.username});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final fontSize = width < 380
        ? 22.0
        : width < 600
        ? 26.0
        : 30.0;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 18
        ? 'Good Afternoon'
        : 'Good Evening';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - value)),
          child: child,
        ),
      ),
      child: Column(
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF6075DE), Color(0xFF9A7DDB)],
            ).createShader(bounds),
            child: Text(
              '$greeting, $username',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'How can I help you today?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.mutedText),
          ),
        ],
      ),
    );
  }
}

// class _Greeting extends StatelessWidget {
//   final String username;
//   const _Greeting({required this.username});

//   @override
//   Widget build(BuildContext context) {
//     final hour = DateTime.now().hour;
//     final greeting = hour < 12
//         ? 'Good Morning'
//         : hour < 18
//         ? 'Good Afternoon'
//         : 'Good Evening';
//     return TweenAnimationBuilder<double>(
//       tween: Tween(begin: 0, end: 1),
//       duration: const Duration(milliseconds: 600),
//       curve: Curves.easeOutCubic,
//       builder: (context, value, child) => Opacity(
//         opacity: value,
//         child: Transform.translate(
//           offset: Offset(0, 12 * (1 - value)),
//           child: child,
//         ),
//       ),
//       child: Column(
//         children: [
//           ShaderMask(
//             blendMode: BlendMode.srcIn,
//             shaderCallback: (bounds) => const LinearGradient(
//               colors: [Color(0xFF6075DE), Color(0xFF9A7DDB)],
//             ).createShader(bounds),
//             child: Text(
//               '$greeting, $username',
//               textAlign: TextAlign.center,
//               style: Theme.of(context).textTheme.headlineMedium?.copyWith(
//                 fontWeight: FontWeight.w700,
//                 letterSpacing: -1.1,
//               ),
//             ),
//           ),
//           const SizedBox(height: 10),
//           Text(
//             'How can I help you today?',
//             style: Theme.of(
//               context,
//             ).textTheme.titleMedium?.copyWith(color: AppTheme.mutedText),
//           ),
//         ],
//       ),
//     );
//   }
// }

class _ConversationView extends StatelessWidget {
  final ScrollController controller;
  final ChatProvider chat;
  const _ConversationView({
    super.key,
    required this.controller,
    required this.chat,
  });

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: controller,
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
    itemCount:
        (chat.activeConversation?.messages.length ?? 0) +
        (chat.showTypingIndicator ? 1 : 0),
    itemBuilder: (context, index) {
      final messages = chat.activeConversation?.messages ?? const [];
      if (chat.showTypingIndicator && index == messages.length) {
        return const _ThinkingIndicator();
      }
      final message = messages[index];
      return MessageBubble(
        message: message,
        isStreaming:
            chat.isStreaming &&
            message.role == 'assistant' &&
            message.content.isEmpty,
      );
    },
  );
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    child: Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.accent,
          ),
        ),
        SizedBox(width: 12),
        Text('Nova is thinking…', style: TextStyle(color: AppTheme.mutedText)),
      ],
    ),
  );
}

class _SuggestionGrid extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _SuggestionGrid({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    const suggestions = [
      (
        '🚀',
        'Plan a Launch',
        'Shape a roadmap with clear milestones.',
        'Plan a launch strategy for my product with milestones and risks.',
        Color(0xFF7F5AF0),
        Color(0xFF22D3EE),
      ),
      (
        '💻',
        'Generate Code',
        'Create clean Flutter, Python or Django code.',
        'Generate Flutter code for a polished modern dashboard.',
        Color(0xFF3B82F6),
        Color(0xFF06B6D4),
      ),
      (
        '📝',
        'Write Content',
        'Create blogs, emails and articles.',
        'Write a compelling blog post about AI productivity.',
        Color(0xFFF97316),
        Color(0xFFEC4899),
      ),
      (
        '🧠',
        'Brainstorm Ideas',
        'Generate creative ideas.',
        'Brainstorm fresh ideas for a modern AI assistant experience.',
        Color(0xFF10B981),
        Color(0xFF14B8A6),
      ),
      (
        '📚',
        'Explain Anything',
        'Understand difficult concepts simply.',
        'Explain this concept in simple, practical terms.',
        Color(0xFF6366F1),
        Color(0xFF8B5CF6),
      ),
      (
        '🐞',
        'Debug Code',
        'Find and fix bugs.',
        'Help me debug this issue and suggest a robust fix.',
        Color(0xFFEF4444),
        Color(0xFFF59E0B),
      ),
      (
        '📊',
        'Analyze Data',
        'Summarize charts and datasets.',
        'Analyze this data and summarize the key insights.',
        Color(0xFF06B6D4),
        Color(0xFF3B82F6),
      ),
      (
        '✨',
        'Improve Writing',
        'Refine grammar and style.',
        'Improve this writing for clarity, tone, and polish.',
        Color(0xFFEC4899),
        Color(0xFF8B5CF6),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1000
            ? 4
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: suggestions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: count == 1 ? 2.6 : 2.2,
            // childAspectRatio: count == 1 ? 3.2 : 2.6,
          ),
          // return GridView.builder(
          //   shrinkWrap: true,
          //   physics: const NeverScrollableScrollPhysics(),
          //   itemCount: suggestions.length,
          //   gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          //     crossAxisCount: count,
          //     crossAxisSpacing: 20,
          //     mainAxisSpacing: 20,
          //     mainAxisExtent: 120,
          //   ),
          itemBuilder: (context, index) {
            final item = suggestions[index];
            return _SuggestionCard(
              icon: item.$1,
              title: item.$2,
              description: item.$3,
              colors: [item.$5, item.$6],
              onTap: () => onSelected(item.$4),
            );
          },
        );
      },
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final String icon;
  final String title;
  final String description;
  final List<Color> colors;
  final VoidCallback onTap;
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.colors,
    required this.onTap,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: _hovered ? 1.02 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -5 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF344569,
              ).withValues(alpha: _hovered ? .12 : .055),
              blurRadius: _hovered ? 20 : 10,
              offset: Offset(0, _hovered ? 10 : 5),
            ),
            if (_hovered)
              BoxShadow(
                color: widget.colors.first.withValues(alpha: .10),
                blurRadius: 18,
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.colors.first.withValues(alpha: .16),
                          widget.colors.last.withValues(alpha: .42),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      widget.icon,
                      style: const TextStyle(fontSize: 19),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      color: AppTheme.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 12.5,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
