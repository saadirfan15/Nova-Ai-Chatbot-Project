import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/attachment.dart';
import 'package:flutter_application_1/models/conversation.dart';
import 'package:flutter_application_1/models/message.dart';
import 'package:flutter_application_1/providers/chat_provider.dart';
import 'package:flutter_application_1/services/chat_rest_service.dart';
import 'package:flutter_application_1/widgets/chat_input_bar.dart';

class FakeUploadRestService extends ChatRestService {
  final uploads = <String>[];
  Completer<void>? gate;

  @override
  Future<Conversation> createConversation() async => Conversation(
    id: 'c1',
    title: 'New chat',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  @override
  Future<ChatAttachment> uploadAttachment({
    required String name,
    required Uint8List bytes,
  }) async {
    await gate?.future;
    uploads.add(name);
    if (name.startsWith('fail')) throw Exception('Server said no');
    return ChatAttachment(
      id: 'srv-$name',
      name: name,
      contentType: 'text/plain',
      size: bytes.length,
      kind: AttachmentRules.isImage(name) ? 'image' : 'document',
    );
  }
}

final _bytes = Uint8List.fromList([1, 2, 3]);

void main() {
  group('AttachmentRules', () {
    test('accepts images, PDFs and code; rejects others', () {
      expect(AttachmentRules.problem('photo.JPG', 10), isNull);
      expect(AttachmentRules.problem('report.pdf', 10), isNull);
      expect(AttachmentRules.problem('main.dart', 10), isNull);
      expect(AttachmentRules.problem('setup.exe', 10), contains('unsupported'));
    });

    test('enforces size limits', () {
      expect(
        AttachmentRules.problem('big.png', AttachmentRules.maxImageBytes + 1),
        contains('4 MB'),
      );
      expect(
        AttachmentRules.problem(
          'big.pdf',
          AttachmentRules.maxDocumentBytes + 1,
        ),
        contains('10 MB'),
      );
    });

    test('formats sizes', () {
      expect(formatFileSize(900), '900 B');
      expect(formatFileSize(2048), '2 KB');
      expect(formatFileSize(3 * 1024 * 1024), '3.0 MB');
    });
  });

  test('ChatMessage.fromJson reads attachments', () {
    final m = ChatMessage.fromJson({
      'id': 'm',
      'role': 'user',
      'content': '',
      'created_at': '2026-01-01T00:00:00Z',
      'attachments': [
        {
          'id': 'a1',
          'name': 'cat.png',
          'content_type': 'image/png',
          'size': 42,
          'kind': 'image',
        },
      ],
    });
    expect(m.attachments.single.isImage, isTrue);
    expect(m.attachments.single.size, 42);
  });

  group('ChatProvider attachments', () {
    test('uploads accepted files and becomes ready', () async {
      final rest = FakeUploadRestService();
      final provider = ChatProvider(restService: rest);

      await provider.addAttachments([(name: 'notes.txt', bytes: _bytes)]);

      expect(rest.uploads, ['notes.txt']);
      expect(provider.pendingAttachments.single.isReady, isTrue);
      expect(provider.pendingAttachments.single.uploaded!.id, 'srv-notes.txt');
      expect(provider.isUploading, isFalse);
    });

    test('rejects unsupported files without uploading them', () async {
      final rest = FakeUploadRestService();
      final provider = ChatProvider(restService: rest);

      await provider.addAttachments([(name: 'virus.exe', bytes: _bytes)]);

      expect(rest.uploads, isEmpty);
      expect(provider.pendingAttachments, isEmpty);
      expect(provider.errorMessage, contains('unsupported'));
    });

    test('drops a failed upload and reports the server error', () async {
      final provider = ChatProvider(restService: FakeUploadRestService());

      await provider.addAttachments([(name: 'fail.txt', bytes: _bytes)]);

      expect(provider.pendingAttachments, isEmpty);
      expect(provider.errorMessage, 'Server said no');
    });

    test(
      'is uploading until the server answers; files can be removed',
      () async {
        final rest = FakeUploadRestService()..gate = Completer<void>();
        final provider = ChatProvider(restService: rest);

        final pending = provider.addAttachments([
          (name: 'a.md', bytes: _bytes),
        ]);
        expect(provider.isUploading, isTrue);

        final localId = provider.pendingAttachments.single.localId;
        provider.removeAttachment(localId);
        rest.gate!.complete();
        await pending;

        expect(provider.pendingAttachments, isEmpty);
        expect(provider.isUploading, isFalse);
      },
    );
  });

  testWidgets('composer shows the + button, pending files and remove', (
    tester,
  ) async {
    final removed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatInputBar(
            controller: TextEditingController(),
            isStreaming: false,
            compact: true,
            onSend: () {},
            onChanged: (_) {},
            onAddFiles: (_) {},
            onRemoveAttachment: removed.add,
            attachments: [
              PendingAttachment(
                localId: 'l1',
                name: 'report.pdf',
                bytes: _bytes,
              ).ready(
                const ChatAttachment(
                  id: 's1',
                  name: 'report.pdf',
                  contentType: 'application/pdf',
                  size: 3,
                  kind: 'document',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Add photos, files and more'), findsOneWidget);
    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('PDF · 3 B'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Remove report.pdf'));
    expect(removed, ['l1']);
  });
}
