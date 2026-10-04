import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  AuthProvider({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;

  bool _isLoading = false;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _errorMessage;
  String? _accessToken;

  bool get isLoading => _isLoading;
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get accessToken => _accessToken;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // getCurrentUser refreshes an expired access token automatically.
    final user = await _authService.getCurrentUser();
    _isAuthenticated = user != null;
    _user = user;
    _accessToken = null;
    _errorMessage = null;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    _setBusy();
    try {
      final data = await _authService.login(
        username: username,
        password: password,
      );
      _accessToken = data['access']?.toString();
      // The login endpoint only returns tokens, so fetch the profile.
      _user = await _authService.getCurrentUser() ?? {'username': username};
      _isAuthenticated = true;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _readable(e);
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
  }) async {
    _setBusy();
    try {
      final data = await _authService.register(
        username: username,
        email: email,
        password: password,
      );
      _accessToken = data['access']?.toString();
      _user = data['user'];
      _isAuthenticated = true;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _readable(e);
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _user = null;
    _accessToken = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setBusy() {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
  }

  static String _readable(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
}
