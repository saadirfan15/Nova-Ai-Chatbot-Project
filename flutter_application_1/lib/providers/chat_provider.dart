import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/chat_rest_service.dart';
import '../services/chat_socket_service.dart';
import '../services/token_storage.dart';

class ChatProvider with ChangeNotifier {
  ChatProvider({ChatRestService? restService, ChatSocketService? socketService})
    : _restService = restService ?? ChatRestService(),
      _socketService = socketService ?? ChatSocketService();

  final ChatRestService _restService;
  final ChatSocketService _socketService;

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

  List<Conversation> get conversations => _conversations;
  Conversation? get activeConversation => _activeConversation;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isStreaming => _isStreaming;
  bool get isLoadingConversation => _isLoadingConversation;
  String? get errorMessage => _errorMessage;
  String get draft => _draft;
  bool get showTypingIndicator => _showTypingIndicator;
  List<ChatMessage> get streamingBuffer => _streamingBuffer;

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
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socketService.close();
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
    if (currentConversation.title != 'New chat' &&
        currentConversation.title != 'Untitled') {
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
    if (text.isEmpty || _isStreaming) return;

    _isStreaming = true;
    _showTypingIndicator = true;
    _errorMessage = null;

    final conversationId = _activeConversation?.id;
    setConversationTitleFromPrompt(text);
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );

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
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Authentication token missing');
      }

      _socketService.close();
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
      notifyListeners();

      _socketSubscription?.cancel();
      _socketSubscription = channel.stream.listen(
        (raw) {
          final data = jsonDecode(raw.toString()) as Map<String, dynamic>;
          switch (data['type']) {
            case 'conversation_start':
              final conversationIdFromEvent = data['conversation_id']
                  ?.toString();
              if (conversationIdFromEvent != null &&
                  conversationIdFromEvent.isNotEmpty) {
                _activeConversation = Conversation(
                  id: conversationIdFromEvent,
                  title: _activeConversation!.title,
                  createdAt: _activeConversation!.createdAt,
                  updatedAt: DateTime.now(),
                  messages: _activeConversation!.messages,
                );
              }
              break;
            case 'token':
              final content = data['content']?.toString() ?? '';
              final currentMessages = List<ChatMessage>.from(
                _activeConversation!.messages,
              );
              if (currentMessages.isNotEmpty) {
                final last = currentMessages.last;
                if (last.role == 'assistant') {
                  currentMessages[currentMessages.length - 1] = ChatMessage(
                    id: last.id,
                    role: last.role,
                    content: last.content + content,
                    createdAt: last.createdAt,
                  );
                }
              }
              _activeConversation = Conversation(
                id: _activeConversation!.id,
                title: _activeConversation!.title,
                createdAt: _activeConversation!.createdAt,
                updatedAt: DateTime.now(),
                messages: currentMessages,
              );
              break;
            case 'done':
              _showTypingIndicator = false;
              _isStreaming = false;
              _socketSubscription?.cancel();
              _socketSubscription = null;
              break;
            case 'error':
              _errorMessage = data['message']?.toString() ?? 'Streaming failed';
              _showTypingIndicator = false;
              _isStreaming = false;
              _socketSubscription?.cancel();
              _socketSubscription = null;
              break;
          }
          notifyListeners();
        },
        onError: (_) {
          _errorMessage = 'WebSocket disconnected';
          _showTypingIndicator = false;
          _isStreaming = false;
          notifyListeners();
        },
      );

      _socketService.sendMessage(message: text, conversationId: conversationId);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    } catch (e) {
      _errorMessage = e.toString();
      _showTypingIndicator = false;
      _isStreaming = false;
    } finally {
      notifyListeners();
    }
  }
}
