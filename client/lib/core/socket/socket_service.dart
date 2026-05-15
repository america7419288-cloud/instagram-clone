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
  
  // Streams for external listeners
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  final _inboxController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get inboxStream => _inboxController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final token = await _storage.read(key: AppConstants.tokenKey);
    if (token == null) return;

    _socket?.dispose();
    
    _socket = io.io(
      AppConstants.socketUrl,
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
      _isConnected = true;
      _connectionController.add(true);
      print('Socket Connected: ${_socket?.id}');
    });

    _socket?.onDisconnect((_) {
      _isConnected = false;
      _connectionController.add(false);
      print('Socket Disconnected');
    });

    _socket?.on(SocketEvents.newMessage, (data) => _messageController.add(_asMap(data)));
    _socket?.on(SocketEvents.messageDeleted, (data) => _messageController.add({..._asMap(data), 'type': 'delete'}));
    _socket?.on(SocketEvents.messageReacted, (data) => _messageController.add({..._asMap(data), 'type': 'reaction'}));
    _socket?.on(SocketEvents.userTyping, (data) => _typingController.add(_asMap(data)));
    _socket?.on(SocketEvents.inboxUpdate, (data) => _inboxController.add(_asMap(data)));
    _socket?.on(SocketEvents.onlineStatus, (data) => _presenceController.add(_asMap(data)));
    _socket?.on(SocketEvents.userOnline, (data) => _presenceController.add({..._asMap(data), 'status': 'online'}));
    _socket?.on(SocketEvents.userOffline, (data) => _presenceController.add({..._asMap(data), 'status': 'offline'}));
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    return {};
  }

  void emit(String event, dynamic data) {
    if (_isConnected) {
      _socket?.emit(event, data);
    }
  }

  // Helper methods for specific actions
  void joinRoom(String conversationId) => emit(SocketEvents.joinRoom, {SocketKeys.conversationId: conversationId});
  void leaveRoom(String conversationId) => emit(SocketEvents.leaveRoom, {SocketKeys.conversationId: conversationId});
  void sendMessage(Map<String, dynamic> message) => emit(SocketEvents.sendMessage, message);
  void setTyping(String conversationId, bool isTyping) {
    emit(isTyping ? SocketEvents.typing : SocketEvents.stopTyping, {SocketKeys.conversationId: conversationId});
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
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
  }
}
