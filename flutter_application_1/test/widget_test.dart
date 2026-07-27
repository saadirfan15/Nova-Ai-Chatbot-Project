import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/conversation.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:flutter_application_1/providers/chat_provider.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'package:flutter_application_1/services/chat_rest_service.dart';

class FakeGreetingRestService extends ChatRestService {
  @override
  Future<Conversation> createConversation() async {
    return Conversation.fromJson({
      'conversation_id': 'conv-ui',
      'title': 'New chat',
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
      'messages': [
        {
          'id': 'msg-ui',
          'role': 'assistant',
          'content': 'Hello from the UI',
          'created_at': '2024-01-01T00:00:00.000Z',
        },
      ],
    });
  }

  @override
  Future<List<Conversation>> fetchConversations() async => [];
}

void main() {
  testWidgets('app boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
    'chat screen shows the welcome prompt for a brand-new conversation',
    (WidgetTester tester) async {
      final provider = ChatProvider(restService: FakeGreetingRestService());
      await provider.createNewConversation();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<ChatProvider>.value(value: provider),
          ],
          child: const MaterialApp(home: ChatScreen()),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Good'), findsOneWidget);
      expect(
        find.text('How can I help you today?'),
        findsOneWidget,
      );
    },
  );
}
