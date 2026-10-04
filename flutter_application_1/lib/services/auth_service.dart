import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'token_storage.dart';

class AuthService {
  static const _baseUrl = ApiConfig.baseUrl;

  /// Refresh this long before the access token actually expires.
  static const _expiryLeeway = Duration(seconds: 30);

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/register/'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );

    final data = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await TokenStorage.saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );
      return data;
    }
    throw Exception(_errorText(data, 'Registration failed'));
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await TokenStorage.saveTokens(
        accessToken: data['access'],
        refreshToken: data['refresh'],
      );
      return data;
    }
    throw Exception(_errorText(data, 'Login failed'));
  }

  Future<String?> refreshToken() async {
    final refresh = await TokenStorage.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refresh}),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final data = _decode(response);
      final access = data['access']?.toString();
      if (access == null) return null;

      // ROTATE_REFRESH_TOKENS is on, so the backend may hand back a new one.
      await TokenStorage.saveTokens(
        accessToken: access,
        refreshToken: data['refresh']?.toString() ?? refresh,
      );
      return access;
    } catch (_) {
      return null;
    }
  }

  /// Returns an access token that is not about to expire, refreshing it via
  /// the refresh token when needed. Returns null if the user must log in again.
  Future<String?> getValidAccessToken() async {
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty && !_isExpiringSoon(token)) {
      return token;
    }
    return refreshToken();
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getValidAccessToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _decode(response);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
  }

  static bool _isExpiringSoon(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! num) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().add(_expiryLeeway).isAfter(expiresAt);
    } catch (_) {
      return true;
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  /// DRF returns either {"detail": "..."} or field errors like
  /// {"username": ["A user with that username already exists."]}.
  static String _errorText(Map<String, dynamic> data, String fallback) {
    final detail = data['detail'] ?? data['message'];
    if (detail != null) return detail.toString();
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }
}
