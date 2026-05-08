import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';

class SocketEvents {
  static const String joinRoom = 'join-room';
  static const String leaveRoom = 'leave-room';
  static const String sendMessage = 'send-message';
  static const String typing = 'typing';
  static const String stopTyping = 'stop-typing';
  static const String messageRead = 'message-read';
  static const String checkOnline = 'check-online';

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

class SocketService {
  io.Socket? _socket;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _socketUrl = 'http://10.126.0.227:5000';

  bool _isConnected = false;

  Function(Map<String, dynamic>)? onNewMessage;
  Function(String conversationId, String userId, bool isTyping)?
      onUserTyping;
  Function(List<String> onlineUserIds)? onOnlineUsers;
  Function(String userId, bool isOnline)? onUserOnlineStatus;
  Function(Map<String, dynamic>)? onInboxUpdate;

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  void updateSocketUrl(String url) {
    _socketUrl = url;
    if (_isConnected) {
      disconnect();
    }
  }

  Future<void> connect() async {
    if (_isConnected) {
      print('Socket already connected');
      return;
    }

    try {
      final token = await _storage.read(key: AppConstants.tokenKey);

      if (token == null || token.isEmpty) {
        print('No token found, cannot connect socket');
        return;
      }

      _socket?.dispose();
      _socket = null;

      print('Connecting to socket: $_socketUrl');

      _socket = io.io(
        _socketUrl,
        io.OptionBuilder()
            .setPath('/socket.io')
            .setTransports(['websocket', 'polling'])
            .setAuth({'token': token})
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(10)
            .setReconnectionDelay(1000)
            .setReconnectionDelayMax(5000)
            .setTimeout(10000)
            .enableForceNew()
            .disableMultiplex()
            .build(),
      );

      _setupEventListeners();
      _socket!.connect();
    } catch (e) {
      print('Socket connection error: $e');
    }
  }

  void _setupEventListeners() {
    if (_socket == null) {
      return;
    }

    _socket!.onConnect((_) {
      _isConnected = true;
      print('Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      print('Socket disconnected: $reason');
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      print('Socket connect error: $error');
    });

    _socket!.onError((error) {
      _isConnected = false;
      print('Socket error: $error');
    });

    _socket!.on('reconnecting', (attempt) {
      print('Socket reconnecting... attempt $attempt');
    });

    _socket!.on('reconnect', (attempt) {
      _isConnected = true;
      print('Socket reconnected after $attempt attempts');
    });

    _socket!.on(SocketEvents.newMessage, (data) {
      final payload = _asMap(data);
      final message = payload?['message'];
      final messageId = message is Map ? message['id'] : null;

      print('New message received: $messageId');
      if (onNewMessage != null && payload != null) {
        onNewMessage!(payload);
      }
    });

    _socket!.on(SocketEvents.userTyping, (data) {
      final payload = _asMap(data);
      if (onUserTyping != null && payload != null) {
        onUserTyping!(
          payload['conversation_id'] as String? ?? '',
          payload['user_id'] as String? ?? '',
          payload['is_typing'] as bool? ?? false,
        );
      }
    });

    _socket!.on(SocketEvents.onlineUsers, (data) {
      final payload = _asMap(data);
      if (onOnlineUsers != null && payload != null) {
        final ids = List<String>.from(payload['online_user_ids'] ?? []);
        onOnlineUsers!(ids);
      }
    });

    _socket!.on(SocketEvents.userOnline, (data) {
      final payload = _asMap(data);
      if (onUserOnlineStatus != null && payload != null) {
        onUserOnlineStatus!(payload['user_id'] as String? ?? '', true);
      }
    });

    _socket!.on(SocketEvents.userOffline, (data) {
      final payload = _asMap(data);
      if (onUserOnlineStatus != null && payload != null) {
        onUserOnlineStatus!(payload['user_id'] as String? ?? '', false);
      }
    });

    _socket!.on(SocketEvents.inboxUpdate, (data) {
      final payload = _asMap(data);
      if (onInboxUpdate != null && payload != null) {
        onInboxUpdate!(payload);
      }
    });

    _socket!.on(SocketEvents.errorEvent, (data) {
      print('Socket server error: $data');
    });
  }

  void joinRoom(String conversationId) {
    if (!_isConnected || _socket == null) {
      print('Cannot join room - not connected');
      return;
    }

    print('Joining room: conversation:$conversationId');
    _socket!.emit(SocketEvents.joinRoom, {
      'conversation_id': conversationId,
    });
  }

  void leaveRoom(String conversationId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    print('Leaving room: conversation:$conversationId');
    _socket!.emit(SocketEvents.leaveRoom, {
      'conversation_id': conversationId,
    });
  }

  void emitTyping(String conversationId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit(SocketEvents.typing, {
      'conversation_id': conversationId,
    });
  }

  void emitStopTyping(String conversationId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit(SocketEvents.stopTyping, {
      'conversation_id': conversationId,
    });
  }

  void emitMessageRead(String conversationId) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit(SocketEvents.messageRead, {
      'conversation_id': conversationId,
    });
  }

  void checkOnlineStatus(List<String> userIds) {
    if (!_isConnected || _socket == null) {
      return;
    }

    _socket!.emit(SocketEvents.checkOnline, {
      'user_ids': userIds,
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;

    onNewMessage = null;
    onUserTyping = null;
    onOnlineUsers = null;
    onUserOnlineStatus = null;
    onInboxUpdate = null;

    print('Socket disconnected and disposed');
  }

  bool get isConnected => _isConnected;
  String? get socketId => _socket?.id;
}
