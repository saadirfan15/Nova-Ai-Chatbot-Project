import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api_config.dart';
import 'token_storage.dart';

class ChatSocketService {
  WebSocketChannel? _channel;

  Future<WebSocketChannel> connect({required String token}) async {
    final uri = Uri.parse('${ApiConfig.wsUrl}?token=$token');
    _channel = WebSocketChannel.connect(uri);
    return _channel!;
  }

  Future<WebSocketChannel> connectWithStoredToken() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('No access token');
    }
    return connect(token: token);
  }

  void sendMessage({required String message, String? conversationId}) {
    if (_channel == null) return;
    final payload = jsonEncode({
      'message': message,
      'conversation_id': conversationId,
    });
    _channel!.sink.add(payload);
  }

  void close() {
    _channel?.sink.close();
    _channel = null;
  }
}
