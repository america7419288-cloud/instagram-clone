// lib/core/socket/socket_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'socket_service.dart';
import 'socket_events.dart';

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
class SocketNotifier extends Notifier<SocketState> {
  SocketService get _socketService => ref.read(socketServiceProvider);
  final List<StreamSubscription> _subscriptions = [];

  @override
  SocketState build() {
    _initListeners();
    ref.onDispose(() {
      for (var sub in _subscriptions) {
        sub.cancel();
      }
      _socketService.disconnect();
    });
    return const SocketState();
  }

  void _initListeners() {
    _subscriptions.add(_socketService.connectionStream.listen((isConnected) {
      state = state.copyWith(isConnected: isConnected);
    }));

    _subscriptions.add(_socketService.presenceStream.listen((data) {
      final userId = data[SocketKeys.userId] as String?;
      final status = data['status'] as String?;
      if (userId == null) return;

      final updated = Set<String>.from(state.onlineUserIds);
      if (status == 'online' || status == 'user-online') {
        updated.add(userId);
      } else {
        updated.remove(userId);
      }
      state = state.copyWith(onlineUserIds: updated);
    }));

    _subscriptions.add(_socketService.typingStream.listen((data) {
      final conversationId = data[SocketKeys.conversationId] as String?;
      final userId = data[SocketKeys.userId] as String?;
      final isTyping = data[SocketKeys.isTyping] as bool? ?? true;

      if (conversationId == null) return;

      final updatedTyping = Map<String, String?>.from(state.typingUsers);
      if (isTyping) {
        updatedTyping[conversationId] = userId;
      } else {
        updatedTyping.remove(conversationId);
      }
      state = state.copyWith(typingUsers: updatedTyping);
    }));
  }

  // ─── ACTIONS ──────────────────────────────────────────────
  Future<void> connect() => _socketService.connect();
  void disconnect() => _socketService.disconnect();
  void joinRoom(String conversationId) => _socketService.joinRoom(conversationId);
  void leaveRoom(String conversationId) => _socketService.leaveRoom(conversationId);
  void setTyping(String conversationId, bool isTyping) => _socketService.setTyping(conversationId, isTyping);
}

// ─── PROVIDERS ──────────────────────────────────────────────
final socketServiceProvider = Provider<SocketService>((ref) => SocketService());

final socketProvider = NotifierProvider<SocketNotifier, SocketState>(
  SocketNotifier.new,
);

final isSocketConnectedProvider = Provider<bool>((ref) {
  return ref.watch(socketProvider).isConnected;
});

