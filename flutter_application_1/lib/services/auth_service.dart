import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'token_storage.dart';

class AuthService {
  static const _baseUrl = ApiConfig.baseUrl;

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await TokenStorage.saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );
      return data;
    }
    throw Exception(data['detail'] ?? data['message'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final result = await InternetAddress.lookup(
        'nova-ai-backend-ogch.onrender.com',
      );
      print("DNS RESULT: $result");

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      print("STATUS CODE: ${response.statusCode}");
      print("BODY: ${response.body}");

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await TokenStorage.saveTokens(
          accessToken: data['access'],
          refreshToken: data['refresh'],
        );
        return data;
      }

      throw Exception(data['detail'] ?? data['message'] ?? 'Login failed');
    } catch (e, st) {
      print("ERROR: $e");
      print(st);
      rethrow;
    }
  }
  // Future<Map<String, dynamic>> login({
  //   required String username,
  //   required String password,
  // }) async {
  //   final response = await http.post(
  //     Uri.parse('$_baseUrl/auth/login/'),
  //     headers: {'Content-Type': 'application/json'},
  //     body: jsonEncode({'username': username, 'password': password}),
  //   );

  //   final data = jsonDecode(response.body) as Map<String, dynamic>;
  //   if (response.statusCode >= 200 && response.statusCode < 300) {
  //     await TokenStorage.saveTokens(
  //       accessToken: data['access'],
  //       refreshToken: data['refresh'],
  //     );
  //     return data;
  //   }
  //   throw Exception(data['detail'] ?? data['message'] ?? 'Login failed');
  // }

  Future<String?> refreshToken() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null) return null;

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final access = data['access']?.toString();
      if (access != null) {
        await TokenStorage.saveTokens(
          accessToken: access,
          refreshToken: refresh,
        );
        return access;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$_baseUrl/auth/me/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
  }
}
