import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

class PresenceController extends ChangeNotifier {
  final SocketService _socket;

  PresenceController({required SocketService socket}) : _socket = socket {
    _setupListeners();
  }

  // Map of userId -> isOnline
  final Map<String, bool> _presenceMap = {};
  // Map of userId -> lastSeen
  final Map<String, DateTime> _lastSeenMap = {};
  
  StreamSubscription? _presenceSub;

  void _setupListeners() {
    _presenceSub = _socket.presenceStream.listen((data) {
      final userId = data[SocketKeys.userId] as String?;
      final status = data['status'] as String?; // 'online' or 'offline'
      final lastSeenStr = data['lastSeen'] as String?;

      if (userId == null) return;

      if (status == 'online') {
        _presenceMap[userId] = true;
      } else if (status == 'offline') {
        _presenceMap[userId] = false;
        if (lastSeenStr != null) {
          _lastSeenMap[userId] = DateTime.tryParse(lastSeenStr) ?? DateTime.now();
        }
      }
      notifyListeners();
    });
  }

  bool isUserOnline(String userId) => _presenceMap[userId] ?? false;
  
  DateTime? getLastSeen(String userId) => _lastSeenMap[userId];

  @override
  void dispose() {
    _presenceSub?.cancel();
    super.dispose();
  }
}
