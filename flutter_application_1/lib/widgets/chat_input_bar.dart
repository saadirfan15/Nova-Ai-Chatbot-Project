import 'dart:ui';

import 'package:flutter/material.dart';
import '../config/theme.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool isStreaming;
  final bool compact;
  final VoidCallback onSend;
  final ValueChanged<String> onChanged;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.isStreaming,
    this.compact = false,
    required this.onSend,
    required this.onChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isHovered = false;
  bool _isSendHovered = false;
  bool _isSendPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = AppTheme.border.withValues(alpha: 0.95);
    // final borderColor = _isFocused || _isHovered
    //     ? AppTheme.accent.withValues(alpha: 0.72)
    //     : AppTheme.border.withValues(alpha: 0.95);
    final glowColor = AppTheme.accent.withValues(alpha: 0.12);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;

    return SafeArea(
      child: Padding(
        padding: widget.compact
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? double.infinity : 900,
            ),
            // constraints: const BoxConstraints(maxWidth: 900),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: borderColor, width: 1.15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF344569,
                          ).withValues(alpha: 0.10),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 28,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.84),
                            borderRadius: BorderRadius.circular(32),
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.96),
                                const Color(0xFFF9FAFF).withValues(alpha: 0.96),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            // crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              IconButton(
                                tooltip: 'Attach file',
                                onPressed: () {},
                                icon: const Icon(
                                  Icons.attach_file_rounded,
                                  size: 20,
                                ),
                                color: AppTheme.mutedText,
                                style: IconButton.styleFrom(
                                  minimumSize: Size(
                                    isMobile ? 36 : 40,
                                    isMobile ? 36 : 40,
                                  ),
                                  // minimumSize: const Size(40, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Voice input',
                                onPressed: () {},
                                icon: const Icon(Icons.mic_rounded, size: 20),
                                color: AppTheme.mutedText,
                                style: IconButton.styleFrom(
                                  minimumSize: Size(
                                    isMobile ? 36 : 40,
                                    isMobile ? 36 : 40,
                                  ),
                                  // minimumSize: const Size(40, 40),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Focus(
                                  onFocusChange: (focused) {
                                    setState(() => _isFocused = focused);
                                  },
                                  child: TextField(
                                    focusNode: _focusNode,
                                    controller: widget.controller,
                                    onChanged: widget.onChanged,
                                    minLines: 1,
                                    maxLines: 5,
                                    textInputAction: TextInputAction.newline,
                                    onSubmitted: (_) {
                                      if (!widget.isStreaming &&
                                          widget.controller.text
                                              .trim()
                                              .isNotEmpty) {
                                        widget.onSend();
                                      }
                                    },
                                    style: const TextStyle(
                                      color: AppTheme.primaryText,
                                      fontSize: 15,
                                      height: 1.35,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Ask anything or search...',
                                      hintStyle: const TextStyle(
                                        color: AppTheme.mutedText,
                                        fontSize: 14,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 12,
                                          ),
                                    ),
                                    enabled: !widget.isStreaming,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _isSendHovered = true),
                                onExit: (_) =>
                                    setState(() => _isSendHovered = false),
                                child: GestureDetector(
                                  onTapDown: (_) =>
                                      setState(() => _isSendPressed = true),
                                  onTapUp: (_) =>
                                      setState(() => _isSendPressed = false),
                                  onTapCancel: () =>
                                      setState(() => _isSendPressed = false),
                                  onTap: () {
                                    if (!widget.isStreaming &&
                                        widget.controller.text
                                            .trim()
                                            .isNotEmpty) {
                                      widget.onSend();
                                    }
                                  },
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    scale: _isSendPressed
                                        ? 0.94
                                        : (_isSendHovered ? 1.04 : 1.0),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF6C7CE8),
                                            Color(0xFF9A83DD),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.accent.withValues(
                                              alpha: 0.24,
                                            ),
                                            blurRadius: 14,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: SizedBox(
                                        width: isMobile ? 42 : 48,
                                        height: isMobile ? 42 : 48,
                                        // width: 48,
                                        // height: 48,
                                        child: Center(
                                          child: widget.isStreaming
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.send_rounded,
                                                  size: isMobile ? 18 : 20,
                                                  // size: 20,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
