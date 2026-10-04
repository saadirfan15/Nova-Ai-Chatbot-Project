import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../models/attachment.dart';
import '../providers/chat_provider.dart';

const _codeExtensions = {
  'py',
  'dart',
  'js',
  'jsx',
  'ts',
  'tsx',
  'java',
  'kt',
  'swift',
  'c',
  'h',
  'cpp',
  'hpp',
  'cs',
  'go',
  'rs',
  'rb',
  'php',
  'sql',
  'sh',
  'html',
  'htm',
  'css',
  'json',
  'xml',
  'yaml',
  'yml',
  'toml',
  'ini',
};

IconData fileIcon(String name) {
  final ext = AttachmentRules.extension(name);
  if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
  if (ext == 'csv' || ext == 'tsv') return Icons.table_chart_outlined;
  if (_codeExtensions.contains(ext)) return Icons.code_rounded;
  return Icons.description_outlined;
}

String fileLabel(String name, int size) {
  final ext = AttachmentRules.extension(name).toUpperCase();
  return '${ext.isEmpty ? 'FILE' : ext} · ${formatFileSize(size)}';
}

/// Square image preview. Uses local bytes when available, otherwise downloads
/// the file through the (authenticated) API. Tapping opens a full preview.
class AttachmentImage extends StatelessWidget {
  final ChatAttachment? attachment;
  final Uint8List? bytes;
  final double size;
  final String name;

  const AttachmentImage({
    super.key,
    this.attachment,
    this.bytes,
    required this.name,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final local = bytes ?? attachment?.bytes;
    final Widget image = local != null
        ? _image(context, local)
        : FutureBuilder<Uint8List>(
            future: context.read<ChatProvider>().loadAttachment(attachment!.id),
            builder: (context, snapshot) {
              final data = snapshot.data;
              if (data != null && data.isNotEmpty) return _image(context, data);
              return Container(
                color: AppTheme.surface,
                alignment: Alignment.center,
                child: snapshot.hasError
                    ? const Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.muted,
                      )
                    : const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              );
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  Widget _image(BuildContext context, Uint8List data) => Semantics(
    image: true,
    label: name,
    child: GestureDetector(
      onTap: () => showImagePreview(context, data, name),
      child: MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        child: Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true),
      ),
    ),
  );
}

Future<void> showImagePreview(
  BuildContext context,
  Uint8List bytes,
  String name,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.85),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton.filled(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Compact card for a document: icon, file name and type/size (or status).
class AttachmentFileTile extends StatelessWidget {
  final String name;
  final int size;
  final bool uploading;

  const AttachmentFileTile({
    super.key,
    required this.name,
    required this.size,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      height: 56,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: uploading
                ? const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(fileIcon(name), size: 20, color: AppTheme.accentText),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  uploading ? 'Uploading…' : fileLabel(name, size),
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a list of sent attachments (images as thumbnails, documents as tiles).
class AttachmentGallery extends StatelessWidget {
  final List<ChatAttachment> attachments;
  final WrapAlignment alignment;
  const AttachmentGallery({
    super.key,
    required this.attachments,
    this.alignment = WrapAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in attachments)
          a.isImage
              ? AttachmentImage(attachment: a, name: a.name, size: 140)
              : AttachmentFileTile(name: a.name, size: a.size),
      ],
    );
  }
}
