import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/conversation.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/providers/chat_provider.dart';
import 'package:flutter_application_1/services/chat_rest_service.dart';

class FakeChatRestService extends ChatRestService {
  @override
  Future<Conversation> createConversation() async {
    return Conversation(
      id: 'conv-1',
      title: 'New chat',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
      messages: [
        ChatMessage(
          id: 'msg-1',
          role: 'assistant',
          content: 'Hello! I’m ready to help.',
          createdAt: DateTime(2024, 1, 1),
        ),
      ],
    );
  }
}

class FakeWrappedChatRestService extends ChatRestService {
  @override
  Future<Conversation> createConversation() async {
    return Conversation.fromJson({
      'conversation': {
        'id': 'conv-2',
        'title': 'New chat',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
        'assistant_message': {
          'id': 'msg-2',
          'role': 'assistant',
          'content': 'I’m here and ready to help.',
          'created_at': '2024-01-01T00:00:00.000Z',
        },
      },
    });
  }
}

class FakeConversationIdChatRestService extends ChatRestService {
  @override
  Future<Conversation> createConversation() async {
    return Conversation.fromJson({
      'conversation_id': 'conv-3',
      'title': 'New chat',
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
      'messages': [
        {
          'id': 'msg-3',
          'role': 'assistant',
          'content': 'Greeting from conversation_id payload',
          'created_at': '2024-01-01T00:00:00.000Z',
        },
      ],
    });
  }
}

void main() {
  test(
    'createNewConversation loads the backend greeting into the active conversation once',
    () async {
      final provider = ChatProvider(restService: FakeChatRestService());

      await provider.createNewConversation();

      expect(provider.activeConversation, isNotNull);
      expect(provider.activeConversation!.id, 'conv-1');
      expect(provider.activeConversation!.messages, hasLength(1));
      expect(
        provider.activeConversation!.messages.single.content,
        'Hello! I’m ready to help.',
      );
      expect(provider.conversations, hasLength(1));
    },
  );

  test(
    'createNewConversation uses a wrapped backend greeting payload',
    () async {
      final provider = ChatProvider(restService: FakeWrappedChatRestService());

      await provider.createNewConversation();

      expect(provider.activeConversation, isNotNull);
      expect(provider.activeConversation!.id, 'conv-2');
      expect(provider.activeConversation!.messages, hasLength(1));
      expect(
        provider.activeConversation!.messages.single.content,
        'I’m here and ready to help.',
      );
    },
  );

  test(
    'createNewConversation stores the conversation_id returned by the backend',
    () async {
      final provider = ChatProvider(
        restService: FakeConversationIdChatRestService(),
      );

      await provider.createNewConversation();

      expect(provider.activeConversation, isNotNull);
      expect(provider.activeConversation!.id, 'conv-3');
      expect(provider.activeConversation!.messages, hasLength(1));
      expect(
        provider.activeConversation!.messages.single.content,
        'Greeting from conversation_id payload',
      );
    },
  );
}
