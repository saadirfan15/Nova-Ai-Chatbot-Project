import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/conversation.dart';

class ConversationDrawer extends StatelessWidget {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? selectedConversationId;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onLogout;

  const ConversationDrawer({
    super.key,
    required this.conversations,
    required this.isLoading,
    required this.selectedConversationId,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) => Drawer(
        width: 280,
        backgroundColor: AppTheme.surface,
        surfaceTintColor: Colors.transparent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 16, 13, 13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _DrawerHeader(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6576E8), Color(0xFF9680D7)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('RECENT CONVERSATIONS', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.mutedText, letterSpacing: 1)),
              const SizedBox(height: 10),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                    : conversations.isEmpty
                    ? Center(child: Text('No conversations yet', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.mutedText)))
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = conversations[index];
                          return _ConversationTile(
                            conversation: item,
                            selected: item.id == selectedConversationId,
                            onTap: () => onSelect(item.id),
                            onDismissed: () => onDelete(item.id),
                          );
                        },
                      ),
              ),
              const Divider(height: 28),
              TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('Log out'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.mutedText),
              ),
            ]),
          ),
        ),
      );
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();
  @override
  Widget build(BuildContext context) => const Row(children: [
        CircleAvatar(
          radius: 21,
          backgroundColor: AppTheme.accentSoft,
          child: Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 21),
        ),
        SizedBox(width: 11),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Nova AI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          SizedBox(height: 2),
          Text('Your AI workspace', style: TextStyle(color: AppTheme.mutedText, fontSize: 12)),
        ]),
      ]);
}

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  const _ConversationTile({required this.conversation, required this.selected, required this.onTap, required this.onDismissed});

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey(widget.conversation.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
        ),
        onDismissed: (_) => widget.onDismissed(),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            transform: Matrix4.translationValues(_hovered ? 2 : 0, 0, 0),
            decoration: BoxDecoration(
              color: widget.selected ? AppTheme.accent.withValues(alpha: .13) : (_hovered ? AppTheme.surfaceElevated : AppTheme.surface),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.selected ? AppTheme.accent.withValues(alpha: .48) : AppTheme.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.conversation.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500)),
                    const SizedBox(height: 5),
                    Text(DateFormat('MMM d · HH:mm').format(widget.conversation.updatedAt), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
