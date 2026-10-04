import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/config/theme.dart';
import 'package:flutter_application_1/providers/chat_provider.dart';
import 'package:flutter_application_1/widgets/chat_input_bar.dart';

Widget _composer({
  bool thinkLonger = false,
  ResponseStyle style = ResponseStyle.normal,
  ValueChanged<bool>? onThink,
  ValueChanged<ResponseStyle>? onStyle,
}) => MaterialApp(
  theme: AppTheme.darkTheme(),
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: ChatInputBar(
        controller: TextEditingController(),
        isStreaming: false,
        compact: true,
        onSend: () {},
        onChanged: (_) {},
        onAddFiles: (_) {},
        thinkLonger: thinkLonger,
        onThinkLongerChanged: onThink,
        responseStyle: style,
        onResponseStyleChanged: onStyle,
      ),
    ),
  ),
);

void main() {
  testWidgets('+ opens a menu with add-content and option entries', (
    tester,
  ) async {
    await tester.pumpWidget(_composer());
    await tester.tap(find.byTooltip('Add photos, files and more'));
    await tester.pumpAndSettle();

    expect(find.text('Upload photos & files'), findsOneWidget);
    expect(find.text('Paste text as file'), findsOneWidget);
    expect(find.text('Think longer'), findsOneWidget);
    expect(find.text('Response style'), findsOneWidget);
  });

  testWidgets('Take photo is offered on phones only', (tester) async {
    for (final (platform, shown) in [
      (TargetPlatform.android, true),
      (TargetPlatform.iOS, true),
      (TargetPlatform.windows, false),
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(_composer());
      await tester.tap(find.byTooltip('Add photos, files and more'));
      await tester.pumpAndSettle();
      expect(
        find.text('Take photo'),
        shown ? findsOneWidget : findsNothing,
        reason: '$platform',
      );
      await tester.pumpWidget(const SizedBox());
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('toggling Think longer reports the new value', (tester) async {
    bool? value;
    await tester.pumpWidget(_composer(onThink: (v) => value = v));
    await tester.tap(find.byTooltip('Add photos, files and more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Think longer'));
    await tester.pump(); // menu items fire onPressed after the next frame
    expect(value, isTrue);
  });

  testWidgets('choosing a response style reports it', (tester) async {
    ResponseStyle? picked;
    await tester.pumpWidget(_composer(onStyle: (s) => picked = s));
    await tester.tap(find.byTooltip('Add photos, files and more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Response style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concise'));
    await tester.pumpAndSettle();
    expect(picked, ResponseStyle.concise);
  });

  testWidgets('active options show as removable chips', (tester) async {
    bool? think;
    ResponseStyle? style;
    await tester.pumpWidget(
      _composer(
        thinkLonger: true,
        style: ResponseStyle.formal,
        onThink: (v) => think = v,
        onStyle: (s) => style = s,
      ),
    );
    expect(find.text('Think longer'), findsOneWidget);
    expect(find.text('Formal'), findsOneWidget);

    await tester.tap(find.byTooltip('Turn off Think longer'));
    await tester.tap(find.byTooltip('Turn off Formal'));
    expect(think, isFalse);
    expect(style, ResponseStyle.normal);
  });

  test('provider sends options and reset clears them', () {
    final provider = ChatProvider();
    provider.setThinkLonger(true);
    provider.setResponseStyle(ResponseStyle.explanatory);
    expect(provider.thinkLonger, isTrue);
    expect(provider.responseStyle, ResponseStyle.explanatory);
    provider.reset();
    expect(provider.thinkLonger, isFalse);
    expect(provider.responseStyle, ResponseStyle.normal);
  });
}
