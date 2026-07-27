import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class DnsSafeHttp {
  static final Map<String, String> _cache = {};

  static Future<String?> _resolveViaGoogleDoH(String host) async {
    if (_cache.containsKey(host)) return _cache[host];
    try {
      final client = HttpClient();
      final uri = Uri.parse('https://dns.google/resolve?name=$host&type=A');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      client.close();
      final data = jsonDecode(body);
      final answers = data['Answer'] as List<dynamic>?;
      if (answers != null) {
        for (final a in answers) {
          if (a['type'] == 1) {
            _cache[host] = a['data'];
            return a['data'] as String;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static http.Client buildClient() {
    final httpClient = HttpClient();
    httpClient.connectionFactory =
        (Uri uri, String? proxyHost, int? proxyPort) async {
          final ip = await _resolveViaGoogleDoH(uri.host);
          final target = ip ?? uri.host;
          final socket = await Socket.connect(
            target,
            uri.port,
            timeout: const Duration(seconds: 10),
          );
          return ConnectionTask.fromSocket(
            Future.value(socket),
            () => socket.destroy(),
          );
        };
    return IOClient(httpClient);
  }
}
