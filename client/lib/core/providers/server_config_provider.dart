import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfig {
  final String baseUrl;
  final String socketUrl;

  ServerConfig({
    required this.baseUrl,
    required this.socketUrl,
  });

  ServerConfig copyWith({
    String? baseUrl,
    String? socketUrl,
  }) {
    return ServerConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      socketUrl: socketUrl ?? this.socketUrl,
    );
  }
}

class ServerConfigNotifier extends Notifier<ServerConfig> {
  static const String _baseUrlKey = 'server_base_url';
  static const String _socketUrlKey = 'server_socket_url';
  static const String _defaultBaseUrl = 'http://10.126.0.227:5000/api/v1';
  static const String _defaultSocketUrl = 'http://10.126.0.227:5000';

  @override
  ServerConfig build() {
    _loadConfig();
    return ServerConfig(
      baseUrl: _defaultBaseUrl,
      socketUrl: _defaultSocketUrl,
    );
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    final socketUrl = prefs.getString(_socketUrlKey) ?? _defaultSocketUrl;
    state = ServerConfig(baseUrl: baseUrl, socketUrl: socketUrl);
  }

  Future<void> updateConfig({
    required String baseUrl,
    required String socketUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
    await prefs.setString(_socketUrlKey, socketUrl);
    state = ServerConfig(baseUrl: baseUrl, socketUrl: socketUrl);
  }

  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    await prefs.remove(_socketUrlKey);
    state = ServerConfig(
      baseUrl: _defaultBaseUrl,
      socketUrl: _defaultSocketUrl,
    );
  }
}

final serverConfigProvider = NotifierProvider<ServerConfigNotifier, ServerConfig>(
  ServerConfigNotifier.new,
);
