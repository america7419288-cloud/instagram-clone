import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';
import 'socket_events.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String _socketUrl = AppConstants.dynamicSocketUrl;
  bool _isConnecting = false;
  
  // Streams for external listeners
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _inboxController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _communityController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get inboxStream => _inboxController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<Map<String, dynamic>> get communityStream => _communityController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  void configure({required String socketUrl}) {
    final normalizedUrl = socketUrl.trim().replaceFirst(RegExp(r'/$'), '');
    if (normalizedUrl.isEmpty || normalizedUrl == _socketUrl) return;

    _socketUrl = normalizedUrl;
    if (_socket != null) {
      disconnect();
      connect();
    }
  }

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null) return;

    _isConnecting = true;
    _socket?.dispose();
    
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

    _setupListeners();
    _socket?.connect();
  }

  void _setupListeners() {
    _socket?.onConnect((_) {
      _isConnecting = false;
      _isConnected = true;
      _connectionController.add(true);
      print('Socket Connected: ${_socket?.id}');

      // Re-join active rooms on reconnection
      for (final roomId in _activeRooms) {
        if (roomId.startsWith('community:')) {
          final id = roomId.substring('community:'.length);
          emit('join-community', {'community_id': id});
        } else {
          emit(SocketEvents.joinRoom, {SocketKeys.conversationId: roomId});
        }
      }
    });

    _socket?.onDisconnect((_) {
      _isConnecting = false;
      _isConnected = false;
      _connectionController.add(false);
      print('Socket Disconnected');
    });

    _socket?.onConnectError((error) {
      _isConnecting = false;
      _isConnected = false;
      _connectionController.add(false);
      print('Socket Connect Error: $error');
    });

    _socket?.on(SocketEvents.newMessage, (data) => _messageController.add(_asMap(data)));
    _socket?.on(SocketEvents.messageDeleted, (data) => _messageController.add({..._asMap(data), 'type': 'delete'}));
    _socket?.on(SocketEvents.messageReacted, (data) => _messageController.add({..._asMap(data), 'type': 'reaction'}));
    _socket?.on('message-edited', (data) => _messageController.add({..._asMap(data), 'type': 'edit'}));
    _socket?.on(SocketEvents.messagesRead, (data) => _messageController.add({..._asMap(data), 'type': 'messages-read'}));
    _socket?.on('disappearing-mode-changed', (data) => _inboxController.add(_asMap(data)));
    _socket?.on(SocketEvents.userTyping, (data) => _typingController.add(_asMap(data)));
    _socket?.on(SocketEvents.inboxUpdate, (data) => _inboxController.add(_asMap(data)));
    _socket?.on(SocketEvents.onlineStatus, (data) => _presenceController.add(_asMap(data)));
    _socket?.on(SocketEvents.onlineUsers, (data) => _presenceController.add(_asMap(data)));
    _socket?.on(SocketEvents.userOnline, (data) => _presenceController.add({..._asMap(data), 'status': 'online'}));
    _socket?.on(SocketEvents.userOffline, (data) => _presenceController.add({..._asMap(data), 'status': 'offline'}));

    // Communities Listeners
    _socket?.on('new-community-post', (data) => _communityController.add({'event': 'new-post', 'data': _asMap(data)}));
    _socket?.on('community-poll-updated', (data) => _communityController.add({'event': 'poll-updated', 'data': _asMap(data)}));
    _socket?.on('community-event-updated', (data) => _communityController.add({'event': 'event-updated', 'data': _asMap(data)}));
    _socket?.on('channel-created', (data) => _communityController.add({'event': 'channel-created', 'data': _asMap(data)}));
    _socket?.on('channel-updated', (data) => _communityController.add({'event': 'channel-updated', 'data': _asMap(data)}));
    _socket?.on('channel-deleted', (data) => _communityController.add({'event': 'channel-deleted', 'data': _asMap(data)}));
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    return {};
  }

  void emit(String event, dynamic data) {
    print('📤 Socket Emit: $event - $data');
    _socket?.emit(event, data);
  }

  // Helper methods for specific actions
  void checkOnline(List<String> userIds) {
    print('📡 Checking online status for: $userIds');
    emit(SocketEvents.checkOnline, {'user_ids': userIds});
  }

  final Set<String> _activeRooms = {};

  void joinRoom(String conversationId) {
    _activeRooms.add(conversationId);
    if (_isConnected) {
      emit(SocketEvents.joinRoom, {SocketKeys.conversationId: conversationId});
    }
  }

  void leaveRoom(String conversationId) {
    _activeRooms.remove(conversationId);
    emit(SocketEvents.leaveRoom, {SocketKeys.conversationId: conversationId});
  }

  void joinCommunity(String communityId) {
    final roomId = 'community:$communityId';
    _activeRooms.add(roomId);
    if (_isConnected) {
      emit('join-community', {'community_id': communityId});
    }
  }

  void leaveCommunity(String communityId) {
    final roomId = 'community:$communityId';
    _activeRooms.remove(roomId);
    emit('leave-community', {'community_id': communityId});
  }
  void sendMessage(Map<String, dynamic> message) => emit(SocketEvents.sendMessage, message);
  void setTyping(String conversationId, bool isTyping) {
    emit(isTyping ? SocketEvents.typing : SocketEvents.stopTyping, {SocketKeys.conversationId: conversationId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnecting = false;
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _typingController.close();
    _inboxController.close();
    _presenceController.close();
    _connectionController.close();
    _communityController.close();
  }
}
