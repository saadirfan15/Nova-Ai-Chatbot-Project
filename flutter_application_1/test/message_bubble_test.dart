import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/widgets/message_bubble.dart';

ChatMessage _assistant({
  String content = '',
  String reasoning = '',
  double? seconds,
}) => ChatMessage(
  id: 'a1',
  role: 'assistant',
  content: content,
  reasoning: reasoning,
  thinkingSeconds: seconds,
  createdAt: DateTime(2026, 1, 1),
);

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  test('ChatMessage.fromJson reads reasoning', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'role': 'assistant',
      'content': 'Hi',
      'reasoning': 'User said hi.',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(message.reasoning, 'User said hi.');
    expect(message.thinkingSeconds, isNull);
  });

  testWidgets('shows a live Thinking panel with the reasoning while thinking', (
    tester,
  ) async {
    await _pump(
      tester,
      MessageBubble(
        message: _assistant(reasoning: 'Weighing options'),
        isStreaming: true,
      ),
    );
    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.text('Weighing options'), findsOneWidget);
  });

  testWidgets('collapses to "Thought for Ns" once the answer arrives', (
    tester,
  ) async {
    await _pump(
      tester,
      MessageBubble(
        message: _assistant(
          content: 'The answer',
          reasoning: 'Weighing options',
          seconds: 3.2,
        ),
      ),
    );
    expect(find.text('Thought for 3s'), findsOneWidget);
    expect(find.text('Weighing options'), findsNothing);

    await tester.tap(find.text('Thought for 3s'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Weighing options'), findsOneWidget);
    expect(find.byTooltip('Copy reply'), findsOneWidget);
  });

  testWidgets('history without timing says "Thought process"', (tester) async {
    await _pump(
      tester,
      MessageBubble(
        message: _assistant(content: 'Hi', reasoning: 'r'),
      ),
    );
    expect(find.text('Thought process'), findsOneWidget);
  });
}
