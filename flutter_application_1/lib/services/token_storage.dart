import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  static Future<String?> getAccessToken() => _read('access_token');

  static Future<String?> getRefreshToken() => _read('refresh_token');

  /// Secure storage can hang on some platforms (e.g. web without a secure
  /// context), so never wait on it forever.
  static Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key).timeout(const Duration(seconds: 5));
    } catch (e) {
      return null;
    }
  }
}
