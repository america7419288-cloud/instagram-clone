// lib/core/socket/socket_service.dart

import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

// ─── SOCKET EVENT NAMES ─────────────────────────────────────
// Keep these in sync with backend socket.service.js
class SocketEvents {
  // Outgoing (client → server)
  static const String joinRoom = 'join-room';
  static const String leaveRoom = 'leave-room';
  static const String sendMessage = 'send-message';
  static const String typing = 'typing';
  static const String stopTyping = 'stop-typing';
  static const String messageRead = 'message-read';
  static const String checkOnline = 'check-online';

  // Incoming (server → client)
  static const String newMessage = 'new-message';
  static const String userTyping = 'user-typing';
  static const String onlineUsers = 'online-users';
  static const String userOnline = 'user-online';
  static const String userOffline = 'user-offline';
  static const String onlineStatus = 'online-status';
  static const String inboxUpdate = 'inbox-update';
  static const String joinedRoom = 'joined-room';
  static const String messagesRead = 'messages-read';
  static const String errorEvent = 'error';
}

// ─── SOCKET SERVICE ─────────────────────────────────────────
class SocketService {
  IO.Socket? _socket;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Track if we are connected
  bool _isConnected = false;

  // Callback functions set by providers
  Function(Map<String, dynamic>)? onNewMessage;
  Function(String conversationId, String userId, bool isTyping)?
      onUserTyping;
  Function(List<String> onlineUserIds)? onOnlineUsers;
  Function(String userId, bool isOnline)? onUserOnlineStatus;
  Function(Map<String, dynamic>)? onInboxUpdate;

  // ─── CONNECT ─────────────────────────────────────────────
  Future<void> connect() async {
    if (_isConnected) {
      print('⚡ Socket already connected');
      return;
    }

    try {
      // Get JWT token from secure storage
      final token = await _storage.read(key: AppConstants.tokenKey);

      if (token == null || token.isEmpty) {
        print('⚠️ No token found, cannot connect socket');
        return;
      }

      print('🔌 Connecting to socket: ${AppConstants.socketUrl}');

      _socket = IO.io(
        AppConstants.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            // Auth: send JWT token
            .setAuth({'token': token})
            // Auto reconnect on disconnect
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)      // 1 second
            .setReconnectionDelayMax(5000)   // Max 5 seconds
            .setTimeout(10000)               // 10 second timeout
            .build(),
      );

      _setupEventListeners();
      _socket!.connect();

    } catch (e) {
      print('❌ Socket connection error: $e');
    }
  }

  // ─── SETUP EVENT LISTENERS ───────────────────────────────
  void _setupEventListeners() {
    if (_socket == null) return;

    // Connection established
    _socket!.onConnect((_) {
      _isConnected = true;
      print('✅ Socket connected: ${_socket!.id}');
    });

    // Disconnected
    _socket!.onDisconnect((reason) {
      _isConnected = false;
      print('❌ Socket disconnected: $reason');
    });

    // Connection error
    _socket!.onConnectError((error) {
      _isConnected = false;
      print('❌ Socket connect error: $error');
    });

    // Reconnecting
    _socket!.on('reconnecting', (attempt) {
      print('🔄 Socket reconnecting... attempt $attempt');
    });

    // Reconnected
    _socket!.on('reconnect', (attempt) {
      _isConnected = true;
      print('✅ Socket reconnected after $attempt attempts');
    });

    // ─── INCOMING EVENTS ────────────────────────────────────

    // New message received
    _socket!.on(SocketEvents.newMessage, (data) {
      print('📩 New message received: ${data['message']['id']}');
      if (onNewMessage != null && data is Map<String, dynamic>) {
        onNewMessage!(data);
      }
    });

    // User typing indicator
    _socket!.on(SocketEvents.userTyping, (data) {
      if (onUserTyping != null && data is Map<String, dynamic>) {
        onUserTyping!(
          data['conversation_id'] as String? ?? '',
          data['user_id'] as String? ?? '',
          data['is_typing'] as bool? ?? false,
        );
      }
    });

    // Currently online users (received on connect)
    _socket!.on(SocketEvents.onlineUsers, (data) {
      if (onOnlineUsers != null && data is Map<String, dynamic>) {
        final ids = List<String>.from(
          data['online_user_ids'] ?? [],
        );
        onOnlineUsers!(ids);
      }
    });

    // User came online
    _socket!.on(SocketEvents.userOnline, (data) {
      if (onUserOnlineStatus != null &&
          data is Map<String, dynamic>) {
        onUserOnlineStatus!(
          data['user_id'] as String? ?? '',
          true,
        );
      }
    });

    // User went offline
    _socket!.on(SocketEvents.userOffline, (data) {
      if (onUserOnlineStatus != null &&
          data is Map<String, dynamic>) {
        onUserOnlineStatus!(
          data['user_id'] as String? ?? '',
          false,
        );
      }
    });

    // Inbox update (new message from another user)
    _socket!.on(SocketEvents.inboxUpdate, (data) {
      if (onInboxUpdate != null && data is Map<String, dynamic>) {
        onInboxUpdate!(data);
      }
    });

    // Server error
    _socket!.on(SocketEvents.errorEvent, (data) {
      print('❌ Socket server error: $data');
    });
  }

  // ─── JOIN CONVERSATION ROOM ──────────────────────────────
  void joinRoom(String conversationId) {
    if (!_isConnected || _socket == null) {
      print('⚠️ Cannot join room - not connected');
      return;
    }

    print('📥 Joining room: conversation:$conversationId');
    _socket!.emit(SocketEvents.joinRoom, {
      'conversation_id': conversationId,
    });
  }

  // ─── LEAVE CONVERSATION ROOM ─────────────────────────────
  void leaveRoom(String conversationId) {
    if (!_isConnected || _socket == null) return;

    print('📤 Leaving room: conversation:$conversationId');
    _socket!.emit(SocketEvents.leaveRoom, {
      'conversation_id': conversationId,
    });
  }

  // ─── EMIT TYPING ─────────────────────────────────────────
  void emitTyping(String conversationId) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit(SocketEvents.typing, {
      'conversation_id': conversationId,
    });
  }

  // ─── EMIT STOP TYPING ────────────────────────────────────
  void emitStopTyping(String conversationId) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit(SocketEvents.stopTyping, {
      'conversation_id': conversationId,
    });
  }

  // ─── EMIT MESSAGE READ ───────────────────────────────────
  void emitMessageRead(String conversationId) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit(SocketEvents.messageRead, {
      'conversation_id': conversationId,
    });
  }

  // ─── CHECK ONLINE STATUS ─────────────────────────────────
  void checkOnlineStatus(List<String> userIds) {
    if (!_isConnected || _socket == null) return;
    _socket!.emit(SocketEvents.checkOnline, {
      'user_ids': userIds,
    });
  }

  // ─── DISCONNECT ──────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;

    // Clear callbacks
    onNewMessage = null;
    onUserTyping = null;
    onOnlineUsers = null;
    onUserOnlineStatus = null;
    onInboxUpdate = null;

    print('🔌 Socket disconnected and disposed');
  }

  // ─── GETTERS ─────────────────────────────────────────────
  bool get isConnected => _isConnected;
  String? get socketId => _socket?.id;
}