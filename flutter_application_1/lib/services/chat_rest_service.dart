import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/attachment.dart';
import '../models/conversation.dart';
import 'auth_service.dart';

class ChatRestService {
  ChatRestService({AuthService? authService})
    : _authService = authService ?? AuthService();

  static const _baseUrl = '${ApiConfig.baseUrl}/chat/conversations';
  static const _attachmentsUrl = '${ApiConfig.baseUrl}/chat/attachments';

  final AuthService _authService;

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getValidAccessToken();
    if (token == null) {
      throw Exception('Session expired. Please log in again.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Conversation> createConversation() async {
    final response = await http.post(
      Uri.parse('$_baseUrl/'),
      headers: {...await _authHeaders(), 'Content-Type': 'application/json'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Conversation.fromJson(Map<String, dynamic>.from(decoded));
      }
      throw Exception('Unexpected conversation payload');
    }
    throw Exception('Unable to create conversation');
  }

  Future<List<Conversation>> fetchConversations() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    throw Exception('Unable to load conversations');
  }

  Future<Conversation> fetchConversation(String id) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$id/'),
      headers: await _authHeaders(),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Conversation.fromJson(jsonDecode(response.body));
    }
    throw Exception('Unable to load conversation');
  }

  /// Uploads one file; it is linked to a message when that message is sent.
  Future<ChatAttachment> uploadAttachment({
    required String name,
    required Uint8List bytes,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$_attachmentsUrl/'))
          ..headers.addAll(await _authHeaders())
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: name),
          );
    final response = await http.Response.fromStream(await request.send());

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ChatAttachment.fromJson(jsonDecode(response.body));
    }
    String detail = 'Could not upload $name';
    try {
      detail =
          (jsonDecode(response.body) as Map)['detail']?.toString() ?? detail;
    } catch (_) {}
    throw Exception(detail);
  }

  /// Downloads an attachment's bytes (used for image previews in history).
  Future<Uint8List> fetchAttachmentBytes(String id) async {
    final response = await http.get(
      Uri.parse('$_attachmentsUrl/$id/file/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw Exception('Unable to load attachment');
  }

  Future<void> deleteConversation(String id) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$id/'),
      headers: await _authHeaders(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to delete conversation');
    }
  }
}
