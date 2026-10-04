import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/conversation.dart';
import 'aurora_effects.dart';

/// Conversation list. Shown permanently on wide screens and inside a Drawer
/// on phones.
class ConversationDrawer extends StatefulWidget {
  final List<Conversation> conversations;
  final bool isLoading;
  final String? selectedConversationId;
  final String username;
  final String? email;
  final VoidCallback onNewChat;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;
  final VoidCallback onLogout;

  const ConversationDrawer({
    super.key,
    required this.conversations,
    required this.isLoading,
    required this.selectedConversationId,
    required this.username,
    this.email,
    required this.onNewChat,
    required this.onSelect,
    required this.onDelete,
    required this.onLogout,
  });

  @override
  State<ConversationDrawer> createState() => _ConversationDrawerState();
}

class _ConversationDrawerState extends State<ConversationDrawer> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = query.isEmpty
        ? widget.conversations
        : widget.conversations
              .where((c) => c.title.toLowerCase().contains(query))
              .toList();

    return Material(
      color: AppTheme.sidebar.withValues(alpha: 0.82),
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const NovaLogo(size: 30),
                  const SizedBox(width: 10),
                  Text('Nova', style: AppTheme.display(19)),
                ],
              ),
              const SizedBox(height: 18),
              HoverLift(
                child: ElevatedButton.icon(
                  onPressed: widget.onNewChat,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('New chat'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    textStyle: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (value) => setState(() => _query = value),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search chats',
                  isDense: true,
                  prefixIcon: Icon(Icons.search_rounded, size: 18),
                  prefixIconConstraints: BoxConstraints(minWidth: 40),
                  contentPadding: EdgeInsets.symmetric(vertical: 11),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.only(left: 10, bottom: 6),
                child: Text(
                  'Recent',
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ),
              Expanded(
                child: widget.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : visible.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty
                              ? 'No conversations yet'
                              : 'No chats match “$_query”',
                          style: const TextStyle(color: AppTheme.muted),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return _ConversationTile(
                            conversation: item,
                            selected: item.id == widget.selectedConversationId,
                            onTap: () => widget.onSelect(item.id),
                            onDelete: () => widget.onDelete(item.id),
                          );
                        },
                      ),
              ),
              const Divider(height: 24),
              _UserRow(
                username: widget.username,
                email: widget.email,
                onLogout: widget.onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = widget.selected
        ? AppTheme.raised
        : (_hovered ? AppTheme.surface : Colors.transparent);

    return Dismissible(
      key: ValueKey(widget.conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
      ),
      onDismissed: (_) => widget.onDelete(),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: SizedBox(
              height: 40,
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.selected ? AppTheme.text : AppTheme.muted,
                        fontWeight: widget.selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (_hovered || widget.selected)
                    IconButton(
                      tooltip: 'Delete chat',
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 17),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(36, 36),
                        foregroundColor: AppTheme.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final String username;
  final String? email;
  final VoidCallback onLogout;
  const _UserRow({
    required this.username,
    required this.email,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final initials = username.isEmpty
        ? '?'
        : username.substring(0, username.length >= 2 ? 2 : 1).toUpperCase();
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.raised,
          child: Text(
            initials,
            style: const TextStyle(
              color: AppTheme.accentText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (email != null && email!.isNotEmpty)
                Text(
                  email!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.muted),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Log out',
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded, size: 19),
        ),
      ],
    );
  }
}
