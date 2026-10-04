import 'dart:typed_data';

/// A file attached to a message (as returned by the backend).
class ChatAttachment {
  final String id;
  final String name;
  final String contentType;
  final int size;

  /// "image" or "document".
  final String kind;

  /// Local bytes for files picked on this device, so previews don't need a
  /// download. Null for attachments loaded from history.
  final Uint8List? bytes;

  const ChatAttachment({
    required this.id,
    required this.name,
    required this.contentType,
    required this.size,
    required this.kind,
    this.bytes,
  });

  bool get isImage => kind == 'image';

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'file',
    contentType: json['content_type']?.toString() ?? '',
    size: (json['size'] as num?)?.toInt() ?? 0,
    kind: json['kind']?.toString() ?? 'document',
  );

  ChatAttachment withBytes(Uint8List data) => ChatAttachment(
    id: id,
    name: name,
    contentType: contentType,
    size: size,
    kind: kind,
    bytes: data,
  );
}

enum UploadStatus { uploading, ready }

/// A file picked in the composer that hasn't been sent yet.
class PendingAttachment {
  final String localId;
  final String name;
  final Uint8List bytes;
  final UploadStatus status;
  final ChatAttachment? uploaded;

  const PendingAttachment({
    required this.localId,
    required this.name,
    required this.bytes,
    this.status = UploadStatus.uploading,
    this.uploaded,
  });

  bool get isImage => AttachmentRules.isImage(name);
  bool get isReady => status == UploadStatus.ready && uploaded != null;

  PendingAttachment ready(ChatAttachment attachment) => PendingAttachment(
    localId: localId,
    name: name,
    bytes: bytes,
    status: UploadStatus.ready,
    uploaded: attachment.withBytes(bytes),
  );
}

/// Mirrors the backend's accepted types and limits (apps/chat/attachments.py)
/// so users get instant feedback instead of a failed upload.
class AttachmentRules {
  static const maxFiles = 10;
  static const maxImageBytes = 4 * 1024 * 1024;
  static const maxDocumentBytes = 10 * 1024 * 1024;

  static const imageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
  static const documentExtensions = [
    'pdf',
    'txt',
    'md',
    'markdown',
    'csv',
    'tsv',
    'json',
    'xml',
    'yaml',
    'yml',
    'html',
    'htm',
    'css',
    'js',
    'jsx',
    'ts',
    'tsx',
    'py',
    'dart',
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
    'log',
    'ini',
    'toml',
  ];

  static List<String> get allExtensions => [
    ...imageExtensions,
    ...documentExtensions,
  ];

  static String extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  static bool isImage(String name) => imageExtensions.contains(extension(name));

  /// Null when the file is acceptable, otherwise a user-facing reason.
  static String? problem(String name, int size) {
    final ext = extension(name);
    if (imageExtensions.contains(ext)) {
      return size > maxImageBytes ? '$name is larger than 4 MB.' : null;
    }
    if (documentExtensions.contains(ext)) {
      return size > maxDocumentBytes ? '$name is larger than 10 MB.' : null;
    }
    return '$name: unsupported file type.';
  }
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
