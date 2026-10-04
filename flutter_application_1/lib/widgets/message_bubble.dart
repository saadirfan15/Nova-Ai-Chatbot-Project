import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:markdown/markdown.dart' as md;
import '../config/theme.dart';
import '../models/message.dart';
import 'attachment_views.dart';
import 'aurora_effects.dart';

/// User messages sit in a teal glass bubble on the right; Nova's replies are
/// full-width text with the logo, so long answers read like an article.
///
/// While a reply streams it shows, Claude-style: a "Thinking…" panel with the
/// model's live reasoning (collapsing to "Thought for Ns" once the answer
/// starts), the answer itself, and a busy logo; when finished, a Copy action.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;

  /// True only for the assistant message that is currently streaming.
  final bool isStreaming;

  /// Copy etc. under finished replies (off for the canned greeting).
  final bool showActions;
  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) =>
      message.role == 'user' ? _userBubble(context) : _assistantReply(context);

  Widget _userBubble(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.8;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (message.attachments.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: message.content.isEmpty ? 0 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth.clamp(0, 600)),
                child: AttachmentGallery(attachments: message.attachments),
              ),
            ),
          if (message.content.isNotEmpty) _userText(maxWidth),
        ],
      ),
    );
  }

  Widget _userText(double maxWidth) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth.clamp(0, 600)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.userBubble,
          border: Border.all(color: AppTheme.userBubbleBorder),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: SelectableText(
          message.content,
          style: const TextStyle(
            color: AppTheme.text,
            fontSize: 15,
            height: 1.55,
          ),
        ),
      ),
    );
  }

  Widget _assistantReply(BuildContext context) {
    final theme = Theme.of(context);
    final mono = GoogleFonts.jetBrainsMono(fontSize: 13.5, height: 1.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NovaLogo(size: 26, busy: isStreaming),
              const SizedBox(width: 10),
              const Text(
                'Nova',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (message.reasoning.isNotEmpty ||
              (isStreaming && message.content.isEmpty)) ...[
            _ThinkingPanel(
              reasoning: message.reasoning,
              thinking: isStreaming && message.content.isEmpty,
              seconds: message.thinkingSeconds,
            ),
            const SizedBox(height: 12),
          ],
          if (message.content.isNotEmpty)
            MarkdownBody(
              data: message.content,
              selectable: true,
              builders: {'pre': _CodeBlockBuilder()},
              styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                p: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.body,
                  fontSize: 15.5,
                  height: 1.7,
                ),
                listBullet: const TextStyle(color: AppTheme.body),
                strong: const TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w600,
                ),
                a: const TextStyle(
                  color: AppTheme.accentText,
                  decoration: TextDecoration.underline,
                ),
                h1: AppTheme.display(24),
                h2: AppTheme.display(20),
                h3: AppTheme.display(17),
                code: mono.copyWith(
                  color: AppTheme.accentText,
                  backgroundColor: AppTheme.raised,
                ),
                // _CodeBlockBuilder draws the whole block itself.
                codeblockPadding: EdgeInsets.zero,
                codeblockDecoration: const BoxDecoration(),
                tableBorder: TableBorder.all(color: AppTheme.border),
                tableHead: const TextStyle(
                  color: AppTheme.text,
                  fontWeight: FontWeight.w600,
                ),
                tableBody: const TextStyle(color: AppTheme.body),
                blockquoteDecoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: const Border(
                    left: BorderSide(color: AppTheme.accent, width: 3),
                  ),
                ),
                horizontalRuleDecoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.border)),
                ),
              ),
            ),
          if (isStreaming && message.content.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: NovaLogo(size: 20, busy: true),
            ),
          if (showActions && !isStreaming && message.content.isNotEmpty)
            _MessageActions(text: message.content),
        ],
      ),
    );
  }
}

/// Collapsible "Thinking…" / "Thought for Ns" panel.
class _ThinkingPanel extends StatefulWidget {
  final String reasoning;
  final bool thinking;
  final double? seconds;
  const _ThinkingPanel({
    required this.reasoning,
    required this.thinking,
    required this.seconds,
  });

  @override
  State<_ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<_ThinkingPanel> {
  /// Null = follow the default: open while thinking, closed afterwards.
  bool? _userExpanded;

  bool get _expanded => _userExpanded ?? widget.thinking;

  String get _label {
    final s = widget.seconds;
    if (s == null) return 'Thought process';
    if (s < 1) return 'Thought for a moment';
    return 'Thought for ${s.round()}s';
  }

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      fontSize: 14,
      color: AppTheme.muted,
      fontWeight: FontWeight.w500,
    );
    final canExpand = widget.reasoning.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: canExpand
              ? () => setState(() => _userExpanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 16,
                  color: widget.thinking ? AppTheme.accentText : AppTheme.muted,
                ),
                const SizedBox(width: 8),
                widget.thinking
                    ? const ShimmerText('Thinking…', style: labelStyle)
                    : Text(_label, style: labelStyle),
                if (canExpand) ...[
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: _expanded && canExpand
              ? Container(
                  margin: const EdgeInsets.only(top: 8, left: 9),
                  padding: const EdgeInsets.only(left: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppTheme.border, width: 2),
                    ),
                  ),
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: SingleChildScrollView(
                    // While thinking, keep the newest thoughts in view.
                    reverse: widget.thinking,
                    child: SelectableText(
                      widget.reasoning,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Actions under a finished reply.
class _MessageActions extends StatefulWidget {
  final String text;
  const _MessageActions({required this.text});

  @override
  State<_MessageActions> createState() => _MessageActionsState();
}

class _MessageActionsState extends State<_MessageActions> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Transform.translate(
      offset: const Offset(-8, 0),
      child: IconButton(
        tooltip: _copied ? 'Copied' : 'Copy reply',
        onPressed: _copy,
        icon: Icon(
          _copied ? Icons.check_rounded : Icons.copy_rounded,
          size: 17,
          color: _copied ? AppTheme.accentText : AppTheme.muted,
        ),
        style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
      ),
    ),
  );
}

/// Fenced code: dark panel with the language name and a Copy button.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.textContent.trimRight();
    final first = element.children?.isNotEmpty == true
        ? element.children!.first
        : null;
    final language = first is md.Element
        ? (first.attributes['class'] ?? '').replaceFirst('language-', '')
        : '';
    return _CodeBlock(code: code, language: language);
  }
}

class _CodeBlock extends StatefulWidget {
  final String code;
  final String language;
  const _CodeBlock({required this.code, required this.language});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final mono = GoogleFonts.jetBrainsMono(
      fontSize: 13.5,
      height: 1.65,
      color: AppTheme.body,
    );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF03100F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            child: Row(
              children: [
                Text(
                  widget.language.isEmpty ? 'code' : widget.language,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    color: AppTheme.muted,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _copy,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 15,
                  ),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: _copied
                        ? AppTheme.accentText
                        : AppTheme.body,
                    textStyle: const TextStyle(fontSize: 12.5),
                    minimumSize: const Size(0, 34),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: SelectableText(widget.code, style: mono),
          ),
        ],
      ),
    );
  }
}
