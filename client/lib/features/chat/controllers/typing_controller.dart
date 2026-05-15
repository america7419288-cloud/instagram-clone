import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/socket/socket_events.dart';

/// Manages typing indicators with debouncing
class TypingController extends ChangeNotifier {
  final SocketService _socket;
  final String conversationId;

  TypingController({
    required SocketService socket,
    required this.conversationId,
  }) : _socket = socket {
    _setupListeners();
  }

  // Other users currently typing
  final Set<String> _typingUserIds = {};
  
  // Map of userId → cleanup timer (auto-stop after 6s as safety)
  final Map<String, Timer> _typingTimers = {};

  // My typing state
  bool _amITyping = false;
  Timer? _stopTypingTimer;

  StreamSubscription? _typingSub;

  Set<String> get typingUserIds => _typingUserIds;
  bool get isAnyoneTyping => _typingUserIds.isNotEmpty;

  void _setupListeners() {
    _typingSub = _socket.typingStream.listen((data) {
      if (data[SocketKeys.conversationId] != conversationId) return;

      final userId = data[SocketKeys.userId] as String?;
      final isTyping = data['isTyping'] as bool? ?? true; // Default to true if not specified

      if (userId == null) return;

      if (isTyping) {
        _typingUserIds.add(userId);
        // Reset/Start auto-clear timer
        _typingTimers[userId]?.cancel();
        _typingTimers[userId] = Timer(const Duration(seconds: 6), () {
          _typingUserIds.remove(userId);
          _typingTimers.remove(userId);
          notifyListeners();
        });
      } else {
        _typingUserIds.remove(userId);
        _typingTimers[userId]?.cancel();
        _typingTimers.remove(userId);
      }
      notifyListeners();
    });
  }

  void onTyping() {
    if (!_amITyping) {
      _amITyping = true;
      _socket.setTyping(conversationId, true);
    }

    // Debounce: Reset the "stop typing" timer every time user types
    _stopTypingTimer?.cancel();
    _stopTypingTimer = Timer(const Duration(seconds: 3), () {
      _amITyping = false;
      _socket.setTyping(conversationId, false);
    });
  }

  @override
  void dispose() {
    _typingSub?.cancel();
    _typingTimers.values.forEach((t) => t.cancel());
    _stopTypingTimer?.cancel();
    super.dispose();
  }
}
