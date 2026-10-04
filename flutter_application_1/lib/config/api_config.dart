/// Backend endpoints. Defaults to the deployed backend; override for local
/// development without editing code, e.g.:
///
///   flutter run --dart-define=API_HOST=http://127.0.0.1:8000
///
/// (Android emulator: use http://10.0.2.2:8000.) The WebSocket URL is derived
/// from the same host (http -> ws, https -> wss).
class ApiConfig {
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://nova-ai-chatbot-project-production.up.railway.app',
  );

  static const String baseUrl = '$host/api';

  static String get wsUrl =>
      '${host.replaceFirst(RegExp(r'^http'), 'ws')}/ws/chat/';
}
