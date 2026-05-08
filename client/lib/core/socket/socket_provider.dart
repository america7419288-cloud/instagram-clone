// lib/core/socket/socket_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:instagram_clinet/core/providers/server_config_provider.dart';
import 'socket_service.dart';

// ─── SOCKET STATE ────────────────────────────────────────────
class SocketState {
  final bool isConnected;
  final Set<String> onlineUserIds;
  // Map: conversationId → userId who is typing
  final Map<String, String?> typingUsers;

  const SocketState({
    this.isConnected = false,
    this.onlineUserIds = const {},
    this.typingUsers = const {},
  });

  SocketState copyWith({
    bool? isConnected,
    Set<String>? onlineUserIds,
    Map<String, String?>? typingUsers,
  }) {
    return SocketState(
      isConnected: isConnected ?? this.isConnected,
      onlineUserIds: onlineUserIds ?? this.onlineUserIds,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }

  bool isUserOnline(String userId) => onlineUserIds.contains(userId);

  String? getTypingUser(String conversationId) => typingUsers[conversationId];
}

// ─── SOCKET NOTIFIER ─────────────────────────────────────────
class SocketNotifier extends StateNotifier<SocketState> {
  final SocketService _socketService;

  // Callbacks for other providers to register
  // When new message arrives, ChatNotifier handles it
  final Map<String, Function(Map<String, dynamic>)> _messageHandlers = {};
  final Map<String, Function(Map<String, dynamic>)> _inboxHandlers = {};

  SocketNotifier(this._socketService) : super(const SocketState()) {
    _setupCallbacks();
  }

  // ─── SETUP CALLBACKS ──────────────────────────────────────
  void _setupCallbacks() {
    // New message received
    _socketService.onNewMessage = (data) {
      final conversationId = data['conversation_id'] as String? ?? '';

      // Notify registered message handler for this conversation
      if (_messageHandlers.containsKey(conversationId)) {
        _messageHandlers[conversationId]!(data);
      }

      // Always notify inbox handlers
      _inboxHandlers.forEach((_, handler) => handler(data));
    };

    // User typing
    _socketService.onUserTyping = (conversationId, userId, isTyping) {
      if (!mounted) return;
      final updatedTyping = Map<String, String?>.from(state.typingUsers);

      if (isTyping) {
        updatedTyping[conversationId] = userId;
      } else {
        updatedTyping.remove(conversationId);
      }

      state = state.copyWith(typingUsers: updatedTyping);
    };

    // Online users list (received on connect)
    _socketService.onOnlineUsers = (userIds) {
      if (!mounted) return;
      state = state.copyWith(
        isConnected: true,
        onlineUserIds: Set<String>.from(userIds),
      );
    };

    // User came online
    _socketService.onUserOnlineStatus = (userId, isOnline) {
      if (!mounted) return;
      final updated = Set<String>.from(state.onlineUserIds);

      if (isOnline) {
        updated.add(userId);
      } else {
        updated.remove(userId);
      }

      state = state.copyWith(onlineUserIds: updated);
    };

    // Inbox update (message from someone not in chat right now)
    _socketService.onInboxUpdate = (data) {
      if (!mounted) return;
      // Notify all inbox handlers
      _inboxHandlers.forEach((_, handler) => handler(data));
    };
  }

  // ─── CONNECT ──────────────────────────────────────────────
  Future<void> connect() async {
    await _socketService.connect();
    if (mounted) {
      state = state.copyWith(isConnected: _socketService.isConnected);
    }
  }

  // ─── DISCONNECT ───────────────────────────────────────────
  void disconnect() {
    _socketService.disconnect();
    if (mounted) {
      state = const SocketState();
    }
  }

  // ─── JOIN ROOM ────────────────────────────────────────────
  void joinRoom(String conversationId) {
    _socketService.joinRoom(conversationId);
  }

  // ─── LEAVE ROOM ───────────────────────────────────────────
  void leaveRoom(String conversationId) {
    _socketService.leaveRoom(conversationId);
    // Clear typing indicator when leaving
    if (mounted) {
      final updated = Map<String, String?>.from(state.typingUsers);
      updated.remove(conversationId);
      state = state.copyWith(typingUsers: updated);
    }
  }

  // ─── EMIT TYPING ──────────────────────────────────────────
  void emitTyping(String conversationId) {
    _socketService.emitTyping(conversationId);
  }

  void emitStopTyping(String conversationId) {
    _socketService.emitStopTyping(conversationId);
  }

  // ─── EMIT MESSAGE READ ────────────────────────────────────
  void emitMessageRead(String conversationId) {
    _socketService.emitMessageRead(conversationId);
  }

  // ─── REGISTER MESSAGE HANDLER ─────────────────────────────
  // Called by ChatNotifier when chat is opened
  void registerMessageHandler(
    String conversationId,
    Function(Map<String, dynamic>) handler,
  ) {
    _messageHandlers[conversationId] = handler;
  }

  // ─── UNREGISTER MESSAGE HANDLER ───────────────────────────
  // Called by ChatNotifier when chat is closed
  void unregisterMessageHandler(String conversationId) {
    _messageHandlers.remove(conversationId);
  }

  // ─── REGISTER INBOX HANDLER ───────────────────────────────
  void registerInboxHandler(
    String key,
    Function(Map<String, dynamic>) handler,
  ) {
    _inboxHandlers[key] = handler;
  }

  // ─── UNREGISTER INBOX HANDLER ─────────────────────────────
  void unregisterInboxHandler(String key) {
    _inboxHandlers.remove(key);
  }

  // ─── CHECK ONLINE STATUS ──────────────────────────────────
  void checkOnlineStatus(List<String> userIds) {
    _socketService.checkOnlineStatus(userIds);
  }

  // ─── IS USER ONLINE ───────────────────────────────────────
  bool isUserOnline(String userId) => state.isUserOnline(userId);

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  final config = ref.watch(serverConfigProvider);
  service.updateSocketUrl(config.socketUrl);
  return service;
});

final socketProvider = StateNotifierProvider<SocketNotifier, SocketState>((
  ref,
) {
  return SocketNotifier(ref.watch(socketServiceProvider));
});

// Convenience: just connection status
final isSocketConnectedProvider = Provider<bool>((ref) {
  return ref.watch(socketProvider).isConnected;
});
