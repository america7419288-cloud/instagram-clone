import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

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
  
  static String get _defaultBaseUrl {
    return AppConstants.baseUrl;
  }

  static String get _defaultSocketUrl {
    return AppConstants.socketUrl;
  }

  @override
  ServerConfig build() {
    _loadConfig();
    return ServerConfig(
      baseUrl: _defaultBaseUrl,
      socketUrl: _defaultSocketUrl,
    );
  }

  Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBaseUrl = prefs.getString(_baseUrlKey);
      final savedSocketUrl = prefs.getString(_socketUrlKey);

      String baseUrl = savedBaseUrl ?? _defaultBaseUrl;
      String socketUrl = savedSocketUrl ?? _defaultSocketUrl;

      final isAndroid = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android);

      debugPrint('⚙️ [ServerConfigNotifier] Initial config load: savedBaseUrl=$savedBaseUrl, savedSocketUrl=$savedSocketUrl');
      debugPrint('⚙️ [ServerConfigNotifier] Platform info: kDebugMode=$kDebugMode, kIsWeb=$kIsWeb, isAndroid=$isAndroid');

      if (kDebugMode) {
        bool needsHealing = false;
        if (isAndroid && baseUrl.contains('localhost')) {
          needsHealing = true;
        } else {
          // Detect if the cached URL host is local but the port is misconfigured (i.e. not 5000)
          final uri = Uri.tryParse(baseUrl);
          if (uri != null) {
            final host = uri.host.toLowerCase();
            if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
              if (uri.port != 5000) {
                needsHealing = true;
                debugPrint('⚙️ [ServerConfigNotifier] Stale or misconfigured local port (${uri.port}) detected.');
              }
            }
          }
        }

        if (needsHealing) {
          debugPrint('⚙️ [ServerConfigNotifier] Healing config from "$baseUrl" to "$_defaultBaseUrl"');
          baseUrl = _defaultBaseUrl;
          socketUrl = _defaultSocketUrl;
          await prefs.setString(_baseUrlKey, baseUrl);
          await prefs.setString(_socketUrlKey, socketUrl);
        }
      }

      state = ServerConfig(baseUrl: baseUrl, socketUrl: socketUrl);
      debugPrint('⚙️ [ServerConfigNotifier] Active state initialized: ${state.baseUrl}');
    } catch (e, stack) {
      debugPrint('🚨 [ServerConfigNotifier] Error loading config: $e\n$stack');
    }
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
