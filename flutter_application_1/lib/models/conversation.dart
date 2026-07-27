import 'message.dart';

class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final payload = _normalizePayload(json);
    final rawMessages = payload['messages'] as List<dynamic>? ?? const [];
    final parsedMessages = rawMessages
        .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
        .toList();
    final fallbackMessage = _extractFallbackMessage(payload);

    return Conversation(
      id: _extractConversationId(payload),
      title: payload['title']?.toString() ?? 'New chat',
      createdAt: DateTime.parse(
        payload['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        payload['updated_at'] ?? DateTime.now().toIso8601String(),
      ),
      messages: parsedMessages.isNotEmpty || fallbackMessage == null
          ? parsedMessages
          : [...parsedMessages, fallbackMessage],
    );
  }

  static Map<String, dynamic> _normalizePayload(Map<String, dynamic> json) {
    final nested = json['conversation'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return json;
  }

  static String _extractConversationId(Map<String, dynamic> json) {
    final directId = json['id']?.toString();
    if (directId != null && directId.isNotEmpty) {
      return directId;
    }

    final directConversationId = json['conversation_id']?.toString();
    if (directConversationId != null && directConversationId.isNotEmpty) {
      return directConversationId;
    }

    final nested = json['conversation'];
    if (nested is Map) {
      final nestedId = nested['id']?.toString();
      if (nestedId != null && nestedId.isNotEmpty) {
        return nestedId;
      }

      final nestedConversationId = nested['conversation_id']?.toString();
      if (nestedConversationId != null && nestedConversationId.isNotEmpty) {
        return nestedConversationId;
      }
    }

    return '';
  }

  static ChatMessage? _extractFallbackMessage(Map<String, dynamic> json) {
    final candidates = <String>[
      'assistant_message',
      'initial_message',
      'first_message',
      'greeting',
      'message',
    ];

    for (final key in candidates) {
      final value = json[key];
      if (value is Map) {
        return ChatMessage.fromJson(Map<String, dynamic>.from(value));
      }
    }

    return null;
  }
}
