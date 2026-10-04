import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/aurora_effects.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/conversation_drawer.dart';
import '../widgets/message_bubble.dart';

const _desktopBreakpoint = 1050.0;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _hasInitialized = false;
  bool _dragging = false;
  late final ChatProvider _chat;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>();
    _chat.addListener(_showChatError);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final chat = _chat;

      if (chat.conversations.isEmpty) {
        chat.loadConversations();
      }

      if (chat.activeConversation == null && !_hasInitialized) {
        _hasInitialized = true;
        chat.createNewConversation();
      }
    });
  }

  @override
  void dispose() {
    _chat.removeListener(_showChatError);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _showChatError() {
    final error = _chat.errorMessage;
    if (error == _lastShownError) return;
    _lastShownError = error;
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.replaceFirst('Exception: ', ''))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final auth = context.watch<AuthProvider>();
    final isDesktop = MediaQuery.sizeOf(context).width >= _desktopBreakpoint;
    final showWelcome =
        !chat.isLoadingConversation &&
        chat.activeConversation != null &&
        !_hasUserMessages(chat.activeConversation);

    if (chat.activeConversation?.messages.isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }

    final sidebar = ConversationDrawer(
      conversations: chat.conversations,
      isLoading: chat.isLoadingConversations,
      selectedConversationId: chat.activeConversation?.id,
      username: auth.user?['username']?.toString() ?? '',
      email: auth.user?['email']?.toString(),
      onNewChat: () async {
        _closeDrawer();
        await chat.createNewConversation();
      },
      onSelect: (id) async {
        _closeDrawer();
        await chat.selectConversation(id);
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
        chat.reset();
        if (!context.mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      },
    );

    final main = Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: showWelcome
                ? _WelcomeView(
                    key: const ValueKey('welcome'),
                    controller: _inputController,
                    chat: chat,
                    username: auth.user?['username']?.toString() ?? 'there',
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
            onStop: chat.stopStreaming,
            attachments: chat.pendingAttachments,
            onAddFiles: chat.addAttachments,
            onRemoveAttachment: chat.removeAttachment,
            thinkLonger: chat.thinkLonger,
            onThinkLongerChanged: chat.setThinkLonger,
            responseStyle: chat.responseStyle,
            onResponseStyleChanged: chat.setResponseStyle,
          ),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppTheme.background,
        appBar: isDesktop
            ? null
            : AppBar(
                backgroundColor: AppTheme.background,
                toolbarHeight: 60,
                centerTitle: true,
                leading: IconButton(
                  tooltip: 'Conversations',
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
                title: Text('Nova', style: AppTheme.display(17)),
                actions: [
                  IconButton(
                    tooltip: 'New chat',
                    onPressed: chat.createNewConversation,
                    icon: const Icon(Icons.edit_square, size: 21),
                  ),
                  const SizedBox(width: 4),
                ],
                shape: const Border(
                  bottom: BorderSide(color: Color(0xFF0E2A31)),
                ),
              ),
        drawer: isDesktop ? null : Drawer(width: 300, child: sidebar),
        body: AuroraBackground(
          child: SafeArea(
            child: isDesktop
                ? Row(
                    children: [
                      Container(
                        width: 280,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        child: sidebar,
                      ),
                      Expanded(child: _dropZone(chat, main)),
                    ],
                  )
                : _dropZone(chat, main),
          ),
        ),
      ),
    );
  }

  /// Lets users drag files from their computer onto the chat (desktop / web).
  Widget _dropZone(ChatProvider chat, Widget child) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        final files = <({String name, Uint8List bytes})>[];
        for (final item in details.files) {
          if (item is DropItemDirectory) continue;
          files.add((name: item.name, bytes: await item.readAsBytes()));
        }
        if (files.isNotEmpty) await chat.addAttachments(files);
      },
      // StackFit.expand: the chat must keep filling the whole area; a loose
      // Stack would shrink it and push the composer off-centre.
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (_dragging) const Positioned.fill(child: _DropOverlay()),
        ],
      ),
    );
  }

  void _closeDrawer() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
  }

  Future<void> _sendMessage(ChatProvider chat) async {
    final text = _inputController.text.trim();
    final hasFiles = chat.pendingAttachments.any((a) => a.isReady);

    if ((text.isEmpty && !hasFiles) || chat.isStreaming || chat.isUploading) {
      return;
    }

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

class _WelcomeView extends StatelessWidget {
  final TextEditingController controller;
  final ChatProvider chat;
  final String username;
  final VoidCallback onSend;

  const _WelcomeView({
    super.key,
    required this.controller,
    required this.chat,
    required this.username,
    required this.onSend,
  });

  static const _suggestions = [
    (
      Icons.map_outlined,
      'Plan a trip',
      'Routes, stays and a packing list',
      'Plan a relaxed 3-day weekend trip with a budget, places to stay and a packing list.',
    ),
    (
      Icons.code_rounded,
      'Write code',
      'Flutter, Python or Django',
      'Write clean, well-commented Flutter code for a login screen with validation.',
    ),
    (
      Icons.lightbulb_outline_rounded,
      'Explain a concept',
      'Clear, practical, step by step',
      'Explain how JWT access and refresh tokens work, step by step.',
    ),
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 400 ? 30.0 : (width < 700 ? 36.0 : 44.0);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: width < 400 ? 16 : 24,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RiseIn(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  children: [
                    const Floating(child: NovaLogo(size: 68, glow: true)),
                    const SizedBox(height: 22),
                    Text(
                      '$_greeting, $username',
                      textAlign: TextAlign.center,
                      style: AppTheme.display(titleSize),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ask anything. The lights are on.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 17, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 34),
              RiseIn(
                delay: const Duration(milliseconds: 300),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ChatInputBar(
                    controller: controller,
                    isStreaming: chat.isStreaming,
                    onChanged: chat.setDraft,
                    onSend: onSend,
                    onStop: chat.stopStreaming,
                    attachments: chat.pendingAttachments,
                    onAddFiles: chat.addAttachments,
                    onRemoveAttachment: chat.removeAttachment,
                    thinkLonger: chat.thinkLonger,
                    onThinkLongerChanged: chat.setThinkLonger,
                    responseStyle: chat.responseStyle,
                    onResponseStyleChanged: chat.setResponseStyle,
                    compact: true,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              RiseIn(
                delay: const Duration(milliseconds: 500),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final cards = [
                        for (final s in _suggestions)
                          _SuggestionCard(
                            icon: s.$1,
                            title: s.$2,
                            subtitle: s.$3,
                            onTap: () {
                              controller.text = s.$4;
                              controller.selection = TextSelection.collapsed(
                                offset: s.$4.length,
                              );
                              chat.setDraft(s.$4);
                            },
                          ),
                      ];
                      if (box.maxWidth < 640) {
                        return Column(
                          children: [
                            for (final card in cards) ...[
                              card,
                              if (card != cards.last)
                                const SizedBox(height: 10),
                            ],
                          ],
                        );
                      }
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final card in cards) ...[
                              Expanded(child: card),
                              if (card != cards.last) const SizedBox(width: 12),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Nova can make mistakes. Check important information.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SuggestionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => HoverLift(
    child: Material(
      color: AppTheme.surface.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppTheme.accentText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConversationView extends StatelessWidget {
  final ScrollController controller;
  final ChatProvider chat;
  const _ConversationView({
    super.key,
    required this.controller,
    required this.chat,
  });

  /// Only freshly sent/streamed messages animate in; loaded history appears
  /// instantly so scrolling back doesn't replay animations.
  static bool _isFresh(ChatMessage message) =>
      DateTime.now().difference(message.createdAt).inSeconds.abs() < 10;

  @override
  Widget build(BuildContext context) {
    final messages = chat.activeConversation?.messages ?? const [];
    final width = MediaQuery.sizeOf(context).width;
    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.fromLTRB(
        width < 400 ? 16 : 24,
        20,
        width < 400 ? 16 : 24,
        12,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final bubble = MessageBubble(
          message: message,
          isStreaming:
              chat.isStreaming &&
              message.role == 'assistant' &&
              index == messages.length - 1,
          // The first message is the server's canned greeting.
          showActions: index > 0,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _isFresh(message)
                ? RiseIn(key: ValueKey(message.id), offset: 12, child: bubble)
                : bubble,
          ),
        );
      },
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.accent, width: 2),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.upload_file_rounded,
            size: 44,
            color: AppTheme.accentText,
          ),
          const SizedBox(height: 14),
          Text('Drop files to add to chat', style: AppTheme.display(20)),
          const SizedBox(height: 6),
          const Text(
            'Images, PDFs, text and code files',
            style: TextStyle(color: AppTheme.muted),
          ),
        ],
      ),
    ),
  );
}
