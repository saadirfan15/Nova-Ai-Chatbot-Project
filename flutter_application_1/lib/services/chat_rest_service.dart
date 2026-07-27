import 'dart:convert';
import '../config/api_config.dart';
import '../models/conversation.dart';
import '../utils/dns_safe_client.dart';
import 'token_storage.dart';

class ChatRestService {
  static const _baseUrl = ApiConfig.baseUrl;

  Future<Conversation> createConversation() async {
    final token = await TokenStorage.getAccessToken();
    final endpoints = <String>[
      '$_baseUrl/conversations/',
      '$_baseUrl/chat/conversations/',
    ];

    final client = DnsSafeHttp.buildClient();
    try {
      for (final endpoint in endpoints) {
        final response = await client.post(
          Uri.parse(endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            return Conversation.fromJson(decoded);
          }
          if (decoded is Map) {
            return Conversation.fromJson(Map<String, dynamic>.from(decoded));
          }
          throw Exception('Unexpected conversation payload');
        }

        if (response.statusCode != 404) {
          break;
        }
      }

      throw Exception('Unable to create conversation');
    } finally {
      client.close();
    }
  }

  Future<List<Conversation>> fetchConversations() async {
    final token = await TokenStorage.getAccessToken();
    final client = DnsSafeHttp.buildClient();
    try {
      final response = await client.get(
        Uri.parse('$_baseUrl/chat/conversations/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map(
              (item) => Conversation(
                id: item['id'].toString(),
                title: item['title']?.toString() ?? 'New chat',
                createdAt: DateTime.parse(
                  item['created_at'] ?? DateTime.now().toIso8601String(),
                ),
                updatedAt: DateTime.parse(
                  item['updated_at'] ?? DateTime.now().toIso8601String(),
                ),
              ),
            )
            .toList();
      }
      throw Exception('Unable to load conversations');
    } finally {
      client.close();
    }
  }

  Future<Conversation> fetchConversation(String id) async {
    final token = await TokenStorage.getAccessToken();
    final client = DnsSafeHttp.buildClient();
    try {
      final response = await client.get(
        Uri.parse('$_baseUrl/chat/conversations/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Conversation.fromJson(jsonDecode(response.body));
      }
      throw Exception('Unable to load conversation');
    } finally {
      client.close();
    }
  }

  Future<void> deleteConversation(String id) async {
    final token = await TokenStorage.getAccessToken();
    final client = DnsSafeHttp.buildClient();
    try {
      final response = await client.delete(
        Uri.parse('$_baseUrl/chat/conversations/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Unable to delete conversation');
      }
    } finally {
      client.close();
    }
  }
}
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import '../config/api_config.dart';
// import '../models/conversation.dart';
// import 'token_storage.dart';

// class ChatRestService {
//   static const _baseUrl = ApiConfig.baseUrl;

//   Future<Conversation> createConversation() async {
//     final token = await TokenStorage.getAccessToken();
//     final endpoints = <String>[
//       '$_baseUrl/conversations/',
//       '$_baseUrl/chat/conversations/',
//     ];

//     for (final endpoint in endpoints) {
//       final response = await http.post(
//         Uri.parse(endpoint),
//         headers: {
//           'Authorization': 'Bearer $token',
//           'Content-Type': 'application/json',
//         },
//       );

//       if (response.statusCode >= 200 && response.statusCode < 300) {
//         final decoded = jsonDecode(response.body);
//         if (decoded is Map<String, dynamic>) {
//           return Conversation.fromJson(decoded);
//         }
//         if (decoded is Map) {
//           return Conversation.fromJson(Map<String, dynamic>.from(decoded));
//         }
//         throw Exception('Unexpected conversation payload');
//       }

//       if (response.statusCode != 404) {
//         break;
//       }
//     }

//     throw Exception('Unable to create conversation');
//   }

//   Future<List<Conversation>> fetchConversations() async {
//     final token = await TokenStorage.getAccessToken();
//     final response = await http.get(
//       Uri.parse('$_baseUrl/chat/conversations/'),
//       headers: {'Authorization': 'Bearer $token'},
//     );

//     if (response.statusCode >= 200 && response.statusCode < 300) {
//       final data = jsonDecode(response.body) as List<dynamic>;
//       return data
//           .map(
//             (item) => Conversation(
//               id: item['id'].toString(),
//               title: item['title']?.toString() ?? 'New chat',
//               createdAt: DateTime.parse(
//                 item['created_at'] ?? DateTime.now().toIso8601String(),
//               ),
//               updatedAt: DateTime.parse(
//                 item['updated_at'] ?? DateTime.now().toIso8601String(),
//               ),
//             ),
//           )
//           .toList();
//     }
//     throw Exception('Unable to load conversations');
//   }

//   Future<Conversation> fetchConversation(String id) async {
//     final token = await TokenStorage.getAccessToken();
//     final response = await http.get(
//       Uri.parse('$_baseUrl/chat/conversations/$id/'),
//       headers: {'Authorization': 'Bearer $token'},
//     );

//     if (response.statusCode >= 200 && response.statusCode < 300) {
//       return Conversation.fromJson(jsonDecode(response.body));
//     }
//     throw Exception('Unable to load conversation');
//   }

//   Future<void> deleteConversation(String id) async {
//     final token = await TokenStorage.getAccessToken();
//     final response = await http.delete(
//       Uri.parse('$_baseUrl/chat/conversations/$id/'),
//       headers: {'Authorization': 'Bearer $token'},
//     );
//     if (response.statusCode < 200 || response.statusCode >= 300) {
//       throw Exception('Unable to delete conversation');
//     }
//   }
// }
