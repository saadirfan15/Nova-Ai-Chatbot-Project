import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/models/conversation.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:flutter_application_1/providers/chat_provider.dart';
import 'package:flutter_application_1/screens/chat_screen.dart';
import 'package:flutter_application_1/services/chat_rest_service.dart';
import 'package:flutter_application_1/widgets/chat_input_bar.dart';

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
  setUp(() {
    // No stored tokens -> AuthGate should land on the login screen.
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('app boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // The aurora background animates forever, so pump a fixed time instead
    // of waiting for everything to settle.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
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
      // Let the staggered rise-in animations finish.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Good'), findsOneWidget);
      expect(find.text('Ask anything. The lights are on.'), findsOneWidget);
    },
  );

  // Regression: wrapping the chat in a loose Stack (for drag & drop) once
  // shrank it and pushed the message box off-centre.
  for (final (label, size, expectedCenter) in [
    ('desktop', const Size(1440, 900), 280 + (1440 - 280) / 2),
    ('mobile', const Size(390, 844), 390 / 2),
  ]) {
    testWidgets('message box is centred in the chat area on $label', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

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
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      final box = tester.getRect(find.byType(ChatInputBar));
      expect(box.center.dx, moreOrLessEquals(expectedCenter, epsilon: 2));
    });
  }
}
