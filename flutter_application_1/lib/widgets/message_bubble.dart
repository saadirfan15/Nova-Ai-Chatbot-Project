import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../config/theme.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  const MessageBubble({super.key, required this.message, this.isStreaming = false});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final content = message.content.isEmpty && isStreaming ? '▍' : message.content;
    final maxWidth = MediaQuery.sizeOf(context).width > 700 ? 720.0 : MediaQuery.sizeOf(context).width * .86;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(vertical: 8),
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFFEFF2FF) : AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 7), bottomRight: Radius.circular(isUser ? 7 : 20),
            ),
            border: Border.all(color: isUser ? AppTheme.accent.withValues(alpha: .3) : AppTheme.border),
            boxShadow: [BoxShadow(color: const Color(0xFF344569).withValues(alpha: .08), blurRadius: 14, offset: const Offset(0, 7))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (message.content.isNotEmpty || isStreaming)
              MarkdownBody(
                data: content,
                selectable: true,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.primaryText, height: 1.62),
                  code: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.accent, fontFamily: 'monospace'),
                  codeblockDecoration: BoxDecoration(color: AppTheme.surfaceElevated, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                  h1: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryText, fontWeight: FontWeight.w700),
                  h2: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primaryText, fontWeight: FontWeight.w700),
                  listBullet: const TextStyle(color: AppTheme.primaryText),
                ),
              ),
            const SizedBox(height: 8),
            Text(_formatTime(message.createdAt), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.mutedText)),
          ]),
        ),
      ),
    );
  }

  String _formatTime(DateTime createdAt) => '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
}
