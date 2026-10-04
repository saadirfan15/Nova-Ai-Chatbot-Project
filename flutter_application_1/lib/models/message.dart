import 'attachment.dart';

class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  /// The model's thinking before it answered (reasoning models only).
  final String reasoning;

  /// How long the model thought, measured live on this device. Null for
  /// messages loaded from history.
  final double? thinkingSeconds;

  final List<ChatAttachment> attachments;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.reasoning = '',
    this.thinkingSeconds,
    this.attachments = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      reasoning: json['reasoning']?.toString() ?? '',
      attachments: [
        for (final item in json['attachments'] as List<dynamic>? ?? const [])
          if (item is Map)
            ChatAttachment.fromJson(Map<String, dynamic>.from(item)),
      ],
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  ChatMessage copyWith({
    String? content,
    String? reasoning,
    double? thinkingSeconds,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      reasoning: reasoning ?? this.reasoning,
      thinkingSeconds: thinkingSeconds ?? this.thinkingSeconds,
      attachments: attachments,
    );
  }
}
