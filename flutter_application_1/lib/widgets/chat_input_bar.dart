import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../config/theme.dart';
import '../models/attachment.dart';
import '../providers/chat_provider.dart';
import 'attachment_views.dart';
import 'composer_menu.dart';

typedef PickedFiles = List<({String name, Uint8List bytes})>;

/// The message composer, in the style of Claude / ChatGPT: a rounded box with
/// an auto-growing text area on top and a small toolbar underneath.
///
/// `compact: true` is the hero version on the welcome screen (taller, no
/// disclaimer underneath).
class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final bool compact;
  final VoidCallback onSend;
  final VoidCallback? onStop;
  final ValueChanged<String> onChanged;

  /// Files waiting to be sent with the next message.
  final List<PendingAttachment> attachments;
  final ValueChanged<PickedFiles>? onAddFiles;
  final ValueChanged<String>? onRemoveAttachment;

  /// Options from the "+" menu.
  final bool thinkLonger;
  final ValueChanged<bool>? onThinkLongerChanged;
  final ResponseStyle responseStyle;
  final ValueChanged<ResponseStyle>? onResponseStyleChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isStreaming,
    this.compact = false,
    required this.onSend,
    this.onStop,
    required this.onChanged,
    this.attachments = const [],
    this.onAddFiles,
    this.onRemoveAttachment,
    this.thinkLonger = false,
    this.onThinkLongerChanged,
    this.responseStyle = ResponseStyle.normal,
    this.onResponseStyleChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final FocusNode _focusNode = FocusNode();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKey;
    _focusNode.addListener(() => setState(() {}));
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
    } catch (_) {
      _speechAvailable = false;
    }
    if (mounted) setState(() {});
  }

  /// Enter sends, Shift+Enter inserts a new line (hardware keyboards).
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final isEnter =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (event is KeyDownEvent &&
        isEnter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool get _uploading =>
      widget.attachments.any((a) => a.status == UploadStatus.uploading);

  bool _canSend(String text) =>
      !widget.isStreaming &&
      !_uploading &&
      (text.trim().isNotEmpty || widget.attachments.any((a) => a.isReady));

  void _send() {
    if (!_canSend(widget.controller.text)) return;
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
    widget.onSend();
  }

  int _pastedCount = 0;

  Future<void> _takePhoto() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        imageQuality: 85,
      );
      if (photo == null) return;
      final name = photo.name.contains('.') ? photo.name : '${photo.name}.jpg';
      widget.onAddFiles?.call([(name: name, bytes: await photo.readAsBytes())]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the camera.')),
      );
    }
  }

  Future<void> _pasteText() async {
    final text = await showPasteTextDialog(context);
    if (text == null || text.trim().isEmpty) return;
    _pastedCount++;
    final name = _pastedCount == 1
        ? 'pasted-text.txt'
        : 'pasted-text-$_pastedCount.txt';
    widget.onAddFiles?.call([(name: name, bytes: utf8.encode(text))]);
    _focusNode.requestFocus();
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: AttachmentRules.allExtensions,
    );
    if (result == null) return;
    final files = [
      for (final f in result.files)
        if (f.bytes != null) (name: f.name, bytes: f.bytes!),
    ];
    if (files.isNotEmpty) widget.onAddFiles?.call(files);
    _focusNode.requestFocus();
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice input is not available on this device.'),
        ),
      );
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        widget.controller.text = result.recognizedWords;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
        widget.onChanged(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;

    final composer = GestureDetector(
      // Clicking anywhere in the box (padding, toolbar gaps) focuses the text.
      onTap: _focusNode.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
        decoration: BoxDecoration(
          color: Color.lerp(AppTheme.surface, AppTheme.raised, 0.25),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: focused
                ? AppTheme.accent.withValues(alpha: 0.55)
                : AppTheme.border,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            if (focused)
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.14),
                blurRadius: 24,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.attachments.isNotEmpty) ...[
              _PendingAttachments(
                attachments: widget.attachments,
                onRemove: widget.onRemoveAttachment,
              ),
              const SizedBox(height: 12),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: widget.compact ? 52 : 26),
              child: TextField(
                focusNode: _focusNode,
                controller: widget.controller,
                onChanged: widget.onChanged,
                minLines: 1,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                cursorColor: AppTheme.accent,
                style: const TextStyle(
                  color: AppTheme.text,
                  fontSize: 16,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  // Like Claude: an open question on a fresh chat, "Reply…"
                  // once the conversation is going.
                  hintText: widget.compact
                      ? 'How can I help you today?'
                      : 'Reply to Nova…',
                  hintStyle: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 16,
                  ),
                  filled: false,
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.onAddFiles != null) ...[
                  ComposerPlusMenu(
                    onUploadFiles: _pickFiles,
                    onTakePhoto: supportsCamera ? _takePhoto : null,
                    onPasteText: _pasteText,
                    thinkLonger: widget.thinkLonger,
                    onThinkLongerChanged: (v) =>
                        widget.onThinkLongerChanged?.call(v),
                    responseStyle: widget.responseStyle,
                    onResponseStyleChanged: (s) =>
                        widget.onResponseStyleChanged?.call(s),
                  ),
                  const SizedBox(width: 6),
                ],
                _ToolbarButton(
                  tooltip: _isListening ? 'Stop dictation' : 'Dictate',
                  icon: _isListening
                      ? Icons.mic_rounded
                      : Icons.mic_none_rounded,
                  active: _isListening,
                  onPressed: _toggleListening,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        if (_isListening)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Text(
                              'Listening…',
                              style: TextStyle(
                                color: AppTheme.accentText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        if (widget.thinkLonger)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ActiveOptionChip(
                              icon: Icons.lightbulb_outline_rounded,
                              label: 'Think longer',
                              onRemove: () =>
                                  widget.onThinkLongerChanged?.call(false),
                            ),
                          ),
                        if (widget.responseStyle != ResponseStyle.normal)
                          ActiveOptionChip(
                            icon: Icons.tune_rounded,
                            label: widget.responseStyle.label,
                            onRemove: () => widget.onResponseStyleChanged?.call(
                              ResponseStyle.normal,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.isStreaming)
                  _CircleButton(
                    tooltip: 'Stop generating',
                    background: AppTheme.text,
                    foreground: AppTheme.background,
                    onPressed: widget.onStop,
                    child: const Icon(Icons.stop_rounded, size: 20),
                  )
                else
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (context, value, _) {
                      final ready = _canSend(value.text);
                      return _CircleButton(
                        tooltip: _uploading
                            ? 'Waiting for uploads…'
                            : 'Send message',
                        background: ready ? AppTheme.accent : AppTheme.raised,
                        foreground: ready ? AppTheme.onAccent : AppTheme.muted,
                        onPressed: ready ? _send : null,
                        child: const Icon(Icons.arrow_upward_rounded, size: 20),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (widget.compact) return composer;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                composer,
                const SizedBox(height: 8),
                const Text(
                  'Nova can make mistakes. Check important information.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round 36px icon button used in the composer toolbar.
class _ToolbarButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;
  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    style: IconButton.styleFrom(
      minimumSize: const Size(36, 36),
      fixedSize: const Size(36, 36),
      padding: EdgeInsets.zero,
      shape: const CircleBorder(),
      foregroundColor: active ? AppTheme.accentText : AppTheme.muted,
      backgroundColor: active
          ? AppTheme.accent.withValues(alpha: 0.16)
          : Colors.transparent,
      side: BorderSide(
        color: active
            ? AppTheme.accent.withValues(alpha: 0.5)
            : AppTheme.border,
      ),
    ),
  );
}

/// Send / Stop: a filled 36px circle that animates its color.
class _CircleButton extends StatelessWidget {
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final Widget child;
  const _CircleButton({
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: MouseRegion(
        cursor: onPressed == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: IconTheme(
              data: IconThemeData(color: foreground),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Thumbnails / file tiles for files picked but not yet sent, each with an
/// × to remove it.
class _PendingAttachments extends StatelessWidget {
  final List<PendingAttachment> attachments;
  final ValueChanged<String>? onRemove;
  const _PendingAttachments({required this.attachments, this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in attachments)
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (a.isImage)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    AttachmentImage(bytes: a.bytes, name: a.name, size: 56),
                    if (a.status == UploadStatus.uploading)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                )
              else
                AttachmentFileTile(
                  name: a.name,
                  size: a.bytes.length,
                  uploading: a.status == UploadStatus.uploading,
                ),
              if (onRemove != null)
                Positioned(
                  top: -7,
                  right: -7,
                  child: Tooltip(
                    message: 'Remove ${a.name}',
                    child: Semantics(
                      button: true,
                      label: 'Remove ${a.name}',
                      child: GestureDetector(
                        onTap: () => onRemove!(a.localId),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.text,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.background,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 13,
                            color: AppTheme.background,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
