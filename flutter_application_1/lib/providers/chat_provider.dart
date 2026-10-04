import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/attachment.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/chat_rest_service.dart';
import '../services/chat_socket_service.dart';

/// Response styles from the composer's "+" menu (mirrors the backend's
/// STYLE_INSTRUCTIONS keys).
enum ResponseStyle {
  normal('Normal', 'Default responses'),
  concise('Concise', 'Shorter, to-the-point answers'),
  explanatory('Explanatory', 'Step-by-step, teaches as it goes'),
  formal('Formal', 'Clear, professional tone');

  const ResponseStyle(this.label, this.description);
  final String label;
  final String description;
}

class ChatProvider with ChangeNotifier {
  ChatProvider({
    ChatRestService? restService,
    ChatSocketService? socketService,
    AuthService? authService,
  }) : _restService = restService ?? ChatRestService(),
       _socketService = socketService ?? ChatSocketService(),
       _authService = authService ?? AuthService();

  final ChatRestService _restService;
  final ChatSocketService _socketService;
  final AuthService _authService;

  List<Conversation> _conversations = [];
  Conversation? _activeConversation;
  bool _isLoadingConversations = false;
  bool _isStreaming = false;
  bool _isLoadingConversation = false;
  String? _errorMessage;
  String _draft = '';
  bool _showTypingIndicator = false;
  final List<ChatMessage> _streamingBuffer = [];
  StreamSubscription? _socketSubscription;
  DateTime? _replyStartedAt;
  final List<PendingAttachment> _pendingAttachments = [];
  bool _thinkLonger = false;
  ResponseStyle _responseStyle = ResponseStyle.normal;

  /// "Think longer" (higher reasoning effort) for the next messages.
  bool get thinkLonger => _thinkLonger;
  ResponseStyle get responseStyle => _responseStyle;

  void setThinkLonger(bool value) {
    _thinkLonger = value;
    notifyListeners();
  }

  void setResponseStyle(ResponseStyle style) {
    _responseStyle = style;
    notifyListeners();
  }

  final Map<String, Future<Uint8List>> _attachmentBytes = {};
  int _localIdCounter = 0;

  /// Files picked in the composer that will go with the next message.
  List<PendingAttachment> get pendingAttachments =>
      List.unmodifiable(_pendingAttachments);
  bool get isUploading =>
      _pendingAttachments.any((a) => a.status == UploadStatus.uploading);

  List<Conversation> get conversations => _conversations;
  Conversation? get activeConversation => _activeConversation;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isStreaming => _isStreaming;
  bool get isLoadingConversation => _isLoadingConversation;
  String? get errorMessage => _errorMessage;
  String get draft => _draft;
  bool get showTypingIndicator => _showTypingIndicator;
  List<ChatMessage> get streamingBuffer => _streamingBuffer;

  static bool _isDefaultTitle(String title) {
    final normalized = title.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'new chat' ||
        normalized == 'untitled';
  }

  /// Clears all per-user state, e.g. on logout, so the next account that
  /// signs in on this device never sees the previous user's chats.
  void reset() {
    _closeSocket();
    _conversations = [];
    _activeConversation = null;
    _isLoadingConversations = false;
    _isLoadingConversation = false;
    _isStreaming = false;
    _showTypingIndicator = false;
    _errorMessage = null;
    _draft = '';
    _streamingBuffer.clear();
    _pendingAttachments.clear();
    _attachmentBytes.clear();
    _thinkLonger = false;
    _responseStyle = ResponseStyle.normal;
    notifyListeners();
  }

  /// Validates and uploads picked files. Rejected or failed files are dropped
  /// and reported through [errorMessage].
  Future<void> addAttachments(
    List<({String name, Uint8List bytes})> files,
  ) async {
    final problems = <String>[];
    final accepted = <PendingAttachment>[];
    for (final file in files) {
      if (_pendingAttachments.length + accepted.length >=
          AttachmentRules.maxFiles) {
        problems.add('You can attach up to ${AttachmentRules.maxFiles} files.');
        break;
      }
      final problem = AttachmentRules.problem(file.name, file.bytes.length);
      if (problem != null) {
        problems.add(problem);
        continue;
      }
      accepted.add(
        PendingAttachment(
          localId: 'local-${_localIdCounter++}',
          name: file.name,
          bytes: file.bytes,
        ),
      );
    }
    _pendingAttachments.addAll(accepted);
    _errorMessage = problems.isEmpty ? null : problems.join('\n');
    notifyListeners();

    await Future.wait(accepted.map(_upload));
  }

  Future<void> _upload(PendingAttachment pending) async {
    try {
      final uploaded = await _restService.uploadAttachment(
        name: pending.name,
        bytes: pending.bytes,
      );
      final index = _pendingAttachments.indexWhere(
        (a) => a.localId == pending.localId,
      );
      if (index < 0) return; // removed while uploading
      _pendingAttachments[index] = pending.ready(uploaded);
    } catch (e) {
      _pendingAttachments.removeWhere((a) => a.localId == pending.localId);
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  void removeAttachment(String localId) {
    _pendingAttachments.removeWhere((a) => a.localId == localId);
    notifyListeners();
  }

  /// Bytes for an attachment, downloaded once and cached (history previews).
  Future<Uint8List> loadAttachment(String id) =>
      _attachmentBytes.putIfAbsent(id, () {
        final future = _restService.fetchAttachmentBytes(id);
        // Don't cache failures; a later rebuild can retry.
        future.catchError((Object _) {
          _attachmentBytes.remove(id);
          return Uint8List(0);
        });
        return future;
      });

  void _closeSocket() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socketService.close();
  }

  /// Keeps the sidebar entry for the active conversation in sync.
  void _upsertActiveInList() {
    final active = _activeConversation;
    if (active == null || active.id.isEmpty) return;
    final summary = Conversation(
      id: active.id,
      title: active.title,
      createdAt: active.createdAt,
      updatedAt: active.updatedAt,
    );
    _conversations.removeWhere((item) => item.id == active.id);
    _conversations.insert(0, summary);
  }

  /// Drops the assistant placeholder bubble if nothing was streamed into it.
  void _removeEmptyAssistantPlaceholder() {
    final active = _activeConversation;
    if (active == null || active.messages.isEmpty) return;
    final last = active.messages.last;
    if (last.role != 'assistant' ||
        last.content.isNotEmpty ||
        last.reasoning.isNotEmpty) {
      return;
    }
    _activeConversation = Conversation(
      id: active.id,
      title: active.title,
      createdAt: active.createdAt,
      updatedAt: active.updatedAt,
      messages: active.messages.sublist(0, active.messages.length - 1),
    );
  }

  /// Stops listening to the current reply (the "Stop" button). Whatever has
  /// streamed in so far stays on screen.
  void stopStreaming() {
    if (!_isStreaming) return;
    _isStreaming = false;
    _showTypingIndicator = false;
    _removeEmptyAssistantPlaceholder();
    _closeSocket();
    notifyListeners();
  }

  void _failStreaming(String message) {
    _errorMessage = message;
    _showTypingIndicator = false;
    _isStreaming = false;
    _removeEmptyAssistantPlaceholder();
    _closeSocket();
  }

  /// Applies [update] to the assistant message currently being streamed.
  void _updateStreamingMessage(ChatMessage Function(ChatMessage) update) {
    final active = _activeConversation;
    if (active == null || active.messages.isEmpty) return;
    final last = active.messages.last;
    if (last.role != 'assistant') return;
    _activeConversation = Conversation(
      id: active.id,
      title: active.title,
      createdAt: active.createdAt,
      updatedAt: DateTime.now(),
      messages: [
        ...active.messages.sublist(0, active.messages.length - 1),
        update(last),
      ],
    );
  }

  void setDraft(String value) {
    _draft = value;
    notifyListeners();
  }

  Future<void> loadConversations() async {
    _isLoadingConversations = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _conversations = await _restService.fetchConversations();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  Future<void> selectConversation(String id) async {
    _isLoadingConversation = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final conversation = await _restService.fetchConversation(id);
      _activeConversation = conversation;
      _showTypingIndicator = false;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingConversation = false;
      notifyListeners();
    }
  }

  Future<void> createNewConversation() async {
    _isLoadingConversation = true;
    _errorMessage = null;
    _showTypingIndicator = false;
    _draft = '';
    _isStreaming = false;
    _closeSocket();
    notifyListeners();

    try {
      final conversation = await _restService.createConversation();
      final existingIndex = _conversations.indexWhere(
        (item) => item.id == conversation.id,
      );

      if (existingIndex >= 0) {
        _conversations[existingIndex] = conversation;
      } else {
        _conversations.insert(0, conversation);
      }

      _activeConversation = conversation;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingConversation = false;
      notifyListeners();
    }
  }

  void setConversationTitleFromPrompt(String prompt) {
    if (prompt.trim().isEmpty || _activeConversation == null) {
      return;
    }

    final title = _generateTitle(prompt);
    final currentConversation = _activeConversation!;
    if (!_isDefaultTitle(currentConversation.title)) {
      return;
    }

    final updatedConversation = Conversation(
      id: currentConversation.id,
      title: title,
      createdAt: currentConversation.createdAt,
      updatedAt: DateTime.now(),
      messages: currentConversation.messages,
    );

    _activeConversation = updatedConversation;
    final existingIndex = _conversations.indexWhere(
      (item) => item.id == updatedConversation.id,
    );
    if (existingIndex >= 0) {
      _conversations[existingIndex] = updatedConversation;
    }
    notifyListeners();
  }

  String _generateTitle(String prompt) {
    final words = prompt
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return 'New chat';
    }

    final compact = words.take(5).join(' ');
    if (compact.length <= 32) {
      return compact;
    }
    return '${compact.substring(0, 29)}...';
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _restService.deleteConversation(id);
      _conversations.removeWhere((item) => item.id == id);
      if (_activeConversation?.id == id) {
        _activeConversation = null;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendMessage() async {
    final text = _draft.trim();
    final attachments = [
      for (final a in _pendingAttachments)
        if (a.isReady) a.uploaded!,
    ];
    if ((text.isEmpty && attachments.isEmpty) || _isStreaming || isUploading) {
      return;
    }

    _isStreaming = true;
    _showTypingIndicator = true;
    _errorMessage = null;

    final conversationId = _activeConversation?.id;
    setConversationTitleFromPrompt(
      text.isNotEmpty ? text : attachments.map((a) => a.name).join(' '),
    );
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    _pendingAttachments.clear();

    final activeConversation =
        _activeConversation ??
        Conversation(
          id: '',
          title: 'New chat',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          messages: const [],
        );

    _activeConversation = Conversation(
      id: activeConversation.id,
      title: activeConversation.title,
      createdAt: activeConversation.createdAt,
      updatedAt: DateTime.now(),
      messages: [...activeConversation.messages, userMessage],
    );

    _draft = '';
    notifyListeners();

    try {
      final token = await _authService.getValidAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Session expired. Please log in again.');
      }

      _closeSocket();
      final channel = await _socketService.connect(token: token);
      final assistantMessage = ChatMessage(
        id: 'assistant-${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
      );

      _activeConversation = Conversation(
        id: _activeConversation!.id,
        title: _activeConversation!.title,
        createdAt: _activeConversation!.createdAt,
        updatedAt: DateTime.now(),
        messages: [..._activeConversation!.messages, assistantMessage],
      );
      _replyStartedAt = DateTime.now();
      notifyListeners();

      _socketSubscription?.cancel();
      _socketSubscription = channel.stream.listen(
        (raw) {
          final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
          switch (data['type']) {
            case 'conversation_start':
              final conversationIdFromEvent = data['conversation_id']
                  ?.toString();
              final serverTitle = data['title']?.toString();
              if (conversationIdFromEvent != null &&
                  conversationIdFromEvent.isNotEmpty) {
                _activeConversation = Conversation(
                  id: conversationIdFromEvent,
                  title: serverTitle != null && !_isDefaultTitle(serverTitle)
                      ? serverTitle
                      : _activeConversation!.title,
                  createdAt: _activeConversation!.createdAt,
                  updatedAt: DateTime.now(),
                  messages: _activeConversation!.messages,
                );
                _upsertActiveInList();
              }
              break;
            case 'reasoning':
              final thought = data['content']?.toString() ?? '';
              _updateStreamingMessage(
                (m) => m.copyWith(reasoning: m.reasoning + thought),
              );
              break;
            case 'token':
              final content = data['content']?.toString() ?? '';
              _updateStreamingMessage((m) {
                // First answer token = thinking finished; record how long.
                final finishedThinking =
                    m.content.isEmpty &&
                    m.reasoning.isNotEmpty &&
                    m.thinkingSeconds == null &&
                    _replyStartedAt != null;
                return m.copyWith(
                  content: m.content + content,
                  thinkingSeconds: finishedThinking
                      ? DateTime.now()
                                .difference(_replyStartedAt!)
                                .inMilliseconds /
                            1000
                      : null,
                );
              });
              break;
            case 'done':
              _showTypingIndicator = false;
              _isStreaming = false;
              _closeSocket();
              break;
            case 'error':
              _failStreaming(data['message']?.toString() ?? 'Streaming failed');
              break;
          }
          notifyListeners();
        },
        onError: (_) {
          _failStreaming('WebSocket disconnected');
          notifyListeners();
        },
        onDone: () {
          // Server closed the socket before sending "done" (e.g. auth
          // rejected with code 4001 or the connection dropped).
          if (_isStreaming) {
            _failStreaming('Connection closed before the reply finished');
            notifyListeners();
          }
        },
      );

      _socketService.sendMessage(
        message: text,
        conversationId: conversationId,
        attachmentIds: [for (final a in attachments) a.id],
        options: {
          if (_thinkLonger) 'think': true,
          if (_responseStyle != ResponseStyle.normal)
            'style': _responseStyle.name,
        },
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      _failStreaming(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      notifyListeners();
    }
  }
}
